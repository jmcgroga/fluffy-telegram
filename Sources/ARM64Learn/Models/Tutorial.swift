import SwiftUI
import Foundation

// MARK: - Tutorial Category

struct TutorialCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let tutorials: [Tutorial]
}

// MARK: - Tutorial

struct Tutorial: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let content: String          // Markdown content
    let sampleCode: String?
    let language: CodeLanguage
    let memoryHighlights: [String]
    let difficulty: Difficulty

    enum Difficulty: String {
        case beginner     = "Beginner"
        case intermediate = "Intermediate"
        case advanced     = "Advanced"

        var color: Color {
            switch self {
            case .beginner:     return .green
            case .intermediate: return .orange
            case .advanced:     return .red
            }
        }

        var icon: String {
            switch self {
            case .beginner:     return "1.circle.fill"
            case .intermediate: return "2.circle.fill"
            case .advanced:     return "3.circle.fill"
            }
        }
    }
}
