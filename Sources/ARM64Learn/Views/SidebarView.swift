import SwiftUI

// MARK: - Sidebar (Table of Contents)

struct SidebarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "cpu")
                    .foregroundStyle(.blue)
                Text("ARM64 Learn")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.regularMaterial)

            Divider()

            // Tutorial list
            List(selection: Binding(
                get: { appState.selectedTutorial?.id },
                set: { id in
                    if let id {
                        let all = appState.tutorialCategories.flatMap(\.tutorials)
                        if let tut = all.first(where: { $0.id == id }) {
                            appState.selectTutorial(tut)
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
