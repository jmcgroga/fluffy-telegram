import SwiftUI
import AppKit

// MARK: - Console Output View (auto-scrolling output)

struct ConsoleOutputView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = NSColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1.0)
        textView.textColor = NSColor(red: 0.80, green: 0.85, blue: 0.80, alpha: 1.0)
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Check if text actually changed to avoid unnecessary updates
        if context.coordinator.lastText == text {
            return
        }
        context.coordinator.lastText = text

        // Apply styled text with color coding
        let attributed = buildAttributedString(text)
        textView.textStorage?.setAttributedString(attributed)

        // Auto-scroll to bottom on next run loop
        textView.scrollToEndOfDocument(nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        weak var textView: NSTextView?
        var lastText: String = ""
    }

    private func buildAttributedString(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor(red: 0.80, green: 0.85, blue: 0.80, alpha: 1.0)
        ]

        let lines = text.components(separatedBy: "\n")
        for (i, line) in lines.enumerated() {
            var attrs = baseAttrs
            // Color coding by content
            if line.contains("error:") || line.contains("FAILED") || line.contains("Error") {
                attrs[.foregroundColor] = NSColor.systemRed
            } else if line.contains("warning:") {
                attrs[.foregroundColor] = NSColor.systemYellow
            } else if line.contains("✓") || line.contains("succeeded") {
                attrs[.foregroundColor] = NSColor.systemGreen
            } else if line.hasPrefix("(lldb)") || line.hasPrefix("//") {
                attrs[.foregroundColor] = NSColor.systemBlue
            } else if line.hasPrefix("$") || line.hasPrefix(">") || line.hasPrefix("─") {
                attrs[.foregroundColor] = NSColor.systemCyan
            }

            result.append(NSAttributedString(string: line, attributes: attrs))
            if i < lines.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: baseAttrs))
            }
        }
        return result
    }
}
