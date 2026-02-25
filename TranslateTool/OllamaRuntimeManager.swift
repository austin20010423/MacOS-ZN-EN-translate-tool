import Foundation

actor OllamaRuntimeManager {
    static let shared = OllamaRuntimeManager()

    private var launchedServerProcess: Process?
    private var validatedServers: Set<String> = []
    private var availableModelsByServer: [String: Set<String>] = [:]

    func prepare(serverURL: String, model: String) async throws {
        let normalizedServer = try normalizeServerURL(serverURL)
        let binaryPath = try findOllamaBinary()

        if !validatedServers.contains(normalizedServer) {
            if !(try await isServerReachable(serverURL: normalizedServer)) {
                try startServerIfNeeded(binaryPath: binaryPath)
                try await waitForServer(serverURL: normalizedServer, timeoutSeconds: 12)
            }
            validatedServers.insert(normalizedServer)
        }

        if availableModelsByServer[normalizedServer]?.contains(model) == true {
            return
        }

        let installedModels = try await fetchInstalledModels(serverURL: normalizedServer)
        if installedModels.contains(model) {
            availableModelsByServer[normalizedServer, default: []].insert(model)
            return
        }

        try await pullModel(binaryPath: binaryPath, model: model)
        availableModelsByServer[normalizedServer, default: []].insert(model)
    }

    private func normalizeServerURL(_ serverURL: String) throws -> String {
        let trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "http://127.0.0.1:11434" : trimmed
        guard let url = URL(string: base), url.scheme != nil, url.host != nil else {
            throw RuntimeError.invalidServerURL(base)
        }

        var normalized = "\(url.scheme ?? "http")://\(url.host ?? "127.0.0.1")"
        if let port = url.port {
            normalized += ":\(port)"
        }
        return normalized
    }

    private func isServerReachable(serverURL: String) async throws -> Bool {
        guard let tagsURL = URL(string: "\(serverURL)/api/tags") else { return false }
        var request = URLRequest(url: tagsURL)
        request.timeoutInterval = 1.5
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return (200...299).contains(httpResponse.statusCode)
        } catch {
            return false
        }
    }

    private func waitForServer(serverURL: String, timeoutSeconds: Double) async throws {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if try await isServerReachable(serverURL: serverURL) {
                return
            }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        throw RuntimeError.serverStartTimeout
    }

    private func fetchInstalledModels(serverURL: String) async throws -> Set<String> {
        guard let tagsURL = URL(string: "\(serverURL)/api/tags") else {
            throw RuntimeError.invalidServerURL(serverURL)
        }
        let (data, response) = try await URLSession.shared.data(from: tagsURL)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw RuntimeError.serverUnavailable
        }
        let decoded = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
        return Set(decoded.models.map { $0.name })
    }

    private func startServerIfNeeded(binaryPath: String) throws {
        if let process = launchedServerProcess, process.isRunning {
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["serve"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        launchedServerProcess = process
    }

    private func pullModel(binaryPath: String, model: String) async throws {
        let result = try await runProcess(
            executablePath: binaryPath,
            arguments: ["pull", model]
        )
        guard result.exitCode == 0 else {
            throw RuntimeError.modelPullFailed(model: model, details: result.combinedOutput)
        }
    }

    private func findOllamaBinary() throws -> String {
        let candidates = [
            "/usr/local/bin/ollama",
            "/opt/homebrew/bin/ollama",
            "/Applications/Ollama.app/Contents/Resources/ollama"
        ]

        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }

        let whichResult = try? runProcessSync(executablePath: "/usr/bin/which", arguments: ["ollama"])
        if let whichResult, whichResult.exitCode == 0 {
            let path = whichResult.combinedOutput
                .split(separator: "\n")
                .first
                .map(String.init)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !path.isEmpty {
                return path
            }
        }

        throw RuntimeError.ollamaNotInstalled
    }

    private func runProcess(
        executablePath: String,
        arguments: [String]
    ) async throws -> ProcessResult {
        try await withCheckedThrowingContinuation { continuation in
            do {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executablePath)
                process.arguments = arguments

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                process.terminationHandler = { process in
                    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let stdoutText = String(data: stdoutData, encoding: .utf8) ?? ""
                    let stderrText = String(data: stderrData, encoding: .utf8) ?? ""
                    continuation.resume(
                        returning: ProcessResult(
                            exitCode: Int(process.terminationStatus),
                            combinedOutput: (stdoutText + "\n" + stderrText).trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    )
                }

                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func runProcessSync(executablePath: String, arguments: [String]) throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdoutText = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderrText = String(data: stderrData, encoding: .utf8) ?? ""

        return ProcessResult(
            exitCode: Int(process.terminationStatus),
            combinedOutput: (stdoutText + "\n" + stderrText).trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

private struct OllamaTagsResponse: Decodable {
    let models: [OllamaTagModel]
}

private struct OllamaTagModel: Decodable {
    let name: String
}

private struct ProcessResult {
    let exitCode: Int
    let combinedOutput: String
}

enum RuntimeError: LocalizedError {
    case ollamaNotInstalled
    case invalidServerURL(String)
    case serverUnavailable
    case serverStartTimeout
    case modelPullFailed(model: String, details: String)

    var errorDescription: String? {
        switch self {
        case .ollamaNotInstalled:
            return "Ollama is not installed. Install it first: https://ollama.com/download"
        case let .invalidServerURL(url):
            return "Invalid server URL: \(url)"
        case .serverUnavailable:
            return "Ollama server is unavailable."
        case .serverStartTimeout:
            return "Ollama server did not become ready in time."
        case let .modelPullFailed(model, details):
            let detailText = details.isEmpty ? "No details." : details
            return "Failed to pull model '\(model)'. \(detailText)"
        }
    }
}
