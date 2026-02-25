import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TranslationViewModel()
    @State private var isComposingText = false

    var body: some View {
        ZStack {
            Color.clear

            VStack(spacing: 12) {
                inputCard
                glowingDivider
                outputCard

                HStack {
                    Spacer()
                    Button {
                        Task { await viewModel.translate() }
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(viewModel.isLoading ? "Translating..." : "Translate")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(GlassButtonStyle())
                    .disabled(viewModel.isLoading || viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.22), radius: 28, x: 0, y: 16)
        .shadow(color: .white.opacity(0.08), radius: 8, x: 0, y: -1)
        .padding(.horizontal, 0)
        .padding(.vertical, 0)
        .frame(minWidth: 420, minHeight: 300)
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Input")
                .font(.headline)
                .foregroundStyle(.primary)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(0.18), lineWidth: 0.5)
                    )

                EnterSubmitTextEditor(
                    text: $viewModel.inputText,
                    isComposing: $isComposingText,
                    onSubmit: { Task { await viewModel.translate() } }
                )

                if viewModel.inputText.isEmpty && !isComposingText {
                    Text("Type Chinese or English...")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 95)
        }
    }

    private var glowingDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.65), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1.2)
            .shadow(color: .white.opacity(0.35), radius: 3)
    }

    private var outputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Output")
                .font(.headline)
                .foregroundStyle(.primary)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                )
                .overlay(
                    ScrollView {
                        Text(viewModel.outputText.isEmpty ? "Translation result will appear here." : viewModel.outputText)
                            .font(.system(size: 16))
                            .foregroundStyle(viewModel.outputText.isEmpty ? .secondary : .primary)
                            .shadow(color: .white.opacity(0.2), radius: 1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(14)
                    }
                )
                .frame(minHeight: 80)
        }
    }
}

private struct EnterSubmitTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var isComposing: Bool
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isComposing: $isComposing, onSubmit: onSubmit)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = EnterAwareTextView()
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.isRichText = false
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        textView.font = .systemFont(ofSize: 16)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.textContainer?.lineFragmentPadding = 0
        textView.submitHandler = onSubmit
        textView.compositionChanged = { isComposing in
            DispatchQueue.main.async {
                context.coordinator.isComposing = isComposing
            }
        }
        textView.string = text

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? EnterAwareTextView else { return }
        textView.submitHandler = onSubmit
        textView.compositionChanged = { composing in
            DispatchQueue.main.async {
                context.coordinator.isComposing = composing
            }
        }
        let isEditing = nsView.window?.firstResponder === textView
        let hasMarkedText = textView.hasMarkedText()
        if textView.string != text && !isEditing && !hasMarkedText {
            textView.string = text
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        @Binding var isComposing: Bool
        let onSubmit: () -> Void

        init(text: Binding<String>, isComposing: Binding<Bool>, onSubmit: @escaping () -> Void) {
            _text = text
            _isComposing = isComposing
            self.onSubmit = onSubmit
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
            isComposing = textView.hasMarkedText()
        }
    }
}

private final class EnterAwareTextView: NSTextView {
    var submitHandler: (() -> Void)?
    var compositionChanged: ((Bool) -> Void)?

    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
        compositionChanged?(true)
    }

    override func unmarkText() {
        super.unmarkText()
        compositionChanged?(false)
    }

    override func keyDown(with event: NSEvent) {
        let isReturnKey = event.keyCode == 36 || event.keyCode == 76
        if isReturnKey {
            if hasMarkedText() {
                super.keyDown(with: event)
                return
            }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.contains(.shift) {
                super.keyDown(with: event)
            } else if flags.isDisjoint(with: [.command, .option, .control]) {
                submitHandler?()
            } else {
                super.keyDown(with: event)
            }
            return
        }
        super.keyDown(with: event)
    }
}

private struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.white.opacity(configuration.isPressed ? 0.2 : 0.12))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(.white.opacity(0.28), lineWidth: 0.5)
                    )
                    .shadow(color: .white.opacity(0.08), radius: 3, x: 0, y: -1)
                    .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 5)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    ContentView()
}
