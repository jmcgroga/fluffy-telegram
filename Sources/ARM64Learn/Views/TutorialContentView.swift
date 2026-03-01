import SwiftUI
import WebKit

// MARK: - Tutorial Content View

struct TutorialContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Panel header
            PanelHeader(title: "Tutorial", systemImage: "book.fill", tint: .blue)

            Divider()

            if let tutorial = appState.selectedTutorial {
                MarkdownWebView(markdown: tutorial.content)
                    .id(tutorial.id) // Force refresh when tutorial changes
            } else {
                EmptyStateView(
                    icon: "book.closed",
                    title: "No Tutorial Selected",
                    message: "Choose a tutorial from the sidebar to get started."
                )
            }
        }
        .background(.windowBackground)
    }
}

// MARK: - Markdown Web View

struct MarkdownWebView: NSViewRepresentable {
    let markdown: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        loadContent(webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        loadContent(webView)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private func loadContent(_ webView: WKWebView) {
        let html = buildHTML(from: markdown)
        webView.loadHTMLString(html, baseURL: nil)
    }

    // Simple Markdown → HTML converter
    private func buildHTML(from md: String) -> String {
        var lines = md.components(separatedBy: "\n")
        var html = ""
        var inCodeBlock = false
        var inTable = false

        for line in lines {
            // Code blocks
            if line.hasPrefix("```") {
                if inCodeBlock {
                    html += "</code></pre>\n"
                    inCodeBlock = false
                } else {
                    let lang = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
                    html += "<pre><code class=\"language-\(lang)\">"
                    inCodeBlock = true
                }
                continue
            }

            if inCodeBlock {
                html += escapeHTML(line) + "\n"
                continue
            }

            // Horizontal rule
            if line.hasPrefix("---") || line.hasPrefix("===") {
                html += "<hr/>\n"; continue
            }

            // Table rows
            if line.hasPrefix("|") {
                if !inTable {
                    html += "<table>\n"
                    inTable = true
                }
                let cells = line.split(separator: "|", omittingEmptySubsequences: false)
                    .dropFirst().dropLast()
                let cellsArr = Array(cells)
                // Skip separator rows
                if cellsArr.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).allSatisfy({ $0 == "-" || $0 == ":" }) }) {
                    continue
                }
                html += "<tr>"
                for cell in cellsArr {
                    let content = inlineMarkdown(cell.trimmingCharacters(in: .whitespaces))
                    html += "<td>\(content)</td>"
                }
                html += "</tr>\n"
                continue
            } else if inTable {
                html += "</table>\n"
                inTable = false
            }

            // Headings
            if line.hasPrefix("# ") {
                html += "<h1>\(inlineMarkdown(String(line.dropFirst(2))))</h1>\n"; continue
            }
            if line.hasPrefix("## ") {
                html += "<h2>\(inlineMarkdown(String(line.dropFirst(3))))</h2>\n"; continue
            }
            if line.hasPrefix("### ") {
                html += "<h3>\(inlineMarkdown(String(line.dropFirst(4))))</h3>\n"; continue
            }
            if line.hasPrefix("#### ") {
                html += "<h4>\(inlineMarkdown(String(line.dropFirst(5))))</h4>\n"; continue
            }

            // List items
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                html += "<li>\(inlineMarkdown(String(line.dropFirst(2))))</li>\n"; continue
            }

            // Empty line = paragraph break
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                html += "<br/>\n"; continue
            }

            // Normal paragraph
            html += "<p>\(inlineMarkdown(line))</p>\n"
        }

        if inTable { html += "</table>\n" }
        if inCodeBlock { html += "</code></pre>\n" }

        return wrapInPage(html)
    }

    private func inlineMarkdown(_ text: String) -> String {
        var s = escapeHTML(text)
        // Bold: **text**
        s = s.replacingOccurrences(of: "\\*\\*([^*]+)\\*\\*",
                                    with: "<strong>$1</strong>",
                                    options: .regularExpression)
        // Italic: *text* or _text_
        s = s.replacingOccurrences(of: "\\*([^*]+)\\*",
                                    with: "<em>$1</em>",
                                    options: .regularExpression)
        s = s.replacingOccurrences(of: "_([^_]+)_",
                                    with: "<em>$1</em>",
                                    options: .regularExpression)
        // Inline code: `code`
        s = s.replacingOccurrences(of: "`([^`]+)`",
                                    with: "<code>$1</code>",
                                    options: .regularExpression)
        return s
    }

    private func escapeHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func wrapInPage(_ body: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        :root {
            color-scheme: light dark;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            font-size: 14px;
            line-height: 1.7;
            color: light-dark(#1a1a1a, #e0e0e0);
            background: light-dark(#ffffff, #1e1e1e);
            margin: 0;
            padding: 16px 20px 32px;
        }
        h1 { font-size: 22px; font-weight: 700; margin: 0 0 12px; color: light-dark(#0a0a0a, #f0f0f0); }
        h2 { font-size: 17px; font-weight: 600; margin: 20px 0 8px; color: light-dark(#1a1a1a, #e0e0e0);
             padding-bottom: 4px; border-bottom: 1px solid light-dark(#e0e0e0, #333); }
        h3 { font-size: 15px; font-weight: 600; margin: 16px 0 6px; color: light-dark(#1a1a1a, #d0d0d0); }
        h4 { font-size: 14px; font-weight: 600; margin: 12px 0 4px; }
        p { margin: 6px 0; }
        li { margin: 3px 0; }
        code {
            font-family: 'SF Mono', 'Menlo', 'Monaco', monospace;
            font-size: 12px;
            background: light-dark(#f0f0f0, #2a2a2a);
            color: light-dark(#c7254e, #ff6b9d);
            padding: 1px 5px;
            border-radius: 3px;
        }
        pre {
            background: light-dark(#1e1e2e, #1e1e2e);
            color: #cdd6f4;
            padding: 14px 16px;
            border-radius: 8px;
            overflow-x: auto;
            margin: 10px 0;
            font-size: 12px;
            line-height: 1.5;
            border: 1px solid light-dark(#ddd, #333);
        }
        pre code {
            background: transparent;
            color: inherit;
            padding: 0;
            font-size: 12px;
        }
        table {
            border-collapse: collapse;
            width: 100%;
            margin: 10px 0;
            font-size: 13px;
        }
        td, th {
            border: 1px solid light-dark(#ddd, #444);
            padding: 6px 10px;
            text-align: left;
        }
        tr:nth-child(even) { background: light-dark(#f7f7f7, #252525); }
        hr { border: none; border-top: 1px solid light-dark(#e0e0e0, #333); margin: 16px 0; }
        strong { font-weight: 600; }
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Open external links in browser, not in the web view
            if action.navigationType == .linkActivated {
                if let url = action.request.url {
                    NSWorkspace.shared.open(url)
                }
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

// MARK: - Shared Components

struct PanelHeader: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.regularMaterial)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}
