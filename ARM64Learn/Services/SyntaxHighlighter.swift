import AppKit
import Foundation

// MARK: - Syntax Highlighter

final class SyntaxHighlighter {

    // MARK: Public API

    static func highlight(_ text: String, language: CodeLanguage) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: (text as NSString).length)

        // Base style: monospaced font, default text color
        result.addAttributes([
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: defaultParagraphStyle()
        ], range: fullRange)

        switch language {
        case .arm64: applyARM64Rules(to: result, source: text)
        case .c:     applyCRules(to: result, source: text)
        }

        return result
    }

    // MARK: - ARM64 Rules

    private static func applyARM64Rules(to attr: NSMutableAttributedString, source: String) {
        // Comments first so they override everything
        highlight(attr, source: source, pattern: "(?://|;)[^\n]*", color: .systemGreen)

        // Strings
        highlight(attr, source: source, pattern: #""[^"]*""#, color: .systemYellow)

        // Directives (e.g. .global, .text, .data)
        highlight(attr, source: source, pattern: #"\.[a-zA-Z_][a-zA-Z0-9_]*"#, color: .systemPurple)

        // Labels (identifier followed by colon at start of line or after whitespace)
        highlight(attr, source: source, pattern: #"(?m)^[ \t]*[a-zA-Z_][a-zA-Z0-9_.]*:"#,
                  color: .systemOrange, bold: true)

        // Instructions
        let instructions = arm64Instructions.joined(separator: "|")
        highlight(attr, source: source,
                  pattern: #"(?i)\b(?:"# + instructions + #")\b"#,
                  color: .systemBlue, bold: true)

        // Registers: x0-x30, w0-w30, sp, lr, fp, xzr, wzr, pc, v0-v31
        highlight(attr, source: source,
                  pattern: #"\b(?:[xw][0-9]{1,2}|sp|lr|fp|xzr|wzr|pc|nzcv|fpsr|v[0-9]{1,2}(?:\.[124816][bBhHsS])?)\b"#,
                  color: .systemTeal)

        // Numeric immediates  (#0x1F, #42, #-1)
        highlight(attr, source: source,
                  pattern: #"#-?(?:0[xX][0-9a-fA-F]+|[0-9]+)"#,
                  color: .systemRed)

        // @ modifiers (PAGE, PAGEOFF, GOT, etc.)
        highlight(attr, source: source,
                  pattern: #"@[A-Z_]+"#,
                  color: .systemIndigo)
    }

    // MARK: - C Rules

    private static func applyCRules(to attr: NSMutableAttributedString, source: String) {
        // Multi-line block comments
        highlight(attr, source: source, pattern: #"/\*[\s\S]*?\*/"#, color: .systemGreen)

        // Single-line comments
        highlight(attr, source: source, pattern: #"//[^\n]*"#, color: .systemGreen)

        // String literals
        highlight(attr, source: source, pattern: #""(?:[^"\\]|\\.)*""#, color: .systemYellow)

        // Character literals
        highlight(attr, source: source, pattern: #"'(?:[^'\\]|\\.)*'"#, color: .systemYellow)

        // Preprocessor directives
        highlight(attr, source: source, pattern: #"(?m)^[ \t]*#[a-zA-Z]+"#, color: .systemPurple)

        // Keywords
        let kws = cKeywords.joined(separator: "|")
        highlight(attr, source: source, pattern: #"\b(?:"# + kws + #")\b"#,
                  color: .systemBlue, bold: true)

        // Builtin types
        let types = cTypes.joined(separator: "|")
        highlight(attr, source: source, pattern: #"\b(?:"# + types + #")\b"#,
                  color: .systemTeal)

        // Numeric literals (hex, float, int)
        highlight(attr, source: source,
                  pattern: #"\b(?:0[xX][0-9a-fA-F]+[uUlL]*|[0-9]+(?:\.[0-9]*)?(?:[eE][+-]?[0-9]+)?[fFlLuU]*)\b"#,
                  color: .systemRed)

        // Function calls: name followed by '('
        highlight(attr, source: source,
                  pattern: #"\b([a-zA-Z_][a-zA-Z0-9_]*)(?=\s*\()"#,
                  color: .systemOrange)
    }

    // MARK: - Core Regex Highlighter

    private static func highlight(
        _ attr: NSMutableAttributedString,
        source: String,
        pattern: String,
        color: NSColor,
        bold: Bool = false,
        options: NSRegularExpression.Options = []
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        let nsSource = source as NSString
        let fullRange = NSRange(location: 0, length: nsSource.length)

        regex.enumerateMatches(in: source, options: [], range: fullRange) { match, _, _ in
            guard let match = match else { return }
            let range = match.range
            guard range.location != NSNotFound else { return }
            var attrs: [NSAttributedString.Key: Any] = [.foregroundColor: color]
            if bold {
                attrs[.font] = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
            }
            attr.addAttributes(attrs, range: range)
        }
    }

    // MARK: - Paragraph Style

    private static func defaultParagraphStyle() -> NSParagraphStyle {
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = 3
        ps.paragraphSpacing = 0
        return ps
    }

    // MARK: - ARM64 Instruction Table

    private static let arm64Instructions: [String] = [
        // Data movement
        "mov", "movz", "movk", "movn", "mvn",
        // Arithmetic
        "add", "adds", "sub", "subs", "neg", "negs",
        "mul", "madd", "msub", "mneg",
        "udiv", "sdiv",
        "adc", "adcs", "sbc", "sbcs", "ngc", "ngcs",
        // Logical / bitwise
        "and", "ands", "orr", "orn", "eor", "eon", "bic", "bics",
        // Shifts
        "lsl", "lsr", "asr", "ror",
        // Bit manipulation
        "clz", "cls", "rbit", "rev", "rev16", "rev32",
        "bfm", "bfi", "bfxil", "sbfm", "sbfiz", "sbfx", "ubfm", "ubfiz", "ubfx",
        "extr",
        // Load / Store
        "ldr", "ldrb", "ldrh", "ldrsb", "ldrsh", "ldrsw", "ldur",
        "str", "strb", "strh", "stur",
        "ldp", "stp", "ldnp", "stnp",
        "ldar", "ldarb", "ldarh", "ldaxr", "ldaxrb", "ldaxrh", "ldxr", "ldxrb", "ldxrh",
        "stlr", "stlrb", "stlrh", "stlxr", "stlxrb", "stlxrh", "stxr", "stxrb", "stxrh",
        // Address computation
        "adr", "adrp",
        // Branches
        "b", "bl", "blr", "br", "ret",
        "cbz", "cbnz", "tbz", "tbnz",
        "b\\.eq", "b\\.ne", "b\\.lt", "b\\.le", "b\\.gt", "b\\.ge",
        "b\\.lo", "b\\.ls", "b\\.hi", "b\\.hs",
        "b\\.mi", "b\\.pl", "b\\.vs", "b\\.vc", "b\\.al",
        "b\\.cs", "b\\.cc",
        // Conditionals
        "cmp", "cmn", "tst",
        "csel", "csinc", "csinv", "csneg", "cset", "csetm", "cinc", "cinv", "cneg",
        // Extend / sign-extend
        "sxtb", "sxth", "sxtw", "uxtb", "uxth", "uxtw",
        // Misc
        "nop", "svc", "brk", "hlt", "dmb", "dsb", "isb",
        "mrs", "msr",
        // FP / SIMD
        "fmov", "fadd", "fsub", "fmul", "fdiv", "fneg", "fabs", "fsqrt",
        "fcmp", "fcmpe", "fccmp", "fcsel",
        "fcvt", "fcvtzs", "fcvtzu", "scvtf", "ucvtf",
        "fmadd", "fmsub", "fnmadd", "fnmsub",
        "ld1", "ld2", "ld3", "ld4", "st1", "st2", "st3", "st4",
        "ins", "dup", "ext", "zip1", "zip2", "uzp1", "uzp2", "trn1", "trn2",
        "addv", "subv", "umov", "smov",
        "push", "pop",
    ]

    // MARK: - C Keyword Tables

    private static let cKeywords: [String] = [
        "auto", "break", "case", "char", "const", "continue",
        "default", "do", "double", "else", "enum", "extern",
        "float", "for", "goto", "if", "inline", "int",
        "long", "register", "restrict", "return", "short",
        "signed", "sizeof", "static", "struct", "switch",
        "typedef", "union", "unsigned", "void", "volatile", "while",
        "_Alignas", "_Alignof", "_Atomic", "_Bool", "_Complex",
        "_Generic", "_Imaginary", "_Noreturn", "_Static_assert",
        "_Thread_local", "NULL", "true", "false",
        "asm", "__asm__", "__volatile__",
    ]

    private static let cTypes: [String] = [
        "uint8_t", "uint16_t", "uint32_t", "uint64_t",
        "int8_t", "int16_t", "int32_t", "int64_t",
        "uintptr_t", "intptr_t", "ptrdiff_t",
        "size_t", "ssize_t", "off_t",
        "FILE", "bool", "va_list",
    ]
}

// MARK: - NSTextStorage Subclass for Live Highlighting

final class SyntaxHighlightingStorage: NSTextStorage {
    private let backing = NSMutableAttributedString()
    var language: CodeLanguage = .arm64
    var executionLine: Int? = nil

    override var string: String { backing.string }

    override func attributes(
        at location: Int,
        effectiveRange range: NSRangePointer?
    ) -> [NSAttributedString.Key: Any] {
        backing.attributes(at: location, effectiveRange: range)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        backing.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range, changeInLength: str.utf16.count - range.length)
        endEditing()
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        beginEditing()
        backing.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }

    override func processEditing() {
        let highlighted = SyntaxHighlighter.highlight(backing.string, language: language)
        backing.setAttributedString(highlighted)
        // Re-apply execution line background after syntax highlighting overwrites it
        applyExecutionLineBackground()
        super.processEditing()
    }

    func applyExecutionLineBackground() {
        guard let targetLine = executionLine, targetLine > 0, backing.length > 0 else { return }
        let string = backing.string as NSString
        var current = 1
        var idx = 0
        while idx < string.length {
            let lr = string.lineRange(for: NSRange(location: idx, length: 0))
            if current == targetLine {
                backing.addAttribute(.backgroundColor,
                                     value: NSColor.systemYellow.withAlphaComponent(0.25),
                                     range: lr)
                return
            }
            current += 1
            idx = NSMaxRange(lr)
        }
    }
}
