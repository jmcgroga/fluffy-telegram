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
                language: appState.codeLanguage,
                executionLine: appState.currentExecutionLine,
                breakpoints: appState.activeBreakpoints,
                onBreakpointToggle: { line in appState.toggleBreakpoint(line: line) }
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
    var executionLine: Int? = nil
    var breakpoints: Set<Int> = []
    var onBreakpointToggle: ((Int) -> Void)? = nil

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
        textContainer.widthTracksTextView = false
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

        // Disable text wrapping
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        // Don't set backgroundColor - LineNumberTextView handles all background drawing
        textView.insertionPointColor = .systemBlue
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor.selectedTextBackgroundColor.withAlphaComponent(0.4)
        ]
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        // textContainerInset is set inside LineNumberTextView.init

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
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
        guard let textView = scrollView.documentView as? LineNumberTextView,
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

        // Update execution line highlight
        if storage.executionLine != executionLine {
            storage.executionLine = executionLine
            let range = NSRange(location: 0, length: storage.length)
            storage.edited(.editedAttributes, range: range, changeInLength: 0)
            if let line = executionLine {
                scrollToLine(line, in: textView)
            }
        }

        // Notify the text view to redraw its gutter with the execution indicator
        if textView.executionLine != executionLine {
            textView.executionLine = executionLine
            textView.setNeedsDisplay(textView.bounds)
        }

        // Sync breakpoints and callback
        if textView.breakpoints != breakpoints {
            textView.breakpoints = breakpoints
            textView.setNeedsDisplay(textView.bounds)
        }
        textView.onBreakpointToggle = onBreakpointToggle
    }

    private func scrollToLine(_ line: Int, in textView: NSTextView) {
        let string = textView.string as NSString
        var current = 1
        var idx = 0
        while idx < string.length {
            let lr = string.lineRange(for: NSRange(location: idx, length: 0))
            if current == line {
                DispatchQueue.main.async { textView.scrollRangeToVisible(lr) }
                return
            }
            current += 1
            idx = NSMaxRange(lr)
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
    var executionLine: Int? = nil
    var breakpoints: Set<Int> = []
    var onBreakpointToggle: ((Int) -> Void)? = nil

    private let gutterAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
        .foregroundColor: NSColor.tertiaryLabelColor,
    ]

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)

        // Shift the text container right to make room for the gutter
        textContainerInset = NSSize(width: LineNumberTextView.gutterWidth + 8, height: 12)

        // We handle all background drawing ourselves in draw(_:)
        drawsBackground = true

        // Observe text storage changes to trigger gutter redraws
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textStorageDidChange(_:)),
            name: NSTextStorage.didProcessEditingNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func textStorageDidChange(_ notification: Notification) {
        // Redraw gutter when text changes
        setNeedsDisplay(bounds)
    }

    override func didChangeText() {
        super.didChangeText()
        // Trigger a redraw of the line numbers
        setNeedsDisplay(bounds)
    }

    // MARK: - Mouse handling for breakpoint gutter clicks

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        // Only intercept clicks inside the gutter area
        if point.x < LineNumberTextView.gutterWidth, let lineNumber = lineNumber(at: point) {
            onBreakpointToggle?(lineNumber)
            return
        }
        super.mouseDown(with: event)
    }

    /// Convert a point (in the text view's coordinate space) to a 1-based line number.
    private func lineNumber(at point: NSPoint) -> Int? {
        guard let layoutManager = layoutManager,
              let container = textContainer else { return nil }
        let textOrigin = textContainerOrigin
        let visibleRect = enclosingScrollView?.documentVisibleRect ?? bounds
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: container)

        if glyphRange.length == 0 || string.isEmpty { return 1 }

        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        let nsString = string as NSString
        let textBeforeVisible = nsString.substring(to: charRange.location)
        var lineNumber = textBeforeVisible.components(separatedBy: "\n").count

        var drawnLineStarts = Set<Int>()
        var glyphIndex = glyphRange.location
        while glyphIndex < NSMaxRange(glyphRange) {
            var lineGlyphRange = NSRange()
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange)
            let lineCharRange = layoutManager.characterRange(forGlyphRange: lineGlyphRange, actualGlyphRange: nil)

            if !drawnLineStarts.contains(lineCharRange.location) {
                drawnLineStarts.insert(lineCharRange.location)
                let yBase = lineRect.minY + textOrigin.y
                if point.y >= yBase && point.y < yBase + lineRect.height {
                    return lineNumber
                }
                lineNumber += 1
            }
            glyphIndex = NSMaxRange(lineGlyphRange)
        }
        return nil
    }

    override func draw(_ dirtyRect: NSRect) {
        // 1. Draw our custom backgrounds FIRST (before calling super)
        // Dark gray gutter
        let gutterRect = NSRect(
            x: bounds.minX,
            y: dirtyRect.minY,
            width: LineNumberTextView.gutterWidth,
            height: dirtyRect.height
        )
        NSColor(white: 0.12, alpha: 1).setFill()
        gutterRect.fill()

        // Editor background for text area
        let textAreaRect = NSRect(
            x: bounds.minX + LineNumberTextView.gutterWidth,
            y: dirtyRect.minY,
            width: bounds.width - LineNumberTextView.gutterWidth,
            height: dirtyRect.height
        )
        (NSColor(named: "editorBackground") ?? .textBackgroundColor).setFill()
        textAreaRect.fill()

        // 2. Draw text content WITHOUT backgrounds
        // Temporarily disable background drawing to avoid overdrawing our custom backgrounds
        NSGraphicsContext.saveGraphicsState()
        let savedDrawsBackground = self.drawsBackground
        self.drawsBackground = false
        super.draw(dirtyRect)
        self.drawsBackground = savedDrawsBackground
        NSGraphicsContext.restoreGraphicsState()

        // 3. Draw separator between gutter and code
        let sepX = bounds.minX + LineNumberTextView.gutterWidth - 0.5
        NSColor.separatorColor.setStroke()
        let sep = NSBezierPath()
        sep.move(to: NSPoint(x: sepX, y: dirtyRect.minY))
        sep.line(to: NSPoint(x: sepX, y: dirtyRect.maxY))
        sep.lineWidth = 0.5
        sep.stroke()

        // 4. Draw line numbers on top of everything
        drawLineNumbers(in: dirtyRect)
    }

    private func drawLineNumbers(in dirtyRect: NSRect) {
        guard let layoutManager = layoutManager,
              let container = textContainer else { return }

        let textOrigin = textContainerOrigin
        let visibleRect = enclosingScrollView?.documentVisibleRect ?? bounds
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: container)

        // Handle empty document
        if glyphRange.length == 0 || string.isEmpty {
            let label = "1" as NSString
            let labelSize = label.size(withAttributes: gutterAttrs)
            let x = bounds.minX + LineNumberTextView.gutterWidth - labelSize.width - 8
            let y = textOrigin.y
            label.draw(at: NSPoint(x: x, y: y), withAttributes: gutterAttrs)
            return
        }

        // Calculate starting line number
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        let nsString = string as NSString
        let textBeforeVisible = nsString.substring(to: charRange.location)
        var lineNumber = textBeforeVisible.components(separatedBy: "\n").count

        // Track which character indices we've drawn line numbers for
        var drawnLineStarts = Set<Int>()

        var glyphIndex = glyphRange.location
        while glyphIndex < NSMaxRange(glyphRange) {
            var lineGlyphRange = NSRange()
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange)
            let lineCharRange = layoutManager.characterRange(forGlyphRange: lineGlyphRange, actualGlyphRange: nil)

            // Only draw line number if this is the first fragment for this line
            // (avoids drawing numbers for wrapped line continuations)
            if !drawnLineStarts.contains(lineCharRange.location) {
                drawnLineStarts.insert(lineCharRange.location)

                let isExecLine = lineNumber == executionLine
                let isBreakpoint = breakpoints.contains(lineNumber)
                let yBase = lineRect.minY + textOrigin.y

                if isExecLine {
                    // Highlight gutter background for the current execution line
                    let gutterHighlight = NSRect(
                        x: bounds.minX, y: yBase,
                        width: LineNumberTextView.gutterWidth, height: lineRect.height
                    )
                    NSColor.systemGreen.withAlphaComponent(0.15).setFill()
                    gutterHighlight.fill()

                    // Draw ▶ arrow
                    let arrowAttrs: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: 9, weight: .bold),
                        .foregroundColor: NSColor.systemGreen
                    ]
                    let arrow = "▶" as NSString
                    let arrowSize = arrow.size(withAttributes: arrowAttrs)
                    arrow.draw(at: NSPoint(x: bounds.minX + 4,
                                          y: yBase + (lineRect.height - arrowSize.height) / 2),
                               withAttributes: arrowAttrs)
                } else if isBreakpoint {
                    // Draw red ● breakpoint dot in the gutter
                    let dotAttrs: [NSAttributedString.Key: Any] = [
                        .font: NSFont.systemFont(ofSize: 10, weight: .bold),
                        .foregroundColor: NSColor.systemRed
                    ]
                    let dot = "●" as NSString
                    let dotSize = dot.size(withAttributes: dotAttrs)
                    dot.draw(at: NSPoint(x: bounds.minX + 4,
                                        y: yBase + (lineRect.height - dotSize.height) / 2),
                             withAttributes: dotAttrs)
                }

                let lineFont = gutterAttrs[.font] as! NSFont
                let lineColor: NSColor = isExecLine ? .systemGreen : (isBreakpoint ? .systemRed : .tertiaryLabelColor)
                let lineAttrs: [NSAttributedString.Key: Any] = [
                    .font: lineFont,
                    .foregroundColor: lineColor
                ]
                let y = yBase + (lineRect.height - lineFont.capHeight) / 2
                let label = "\(lineNumber)" as NSString
                let labelSize = label.size(withAttributes: lineAttrs)
                let x = bounds.minX + LineNumberTextView.gutterWidth - labelSize.width - 8
                label.draw(at: NSPoint(x: x, y: y), withAttributes: lineAttrs)

                lineNumber += 1
            }

            glyphIndex = NSMaxRange(lineGlyphRange)
        }
    }
}

#Preview {
    @Previewable @State var sampleCode = (1...100).map { "Line \($0)" }.joined(separator: "\n")
    @Previewable @StateObject var previewAppState = AppState()

    CodeEditorView()
        .environmentObject(previewAppState)
        .onAppear {
            previewAppState.currentCode = sampleCode
        }
        .frame(width: 800, height: 600)
}
