import Foundation

// MARK: - Tutorial Metadata

struct TutorialMetadata: Codable {
    let title: String
    let subtitle: String
    let contentFile: String      // e.g., "01_introduction.md"
    let sampleCodeFile: String?  // e.g., "01_introduction.s" or "10_interfacing_c.c"
    let language: String         // "arm64" or "c"
    let memoryHighlights: [String]
    let difficulty: String       // "beginner", "intermediate", "advanced"
}

struct TutorialCategoryMetadata: Codable {
    let name: String
    let icon: String
    let tutorials: [String]      // List of tutorial IDs (e.g., "01_introduction")
}

// MARK: - Modern Tutorial Loader

final class TutorialLoaderNew {
    
    /// Load all tutorials from the Resources directory structure
    static func loadTutorials() -> [TutorialCategory] {
        // Load the catalog that defines categories and their tutorials
        guard let catalogURL = Bundle.main.url(
            forResource: "catalog",
            withExtension: "json",
            subdirectory: "Resources/Tutorials"
        ) else {
            print("⚠️ Tutorial catalog not found, using fallback")
            return TutorialLoader.loadTutorials()
        }
        
        guard let catalogData = try? Data(contentsOf: catalogURL),
              let catalog = try? JSONDecoder().decode([TutorialCategoryMetadata].self, from: catalogData) else {
            print("⚠️ Failed to parse catalog, using fallback")
            return TutorialLoader.loadTutorials()
        }
        
        // Load each category
        return catalog.compactMap { categoryMeta in
            let tutorials = categoryMeta.tutorials.compactMap { tutorialID in
                loadTutorial(id: tutorialID)
            }
            
            guard !tutorials.isEmpty else { return nil }
            
            return TutorialCategory(
                name: categoryMeta.name,
                icon: categoryMeta.icon,
                tutorials: tutorials
            )
        }
    }
    
    /// Load a single tutorial by its ID (e.g., "01_introduction")
    private static func loadTutorial(id: String) -> Tutorial? {
        // Load metadata JSON
        guard let metaURL = Bundle.main.url(
            forResource: id,
            withExtension: "json",
            subdirectory: "Resources/Tutorials"
        ) else {
            print("⚠️ Metadata not found for tutorial: \(id)")
            return nil
        }
        
        guard let metaData = try? Data(contentsOf: metaURL),
              let meta = try? JSONDecoder().decode(TutorialMetadata.self, from: metaData) else {
            print("⚠️ Failed to parse metadata for tutorial: \(id)")
            return nil
        }
        
        // Load markdown content
        let contentName = meta.contentFile.replacingOccurrences(of: ".md", with: "")
        guard let contentURL = Bundle.main.url(
            forResource: contentName,
            withExtension: "md",
            subdirectory: "Resources/Tutorials"
        ) else {
            print("⚠️ Content file not found: \(meta.contentFile)")
            return nil
        }
        
        guard let content = try? String(contentsOf: contentURL, encoding: .utf8) else {
            print("⚠️ Failed to read content file: \(meta.contentFile)")
            return nil
        }
        
        // Load sample code (optional)
        var sampleCode: String? = nil
        if let codeFile = meta.sampleCodeFile {
            let codeName = codeFile.replacingOccurrences(of: ".s", with: "").replacingOccurrences(of: ".c", with: "")
            let ext = codeFile.hasSuffix(".c") ? "c" : "s"
            
            if let codeURL = Bundle.main.url(
                forResource: codeName,
                withExtension: ext,
                subdirectory: "Resources/Tutorials"
            ) {
                sampleCode = try? String(contentsOf: codeURL, encoding: .utf8)
            } else {
                print("⚠️ Sample code file not found: \(codeFile)")
            }
        }
        
        // Parse language
        let language: CodeLanguage = meta.language == "c" ? .c : .arm64
        
        // Parse difficulty
        let difficulty: Tutorial.Difficulty
        switch meta.difficulty {
        case "intermediate": difficulty = .intermediate
        case "advanced": difficulty = .advanced
        default: difficulty = .beginner
        }
        
        return Tutorial(
            title: meta.title,
            subtitle: meta.subtitle,
            content: content,
            sampleCode: sampleCode,
            language: language,
            memoryHighlights: meta.memoryHighlights,
            difficulty: difficulty
        )
    }
}
