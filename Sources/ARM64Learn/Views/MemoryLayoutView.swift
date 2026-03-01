import SwiftUI

// MARK: - Memory Layout View

struct MemoryLayoutView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: MemTab = .segments
    @State private var selectedRegCategory: Register.Category = .general

    enum MemTab: String, CaseIterable {
        case segments = "Segments"
        case registers = "Registers"
        case stack = "Stack"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "memorychip")
                    .foregroundStyle(.purple)
                Text("Memory")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Tab", selection: $selectedTab) {
                    ForEach(MemTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.regularMaterial)

            Divider()

            // Content
            switch selectedTab {
            case .segments:
                SegmentsView(memState: appState.memoryState)
            case .registers:
                RegistersView(registers: appState.memoryState.registers,
                              selectedCategory: $selectedRegCategory)
            case .stack:
                StackVisualizationView(memState: appState.memoryState)
            }
        }
        .background(.windowBackground)
    }
}

// MARK: - Segments View

struct SegmentsView: View {
    let memState: MemoryState
    @State private var expandedSegments: Set<UUID> = []

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Address space indicator
                AddressSpaceBar(segments: memState.segments)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                Divider()

                // Segment list (high address → low address)
                ForEach(memState.segments) { segment in
                    SegmentRowView(
                        segment: segment,
                        isHighlighted: memState.highlightedSegmentNames.contains(segment.name),
                        isExpanded: expandedSegments.contains(segment.id)
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if expandedSegments.contains(segment.id) {
                                expandedSegments.remove(segment.id)
                            } else {
                                expandedSegments.insert(segment.id)
                            }
                        }
                    }
                    Divider()
                }

                // Legend
                MemoryLegend()
                    .padding(12)
            }
        }
    }
}

// MARK: - Address Space Bar

struct AddressSpaceBar: View {
    let segments: [MemorySegment]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Virtual Address Space (ARM64 macOS)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 2) {
                ForEach(segments) { seg in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(seg.color.opacity(0.8))
                        .frame(height: 20)
                        .overlay(
                            Text(seg.name)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                        )
                }
            }
            .frame(height: 20)

            HStack {
                Text("0x0")
                Spacer()
                Text("Stack top")
            }
            .font(.system(size: 9, weight: .regular, design: .monospaced))
            .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Segment Row

struct SegmentRowView: View {
    let segment: MemorySegment
    let isHighlighted: Bool
    let isExpanded: Bool
    let toggleAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Segment header
            Button(action: toggleAction) {
                HStack(spacing: 10) {
                    // Color swatch
                    RoundedRectangle(cornerRadius: 3)
                        .fill(segment.color)
                        .frame(width: 12, height: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(segment.name)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.primary)
                            Text(segment.permissions)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(segment.color.opacity(0.15))
                                )
                        }
                        Text(segment.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(segment.formattedSize)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 2) {
                            Text(segment.formattedStart)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(isHighlighted ? segment.color.opacity(0.08) : Color.clear)

            // Expanded sections
            if isExpanded {
                VStack(spacing: 0) {
                    // Description
                    HStack {
                        Text(segment.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 6)
                    .padding(.bottom, 8)

                    // Sections
                    ForEach(segment.sections) { section in
                        SectionRowView(section: section, parentColor: segment.color)
                        Divider()
                            .padding(.leading, 24)
                    }
                }
                .background(segment.color.opacity(0.04))
            }
        }
    }
}

// MARK: - Section Row

struct SectionRowView: View {
    let section: MemorySection
    let parentColor: Color

    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(parentColor.opacity(0.4))
                .frame(width: 3)
                .padding(.leading, 21)

