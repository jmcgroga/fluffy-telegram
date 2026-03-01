import SwiftUI
import AppKit

// MARK: - Code Editor View

struct CodeEditorView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header with language indicator and actions
            HStack(spacing: 8) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .foregroundStyle(.orange)
                Text("Editor")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.tertiary)
                Image(systemName: appState.codeLanguage.icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(appState.codeLanguage.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                // Quick actions
                Button {
                    appState.currentCode = appState.codeLanguage == .arm64
                        ? ARM64Samples.helloWorld
                        : CSamples.helloWorld
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .help("Reset to default sample")

                Button {
                    copyToClipboard(appState.currentCode)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy code")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.regularMaterial)

            Divider()

            // The actual NSTextView-based editor
            SyntaxTextEditor(
                text: $appState.currentCode,
                language: appState.codeLanguage
            )
        }
        .background(.windowBackground)
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - NSViewRepresentable Wrapper

struct SyntaxTextEditor: NSViewRepresentable {
    @Binding var text: String
    let language: CodeLanguage

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        // Build the text storage with syntax highlighting
        let storage = SyntaxHighlightingStorage()
        storage.language = language

        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(containerSize: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)

        // Create text view
        let textView = NSTextView(frame: .zero, textContainer: container)
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.usesFindPanel = true
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false

        // Appearance
        textView.backgroundColor = NSColor(named: "editorBackground") ?? .textBackgroundColor
        textView.insertionPointColor = .systemBlue
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor.selectedTextBackgroundColor.withAlphaComponent(0.4)
        ]
        textView.textContainerInset = NSSize(width: 4, height: 12)
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        // Line number support via the ruler view
        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        // Line numbers
        let lineNumberView = LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = lineNumberView
        scrollView.rulersVisible = true

        // Set initial text
        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: text)
        storage.language = language

        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        context.coordinator.storage = storage

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView,
              let storage = textView.textStorage as? SyntaxHighlightingStorage else { return }

        // Update language
        if storage.language != language {
            storage.language = language
            // Re-highlight
            let range = NSRange(location: 0, length: storage.length)
            storage.edited(.editedAttributes, range: range, changeInLength: 0)
        }

        // Update text only if changed from outside
        if storage.string != text && !context.coordinator.isEditing {
            let range = NSRange(location: 0, length: storage.length)
            storage.replaceCharacters(in: range, with: text)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SyntaxTextEditor
        weak var textView: NSTextView?
        weak var storage: SyntaxHighlightingStorage?
        var isEditing = false

        init(_ parent: SyntaxTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            isEditing = true
            parent.text = textView.string
            isEditing = false

            // Update line number ruler
            (textView.enclosingScrollView?.verticalRulerView as? LineNumberRulerView)?.needsDisplay = true
        }

        // Smart indentation: maintain indentation on new line
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                let string = textView.string as NSString
                let range = textView.selectedRange()
                let lineStart = string.lineRange(for: NSRange(location: range.location, length: 0)).location
                let linePrefix = string.substring(with: NSRange(location: lineStart, length: range.location - lineStart))
                let indent = String(linePrefix.prefix(while: { $0 == " " || $0 == "\t" }))
                textView.insertText("\n" + indent, replacementRange: range)
                return true
            }
            // Tab inserts 4 spaces
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                textView.insertText("    ", replacementRange: textView.selectedRange())
                return true
            }
            return false
        }
    }
}

// MARK: - Line Number Ruler View

final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.ruleThickness = 40
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange),
            name: NSText.didChangeNotification,
            object: textView
        )
    }

    required init(coder: NSCoder) { fatalError() }

    @objc private func textDidChange(_ notification: Notification) {
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer else { return }

        let visibleRect = textView.enclosingScrollView?.contentView.bounds ?? .zero
        let textOrigin = textView.textContainerOrigin

        // Background
        NSColor.windowBackgroundColor.blended(withFraction: 0.3, of: .secondaryLabelColor)?.setFill()
        NSColor(white: 0.15, alpha: 1).setFill()
        rect.fill()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor,
        ]

        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: container)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        var lineNumber = 1
        var charIndex = 0

        // Count lines before the visible range
        let stringBeforeVisible = (textView.string as NSString).substring(to: charRange.location)
        lineNumber = stringBeforeVisible.components(separatedBy: "\n").count

        // Draw line numbers for visible lines
        var glyphIndex = glyphRange.location
        while glyphIndex < NSMaxRange(glyphRange) {
            var lineGlyphRange = NSRange()
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange)
            let yPos = lineRect.minY + textOrigin.y - visibleRect.minY

            let label = "\(lineNumber)" as NSString
            let labelSize = label.size(withAttributes: attrs)
            let x = ruleThickness - labelSize.width - 6
            let y = yPos + (lineRect.height - labelSize.height) / 2
            label.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)

            lineNumber += 1
            glyphIndex = NSMaxRange(lineGlyphRange)
        }

        // Draw separator line
        NSColor.separatorColor.setStroke()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: ruleThickness - 0.5, y: rect.minY))
        path.line(to: NSPoint(x: ruleThickness - 0.5, y: rect.maxY))
        path.lineWidth = 0.5
        path.stroke()
    }
}
