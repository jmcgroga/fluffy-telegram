import SwiftUI

// MARK: - Register Panel View

struct RegisterPanelView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedRegCategory: Register.Category = .general

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "cpu")
                    .foregroundStyle(.purple)
                Text("Registers")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.regularMaterial)

            Divider()

            // Registers Content
            RegisterListView(registers: appState.memoryState.registers,
                            selectedCategory: $selectedRegCategory)
        }
        .background(.windowBackground)
    }
}

// MARK: - Register List View

struct RegisterListView: View {
    let registers: [Register]
    @Binding var selectedCategory: Register.Category
    @State private var expandedCategories: Set<Register.Category> = [.general, .special, .flags]

    var registersByCategory: [Register.Category: [Register]] {
        Dictionary(grouping: registers, by: { $0.category })
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(Register.Category.allCases, id: \.self) { category in
                    let categoryRegisters = registersByCategory[category] ?? []
                    
                    if !categoryRegisters.isEmpty {
                        Section {
                            if expandedCategories.contains(category) {
                                ForEach(categoryRegisters) { reg in
                                    RegisterRowView(register: reg)
                                    
                                    if reg.id != categoryRegisters.last?.id {
                                        Divider()
                                            .padding(.leading, 12)
                                    }
                                }
                            }
                        } header: {
                            RegisterCategoryHeader(
                                category: category,
                                count: categoryRegisters.count,
                                isExpanded: expandedCategories.contains(category)
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if expandedCategories.contains(category) {
                                        expandedCategories.remove(category)
                                    } else {
                                        expandedCategories.insert(category)
                                    }
                                }
                            }
                        }
                        
                        Divider()
                    }
                }
            }
        }
    }
}

// MARK: - Register Category Header

struct RegisterCategoryHeader: View {
    let category: Register.Category
    let count: Int
    let isExpanded: Bool
    let action: () -> Void
    
    var categoryColor: Color {
        switch category {
        case .general: return .blue
        case .special: return .purple
        case .flags: return .orange
        }
    }
    
    var categoryIcon: String {
        switch category {
        case .general: return "square.grid.3x3"
        case .special: return "star.fill"
        case .flags: return "flag.fill"
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: categoryIcon)
                    .font(.caption)
                    .foregroundStyle(categoryColor)
                    .frame(width: 16)
                
                Text(category.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Text("(\(count))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

#Preview("Register Panel - Empty") {
    @Previewable @StateObject var previewAppState = AppState()
    
    RegisterPanelView()
        .environmentObject(previewAppState)
        .frame(width: 350, height: 800)
}

#Preview("Register Panel - With Data") {
    @Previewable @StateObject var previewAppState = AppState()
    
    RegisterPanelView()
        .environmentObject(previewAppState)
        .onAppear {
            // Update register values to show sample data
            if let x0Index = previewAppState.memoryState.registers.firstIndex(where: { $0.name == "x0" }) {
                previewAppState.memoryState.registers[x0Index].value = 0x0000000000000042
            }
            if let x1Index = previewAppState.memoryState.registers.firstIndex(where: { $0.name == "x1" }) {
                previewAppState.memoryState.registers[x1Index].value = 0x0000000000000001
            }
            if let spIndex = previewAppState.memoryState.registers.firstIndex(where: { $0.name == "sp" }) {
                previewAppState.memoryState.registers[spIndex].value = 0x16b9e3000
            }
            if let lrIndex = previewAppState.memoryState.registers.firstIndex(where: { $0.name == "x30" }) {
                previewAppState.memoryState.registers[lrIndex].value = 0x0000000100003f80
            }
            if let pcIndex = previewAppState.memoryState.registers.firstIndex(where: { $0.name == "pc" }) {
                previewAppState.memoryState.registers[pcIndex].value = 0x0000000100003f84
            }
        }
        .frame(width: 350, height: 800)
}
