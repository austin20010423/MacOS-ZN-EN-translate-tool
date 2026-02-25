import SwiftUI
import Combine
import Foundation

@MainActor
final class TranslationViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var outputText = ""
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var modelName = "translategemma:latest"
    @Published var serverURL = "http://127.0.0.1:11434"

    private let service = OllamaService()
    private let runtime = OllamaRuntimeManager.shared

    func translate() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !trimmedModel.isEmpty else {
            errorMessage = "Model name cannot be empty."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await runtime.prepare(
                serverURL: serverURL,
                model: trimmedModel
            )

            let result = try await service.translate(
                serverURL: serverURL,
                inputText: trimmed,
                model: trimmedModel
            )
            outputText = result
        } catch {
            outputText = ""
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
