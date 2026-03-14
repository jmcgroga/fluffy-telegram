import SwiftUI
import AppKit

// MARK: - Code Editor View

struct CodeEditorView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header with language indicator, debugger controls, and actions
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
            .padding(.vertical, 5)
            .background(.regularMaterial)

            Divider()

            // The actual NSTextView-based editor
            SyntaxTextEditor(
                text: $appState.currentCode,
                language: appState.codeLanguage,
                executionLine: appState.currentExecutionLine,
                breakpoints: appState.activeBreakpoints,
                onBreakpointToggle: { line in appState.toggleBreakpoint(line: line) },
                disassembly: appState.liveDisassembly,
                textEntries: appState.liveTextEntries
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
    var disassembly: [DisassemblyLine] = []
    var textEntries: [(address: UInt64, value: UInt64)] = []

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

        // Sync disassembly data for hover tooltips
        textView.disassembly = disassembly
        textView.textEntries = textEntries
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
    var disassembly: [DisassemblyLine] = []
    var textEntries: [(address: UInt64, value: UInt64)] = []

    private var hoverTrackingArea: NSTrackingArea?

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

    // MARK: - Hover tracking area

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let old = hoverTrackingArea {
            removeTrackingArea(old)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        let point = convert(event.locationInWindow, from: nil)
        guard point.x >= LineNumberTextView.gutterWidth, !disassembly.isEmpty else {
            toolTip = nil
            return
        }
        guard let line = lineNumber(at: point) else {
            toolTip = nil
            return
        }
        let matching = disassembly.filter { $0.sourceLine == line }
        guard !matching.isEmpty else {
            toolTip = nil
            return
        }
        toolTip = buildTooltip(for: matching)
    }

    private func buildTooltip(for lines: [DisassemblyLine]) -> String {
        lines.map { line in
            var parts = [line.text]
            let bytes = extractInstructionBytes(at: line.address)
            if !bytes.isEmpty {
                let hex = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
                parts.append("Machine code: \(hex)")
            }
            let mnemonic = line.text.components(separatedBy: .whitespaces).first?.lowercased() ?? ""
            if let desc = arm64MnemonicDescriptions[mnemonic] {
                parts.append(desc)
            }
            return parts.joined(separator: "\n")
        }.joined(separator: "\n\n")
    }

    /// Extract the 4 bytes of an ARM64 instruction at `address` from the live __TEXT entries.
    /// Each entry is an 8-byte little-endian quadword; the instruction occupies bytes [0-3] or [4-7].
    private func extractInstructionBytes(at address: UInt64) -> [UInt8] {
        let quadwordAddr = address & ~UInt64(7)
        guard let entry = textEntries.first(where: { $0.address == quadwordAddr }) else { return [] }
        let byteOffset = Int(address & 7)  // 0 or 4 for 4-byte-aligned ARM64
        return (0..<4).map { i in UInt8((entry.value >> ((byteOffset + i) * 8)) & 0xFF) }
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

    // MARK: - ARM64 mnemonic descriptions (used by hover tooltip)

    // swiftlint:disable:next identifier_name
    private let arm64MnemonicDescriptions: [String: String] = [
        "stp":   "Store Pair — saves two registers to memory",
        "ldp":   "Load Pair — loads two registers from memory",
        "str":   "Store Register — writes a register to memory",
        "strb":  "Store Register Byte — writes the low 8 bits to memory",
        "strh":  "Store Register Halfword — writes the low 16 bits to memory",
        "ldr":   "Load Register — reads a value from memory into a register",
        "ldrb":  "Load Register Byte — reads 8 bits from memory, zero-extends to 64",
        "ldrh":  "Load Register Halfword — reads 16 bits from memory, zero-extends to 64",
        "ldrsb": "Load Register Signed Byte — reads 8 bits from memory, sign-extends to 64",
        "ldrsh": "Load Register Signed Halfword — reads 16 bits from memory, sign-extends to 64",
        "ldrsw": "Load Register Signed Word — reads 32 bits from memory, sign-extends to 64",
        "mov":   "Move — copies a value between registers or loads an immediate",
        "movz":  "Move with Zero — loads a 16-bit immediate, zeroing all other bits",
        "movk":  "Move with Keep — inserts a 16-bit immediate without affecting other bits",
        "movn":  "Move with NOT — loads the bitwise inverse of a 16-bit immediate",
        "add":   "Add — adds two registers or a register and immediate",
        "adds":  "Add setting flags — like ADD but updates N, Z, C, V flags",
        "sub":   "Subtract — subtracts a register or immediate from a register",
        "subs":  "Subtract setting flags — like SUB but updates N, Z, C, V flags",
        "mul":   "Multiply — multiplies two registers (low 64 bits of result)",
        "madd":  "Multiply-Add — result = Rm * Rn + Ra",
        "msub":  "Multiply-Subtract — result = Ra - Rm * Rn",
        "mneg":  "Multiply-Negate — result = -(Rm * Rn)",
        "sdiv":  "Signed Divide — divides one register by another (signed, truncates toward zero)",
        "udiv":  "Unsigned Divide — divides one register by another (unsigned, truncates toward zero)",
        "and":   "Bitwise AND — computes the AND of two registers",
        "ands":  "Bitwise AND setting flags — like AND but updates N and Z flags",
        "orr":   "Bitwise OR — computes the OR of two registers or a register and immediate",
        "orn":   "Bitwise OR NOT — computes OR of a register with the bitwise inverse of another",
        "eor":   "Bitwise XOR — computes the exclusive OR of two registers",
        "eon":   "Bitwise XOR NOT — computes XOR with the bitwise inverse",
        "bic":   "Bit Clear — ANDs a register with the complement of another",
        "lsl":   "Logical Shift Left — shifts a value left by N bits, filling with zeros",
        "lsr":   "Logical Shift Right — shifts a value right by N bits, filling with zeros (unsigned)",
        "asr":   "Arithmetic Shift Right — shifts a value right by N bits, preserving sign (signed)",
        "ror":   "Rotate Right — rotates bits right by N positions",
        "cmp":   "Compare — subtracts and sets flags, result is discarded",
        "cmn":   "Compare Negative — adds and sets flags, result is discarded",
        "tst":   "Test Bits — ANDs and sets flags, result is discarded",
        "neg":   "Negate — two's complement negation",
        "negs":  "Negate setting flags — like NEG but updates flags",
        "mvn":   "Move NOT — bitwise inversion of a register",
        "b":     "Branch — unconditional jump to a PC-relative address",
        "bl":    "Branch with Link — calls a subroutine; return address saved in x30 (LR)",
        "blr":   "Branch with Link to Register — calls a subroutine via address in a register",
        "br":    "Branch to Register — unconditional jump to the address in a register",
        "ret":   "Return — jumps to the address in x30 (LR), ending the current function",
        "b.eq":  "Branch if Equal — Z=1 (last comparison was equal)",
        "b.ne":  "Branch if Not Equal — Z=0",
        "b.lt":  "Branch if Less Than — N≠V (signed)",
        "b.gt":  "Branch if Greater Than — Z=0 and N=V (signed)",
        "b.le":  "Branch if Less or Equal — Z=1 or N≠V (signed)",
        "b.ge":  "Branch if Greater or Equal — N=V (signed)",
        "b.lo":  "Branch if Lower — C=0 (unsigned less than)",
        "b.hi":  "Branch if Higher — C=1 and Z=0 (unsigned greater than)",
        "b.ls":  "Branch if Lower or Same — C=0 or Z=1 (unsigned)",
        "b.hs":  "Branch if Higher or Same — C=1 (unsigned greater or equal)",
        "b.mi":  "Branch if Minus — N=1 (result was negative)",
        "b.pl":  "Branch if Plus — N=0 (result was non-negative)",
        "b.vs":  "Branch if Overflow Set — V=1",
        "b.vc":  "Branch if Overflow Clear — V=0",
        "b.cs":  "Branch if Carry Set — C=1",
        "b.cc":  "Branch if Carry Clear — C=0",
        "cbz":   "Compare and Branch if Zero — branches if register == 0, no flags affected",
        "cbnz":  "Compare and Branch if Not Zero — branches if register != 0, no flags affected",
        "tbz":   "Test and Branch if Zero — branches if a specific bit is 0",
        "tbnz":  "Test and Branch if Not Zero — branches if a specific bit is 1",
        "adrp":  "Address of Page — loads a 4 KB page-aligned PC-relative address into a register",
        "adr":   "Address — loads a byte-precise PC-relative address into a register",
        "nop":   "No Operation — does nothing; used for alignment or pipeline padding",
        "svc":   "Supervisor Call — triggers a syscall to the OS kernel (syscall number in x16)",
        "brk":   "Breakpoint — generates a debug exception (used by debuggers)",
        "dmb":   "Data Memory Barrier — ensures ordering of memory accesses",
        "dsb":   "Data Synchronization Barrier — waits for all memory accesses to complete",
        "isb":   "Instruction Synchronization Barrier — flushes the instruction pipeline",
        "csel":  "Conditional Select — sets Rd = Rn if condition true, else Rd = Rm",
        "cset":  "Conditional Set — sets Rd = 1 if condition true, else Rd = 0",
        "csetm": "Conditional Set Mask — sets Rd = -1 (all ones) if true, else 0",
        "cinc":  "Conditional Increment — sets Rd = Rn+1 if condition true, else Rd = Rn",
        "cneg":  "Conditional Negate — negates Rn if condition is true",
        "csinc": "Conditional Select Increment — Rd = Rn if true, else Rd = Rm + 1",
        "csinv": "Conditional Select Invert — Rd = Rn if true, else Rd = ~Rm",
        "csneg": "Conditional Select Negate — Rd = Rn if true, else Rd = -Rm",
        "clz":   "Count Leading Zeros — counts the number of leading zero bits in a register",
        "cls":   "Count Leading Sign Bits — counts consecutive bits equal to the sign bit (minus 1)",
        "rbit":  "Reverse Bits — reverses the order of all bits",
        "rev":   "Reverse Bytes — reverses byte order (big ↔ little endian)",
        "rev16": "Reverse Bytes in Halfwords — reverses bytes within each 16-bit halfword",
        "rev32": "Reverse Bytes in Words — reverses bytes within each 32-bit word",
        "uxth":  "Unsigned Extend Halfword — zero-extends bits [15:0] to 64 bits",
        "uxtb":  "Unsigned Extend Byte — zero-extends bits [7:0] to 64 bits",
        "sxth":  "Signed Extend Halfword — sign-extends bits [15:0] to 64 bits",
        "sxtb":  "Signed Extend Byte — sign-extends bits [7:0] to 64 bits",
        "sxtw":  "Signed Extend Word — sign-extends bits [31:0] to 64 bits",
        "ubfx":  "Unsigned Bit Field Extract — extracts a field of bits, zero-extends",
        "sbfx":  "Signed Bit Field Extract — extracts a field of bits, sign-extends",
        "bfi":   "Bit Field Insert — inserts bits from one register into another",
        "bfxil": "Bit Field Extract and Insert Low — copies low bits from one register to another",
        "extr":  "Extract Register — extracts a bit field spanning two registers (concatenation shift)",
    ]

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

#Preview(traits: .sizeThatFitsLayout) {
    @Previewable @State var sampleCode = (1...100).map { "Line \($0)" }.joined(separator: "\n")
    @Previewable @StateObject var previewAppState = AppState()

    CodeEditorView()
        .environmentObject(previewAppState)
        .onAppear {
            previewAppState.currentCode = sampleCode
        }
        .frame(width: 800, height: 600)
}
