import SwiftUI

// MARK: - Tutorial List Sidebar

struct TutorialListSidebar: View {
    @EnvironmentObject private var appState: AppState
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Image(systemName: "cpu")
                    .foregroundStyle(.blue)
                Text("ARM64 Learn")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.borderless)
                .help("Close sidebar")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.regularMaterial)

            Divider()

            // Tutorial list
            List(selection: Binding(
                get: { appState.selectedTutorial?.id },
                set: { id in
                    guard let id else { return }
                    Task { @MainActor in
                        let all = appState.tutorialCategories.flatMap(\.tutorials)
                        if let tut = all.first(where: { $0.id == id }) {
                            appState.selectTutorial(tut)
                            // Auto-close sidebar after selection
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isPresented = false
                            }
                        }
                    }
                }
            )) {
                ForEach(appState.tutorialCategories) { category in
                    Section {
                        ForEach(category.tutorials) { tutorial in
                            TutorialRowView(tutorial: tutorial)
                                .tag(tutorial.id)
                        }
                    } header: {
                        Label(category.name, systemImage: category.icon)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            // Footer: selected tutorial info
            if let tut = appState.selectedTutorial {
                HStack {
                    Image(systemName: tut.difficulty.icon)
                        .foregroundStyle(tut.difficulty.color)
                    Text(tut.difficulty.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: tut.language.icon)
                        .foregroundStyle(.secondary)
                    Text(tut.language.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial)
            }
        }
        .frame(minWidth: 220)
    }
}

// MARK: - Tutorial Row

struct TutorialRowView: View {
    let tutorial: Tutorial
    @EnvironmentObject private var appState: AppState

    var isSelected: Bool {
        appState.selectedTutorial?.id == tutorial.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: tutorial.difficulty.icon)
                    .font(.caption2)
                    .foregroundStyle(tutorial.difficulty.color)
                Text(tutorial.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? .primary : .primary)
                Spacer()
            }
            Text(tutorial.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
#Preview("Sidebar View") {
    @Previewable @State var isPresented = true
    @Previewable @StateObject var previewAppState = AppState()
    
    TutorialListSidebar(isPresented: $isPresented)
        .environmentObject(previewAppState)
        .frame(width: 280, height: 600)
}

#Preview("Tutorial Row") {
    @Previewable @StateObject var previewAppState = AppState()
    
    List {
        TutorialRowView(tutorial: Tutorial(
            title: "Hello World in ARM64",
            subtitle: "Your first ARM64 assembly program",
            content: "Sample content",
            sampleCode: nil,
            language: .arm64,
            memoryHighlights: [],
            difficulty: .beginner
        ))
        TutorialRowView(tutorial: Tutorial(
            title: "Memory Management",
            subtitle: "Understanding stack and heap",
            content: "Sample content",
            sampleCode: nil,
            language: .arm64,
            memoryHighlights: [],
            difficulty: .intermediate
        ))
        TutorialRowView(tutorial: Tutorial(
            title: "SIMD Operations",
            subtitle: "Advanced vector processing",
            content: "Sample content",
            sampleCode: nil,
            language: .arm64,
            memoryHighlights: [],
            difficulty: .advanced
        ))
    }
    .environmentObject(previewAppState)
}

