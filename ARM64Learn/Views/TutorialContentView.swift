import SwiftUI

// MARK: - Tutorial Content View

struct TutorialContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Panel header
            PanelHeader(title: "Tutorial", systemImage: "book.fill", tint: .blue)

            Divider()

            if let tutorial = appState.selectedTutorial {
                NativeMarkdownView(markdown: tutorial.content)
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

// MARK: - Native Markdown Renderer

struct NativeMarkdownView: View {

    let markdown: String

    private enum MdBlock {
        case h1(String), h2(String), h3(String), h4(String)
        case paragraph(String)
        case codeBlock(code: String, lang: String)
        case listItem(String)
        case table(headers: [String], rows: [[String]])
        case rule
    }

    private var blocks: [MdBlock] {
        var result: [MdBlock] = []
        let lines = markdown.components(separatedBy: "\n")
        var i = 0
        var tableHeaders: [String] = []
        var tableRows: [[String]] = []

        func flushTable() {
            guard !tableHeaders.isEmpty else { return }
            result.append(.table(headers: tableHeaders, rows: tableRows))
            tableHeaders = []
            tableRows = []
        }

        while i < lines.count {
            let line = lines[i]

            // Fenced code block
            if line.hasPrefix("```") {
                flushTable()
                let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                i += 1
                var code = ""
                while i < lines.count && !lines[i].hasPrefix("```") {
                    code += lines[i] + "\n"
                    i += 1
                }
                result.append(.codeBlock(code: code, lang: lang))
                i += 1
                continue
            }

            // Table row
            if line.hasPrefix("|") {
                let cells = line.split(separator: "|", omittingEmptySubsequences: false)
                    .dropFirst().dropLast()
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                let isSeparator = !cells.isEmpty &&
                    cells.allSatisfy { $0.allSatisfy { $0 == "-" || $0 == ":" || $0 == " " } }
                if !isSeparator {
                    if tableHeaders.isEmpty {
                        tableHeaders = cells
                    } else {
                        tableRows.append(cells)
                    }
                }
                i += 1
                continue
            } else {
                flushTable()
            }

            if line.hasPrefix("# ") {
                result.append(.h1(String(line.dropFirst(2))))
            } else if line.hasPrefix("## ") {
                result.append(.h2(String(line.dropFirst(3))))
            } else if line.hasPrefix("### ") {
                result.append(.h3(String(line.dropFirst(4))))
            } else if line.hasPrefix("#### ") {
                result.append(.h4(String(line.dropFirst(5))))
            } else if line.hasPrefix("---") || line.hasPrefix("===") {
                result.append(.rule)
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                result.append(.listItem(String(line.dropFirst(2))))
            } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                result.append(.paragraph(line))
            }
            i += 1
        }
        flushTable()
        return result
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(blocks.indices, id: \.self) { i in
                    blockView(for: blocks[i])
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func blockView(for block: MdBlock) -> some View {
        switch block {
        case .h1(let t):
            inlineText(t)
                .font(.system(size: 22, weight: .bold))
                .padding(.bottom, 12)
                .padding(.top, 4)
        case .h2(let t):
            VStack(alignment: .leading, spacing: 0) {
                inlineText(t)
                    .font(.system(size: 17, weight: .semibold))
                    .padding(.top, 20)
                    .padding(.bottom, 6)
                Divider()
            }
        case .h3(let t):
            inlineText(t)
                .font(.system(size: 15, weight: .semibold))
                .padding(.top, 16)
                .padding(.bottom, 4)
        case .h4(let t):
            inlineText(t)
                .font(.system(size: 14, weight: .semibold))
                .padding(.top, 12)
                .padding(.bottom, 4)
        case .paragraph(let t):
            inlineText(t)
                .font(.system(size: 14))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 6)
        case .codeBlock(let code, _):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code.hasSuffix("\n") ? String(code.dropLast()) : code)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color(red: 0.80, green: 0.84, blue: 0.96))
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(red: 0.12, green: 0.12, blue: 0.18))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 0.5))
            .padding(.vertical, 8)
        case .listItem(let t):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•")
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
                inlineText(t)
                    .font(.system(size: 14))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 3)
        case .table(let headers, let rows):
            MarkdownTableView(headers: headers, rows: rows)
                .padding(.vertical, 8)
        case .rule:
            Divider()
                .padding(.vertical, 12)
        }
    }

    private func inlineText(_ text: String) -> Text {
        let opts = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        guard let attr = try? AttributedString(markdown: text, options: opts) else {
            return Text(text)
        }
        return Text(attr)
    }
}

// MARK: - Markdown Table

private struct MarkdownTableView: View {
    let headers: [String]
    let rows: [[String]]

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                ForEach(headers.indices, id: \.self) { j in
                    Text(headers[j])
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if j < headers.count - 1 {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 0.5)
                    }
                }
            }
            .background(Color.secondary.opacity(0.1))

            Divider()

            // Data rows
            ForEach(rows.indices, id: \.self) { i in
                HStack(spacing: 0) {
                    ForEach(rows[i].indices, id: \.self) { j in
                        Text(rows[i][j])
                            .font(.system(size: 13))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if j < rows[i].count - 1 {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 0.5)
                        }
                    }
                }
                .background(i % 2 == 1 ? Color.secondary.opacity(0.05) : Color.clear)
                if i < rows.count - 1 { Divider() }
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
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