            VStack(alignment: .leading, spacing: 1) {
                Text(section.name)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
                Text(section.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(section.formattedOffset)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text("\(section.size) B")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
        .padding(.trailing, 12)
    }
}

// MARK: - Memory Legend

struct MemoryLegend: View {
    let items: [(String, Color, String)] = [
        ("__TEXT", .blue,   "Code + read-only data (r-x)"),
        ("__DATA", .green,  "Mutable data (rw-)"),
        ("HEAP",   Color(red: 1, green: 0.6, blue: 0), "Dynamic allocation (rw-)"),
        ("STACK",  .purple, "Call frames (rw-, grows ↓)"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LEGEND")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 2)

            ForEach(items, id: \.0) { name, color, desc in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: 12, height: 12)
                    Text(name)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    Text("—")
                        .foregroundStyle(.tertiary)
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
        )
    }
}

// MARK: - Registers View

struct RegistersView: View {
    let registers: [Register]
    @Binding var selectedCategory: Register.Category

    var filteredRegisters: [Register] {
        registers.filter { $0.category == selectedCategory }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Category", selection: $selectedCategory) {
                ForEach(Register.Category.allCases, id: \.self) { cat in
                    Text(cat.rawValue).tag(cat)
                }
            }
            .pickerStyle(.segmented)
            .padding(10)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredRegisters) { reg in
                        RegisterRowView(register: reg)
                        Divider()
                            .padding(.leading, 12)
                    }
                }
            }
        }
    }
}

// MARK: - Register Row

struct RegisterRowView: View {
    let register: Register
    @State private var showDecimal = false

    var body: some View {
        HStack(spacing: 10) {
            // Register name
            Text(register.name)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(width: 80, alignment: .leading)

            // Alias
            if let alias = register.alias {
                Text(alias)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .leading)
            } else {
                Color.clear.frame(width: 40)
            }

            Spacer()

            // Value (toggle hex/decimal)
            Button {
                showDecimal.toggle()
            } label: {
                Text(showDecimal ? register.decValue : register.hexValue)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(register.value == 0 ? .tertiary : .primary)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .help("Click to toggle hex/decimal")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .help(register.description)
    }
}

// MARK: - Stack Visualization

struct StackVisualizationView: View {
    let memState: MemoryState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Stack header info
                VStack(alignment: .leading, spacing: 8) {
                    Text("ARM64 Stack Frame Layout")
                        .font(.system(size: 13, weight: .semibold))

                    Text("The stack grows downward from high to low addresses. Each function creates a frame by decrementing sp.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)

                Divider()

                // Visual stack diagram
                StackDiagram()
                    .padding(12)

                Divider()

                // Stack rules
                VStack(alignment: .leading, spacing: 10) {
                    RuleRow(number: "1", text: "sp must be 16-byte aligned before any BL instruction")
                    RuleRow(number: "2", text: "x29 (fp) points to saved {x29, x30} pair at frame base")
                    RuleRow(number: "3", text: "x30 (lr) holds return address, saved by BL instruction")
                    RuleRow(number: "4", text: "Callee-saved registers (x19–x28) preserved across calls")
                    RuleRow(number: "5", text: "Local variables placed below saved registers")
                }
                .padding(12)
            }
        }
    }
}

// MARK: - Stack Diagram

struct StackDiagram: View {
    let items: [(String, Color, String)] = [
        ("← Higher addresses (caller)", .clear, ""),
        ("Caller's frame", .gray, "..."),
        ("─────── sp before prologue ───────", .clear, ""),
        ("[x29]   saved Frame Pointer", .purple, "8 B"),
        ("[x29+8] saved Link Register (x30)", .purple, "8 B"),
        ("[sp+16] saved x19 (if used)", .orange, "8 B"),
        ("[sp+24] saved x20 (if used)", .orange, "8 B"),
        ("[sp+32] local variable 1", .green, "8 B"),
        ("[sp+40] local variable 2", .green, "8 B"),
        ("─────── sp after prologue ────────", .clear, ""),
        ("← Lower addresses (new sp)", .clear, ""),
    ]

    var body: some View {
        VStack(spacing: 1) {
            ForEach(items.indices, id: \.self) { i in
                let item = items[i]
                if item.1 == .clear {
                    Text(item.0)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                } else {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(item.1.opacity(0.3))
                            .frame(width: 8)
                        Text(item.0)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(item.2)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                    .background(item.1.opacity(0.08))
                    .border(item.1.opacity(0.2), width: 0.5)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Rule Row

struct RuleRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.purple))
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
