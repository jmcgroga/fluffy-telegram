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
        let textContainer = NSTextContainer(
            containerSize: NSSize(width: CGFloat.greatestFiniteMagnitude,
                                  height: CGFloat.greatestFiniteMagnitude)
        )
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        storage.addLayoutManager(layoutManager)

        // LineNumberTextView draws its own gutter, keeping everything in one
        // coordinate space so click-to-cursor mapping is always correct.
        let textView = LineNumberTextView(frame: .zero, textContainer: textContainer)
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

        textView.backgroundColor = NSColor(named: "editorBackground") ?? .textBackgroundColor
        textView.insertionPointColor = .systemBlue
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor.selectedTextBackgroundColor.withAlphaComponent(0.4)
        ]
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        // textContainerInset is set inside LineNumberTextView.init

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

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

        if storage.language != language {
            storage.language = language
            let range = NSRange(location: 0, length: storage.length)
            storage.edited(.editedAttributes, range: range, changeInLength: 0)
        }

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
            let newText = textView.string
            Task { @MainActor in
                self.isEditing = true
                self.parent.text = newText
                self.isEditing = false
            }
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

// MARK: - Line Number Text View
// NSTextView subclass that draws its own gutter on the left side.
// Embedding the gutter inside the text view keeps everything in one
// coordinate space — click positions are always mapped correctly by
// the text view's own event-handling machinery.

final class LineNumberTextView: NSTextView {
    static let gutterWidth: CGFloat = 44

    private let gutterAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
        .foregroundColor: NSColor.tertiaryLabelColor,
    ]

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        // Shift the text container right to make room for the gutter.
        // textContainerInset.width becomes textContainerOrigin.x, so text
        // starts at x = gutterWidth + 8 (an 8-pt gap between gutter and code).
        textContainerInset = NSSize(width: LineNumberTextView.gutterWidth + 8, height: 12)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        // 1. Draw normal text-view content (background, selection, glyphs).
        super.draw(dirtyRect)

        // 2. Overdraw gutter background on top of text-view background.
        NSColor(white: 0.12, alpha: 1).setFill()
        NSRect(x: bounds.minX,
               y: dirtyRect.minY,
               width: LineNumberTextView.gutterWidth,
               height: dirtyRect.height).fill()

        // 3. Separator between gutter and code.
        NSColor.separatorColor.setStroke()
        let sep = NSBezierPath()
        let sepX = bounds.minX + LineNumberTextView.gutterWidth - 0.5
        sep.move(to: NSPoint(x: sepX, y: dirtyRect.minY))
        sep.line(to: NSPoint(x: sepX, y: dirtyRect.maxY))
        sep.lineWidth = 0.5
        sep.stroke()

        // 4. Line numbers.
        drawLineNumbers(in: dirtyRect)
    }

    private func drawLineNumbers(in dirtyRect: NSRect) {
        guard let layoutManager = layoutManager,
              let container = textContainer else { return }

        // textContainerOrigin is (gutterWidth+8, 12) — the text container's
        // origin in text-view coordinates, accounting for textContainerInset.
        let textOrigin = textContainerOrigin

        // documentVisibleRect is in text-view coordinates and reflects the
        // current scroll offset, matching what glyphRange(forBoundingRect:)
        // expects when the text-view IS the document view.
        let visibleRect = enclosingScrollView?.documentVisibleRect ?? bounds

        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: container)
        guard glyphRange.length > 0 else {
            // Empty document: draw "1" at the top.
            let label = "1" as NSString
            let labelSize = label.size(withAttributes: gutterAttrs)
            let x = bounds.minX + LineNumberTextView.gutterWidth - labelSize.width - 8
            let y = textOrigin.y + (NSFont.monospacedSystemFont(ofSize: 13, weight: .regular).pointSize - labelSize.height) / 2
            label.draw(at: NSPoint(x: x, y: y), withAttributes: gutterAttrs)
            return
        }

        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        let textBefore = (string as NSString).substring(to: charRange.location)
        var lineNumber = textBefore.components(separatedBy: "\n").count

        var glyphIndex = glyphRange.location
        while glyphIndex < NSMaxRange(glyphRange) {
            var lineGlyphRange = NSRange()
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange)

            // lineRect is in text-container coordinates.
            // Add textContainerOrigin to get text-view coordinates, which is
            // what draw(_:) uses (scroll offset already baked into bounds.origin).
            let y = lineRect.minY + textOrigin.y + (lineRect.height - (gutterAttrs[.font] as! NSFont).capHeight) / 2

            let label = "\(lineNumber)" as NSString
            let labelSize = label.size(withAttributes: gutterAttrs)
            let x = bounds.minX + LineNumberTextView.gutterWidth - labelSize.width - 8
            label.draw(at: NSPoint(x: x, y: y), withAttributes: gutterAttrs)

            lineNumber += 1
            glyphIndex = NSMaxRange(lineGlyphRange)
        }
    }
}
