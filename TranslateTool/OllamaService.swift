import Foundation

struct OllamaService {
    func translate(serverURL: String, inputText: String, model: String) async throws -> String {
        let trimmedBase = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmedBase.isEmpty ? "http://127.0.0.1:11434" : trimmedBase
        let urlString = base.hasSuffix("/") ? base + "api/generate" : base + "/api/generate"
        guard let endpoint = URL(string: urlString) else {
            throw OllamaError.invalidServerURL(serverURL)
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = buildPrompt(for: inputText)

        let body = OllamaGenerateRequest(
            model: model,
            prompt: prompt,
            stream: false,
            options: OllamaOptions(temperature: 0.2)
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw OllamaError.httpError(statusCode: httpResponse.statusCode, message: text)
        }

        let decoded = try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)
        return decoded.response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func buildPrompt(for inputText: String) -> String {
        if containsChineseCharacters(inputText) {
            return """
            Translate the following Chinese text into natural English.
            Return only the translated text with no explanation.

            Chinese:
            \(inputText)
            """
        }

        return """
        Translate the following English text into natural Traditional Chinese.
        Return only the translated text with no explanation.

        English:
        \(inputText)
        """
    }

    private func containsChineseCharacters(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3400...0x4DBF,  // CJK Unified Ideographs Extension A
                 0x4E00...0x9FFF,  // CJK Unified Ideographs
                 0xF900...0xFAFF,  // CJK Compatibility Ideographs
                 0x20000...0x2A6DF, // Extension B
                 0x2A700...0x2B73F, // Extension C
                 0x2B740...0x2B81F, // Extension D
                 0x2B820...0x2CEAF: // Extension E-F
                return true
            default:
                return false
            }
        }
    }
}

struct OllamaGenerateRequest: Encodable {
    let model: String
    let prompt: String
    let stream: Bool
    let options: OllamaOptions
}

struct OllamaOptions: Encodable {
    let temperature: Double
}

struct OllamaGenerateResponse: Decodable {
    let response: String
}

enum OllamaError: LocalizedError {
    case invalidResponse
    case invalidServerURL(String)
    case httpError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Ollama server."
        case let .invalidServerURL(url):
            return "Invalid server URL: \(url). Example: http://127.0.0.1:11434"
        case let .httpError(statusCode, message):
            return "Ollama error (\(statusCode)): \(message)"
        }
    }
}
