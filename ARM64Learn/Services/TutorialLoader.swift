import Foundation

// MARK: - Tutorial Metadata

struct TutorialMetadata: Codable {
    let title: String
    let subtitle: String
    let contentFile: String      // e.g., "01_introduction.md"
    let sampleCodeFile: String?  // e.g., "01_introduction.s.txt" or "10_interfacing_c.c"
    let language: String         // "arm64" or "c"
    let memoryHighlights: [String]
    let difficulty: String       // "beginner", "intermediate", "advanced"
}

struct TutorialCategoryMetadata: Codable {
    let name: String
    let icon: String
    let tutorials: [String]      // List of tutorial IDs (e.g., "01_introduction")
}

// MARK: - Tutorial Loader

final class TutorialLoader {
    
    /// Load all tutorials from the Resources directory structure
    static func loadTutorials() -> [TutorialCategory] {
        // Try to load catalog from bundle root (where files actually are)
        guard let catalogURL = Bundle.main.url(
            forResource: "catalog",
            withExtension: "json"
        ) else {
            print("❌ Tutorial catalog not found in bundle")
            return []
        }
        
        print("✅ Found catalog at: \(catalogURL.path)")
        
        guard let catalogData = try? Data(contentsOf: catalogURL),
              let catalog = try? JSONDecoder().decode([TutorialCategoryMetadata].self, from: catalogData) else {
            print("❌ Failed to parse catalog")
            return []
        }
        
        print("✅ Successfully parsed catalog with \(catalog.count) categories")
        
        // Load each category
        return catalog.compactMap { categoryMeta in
            print("📖 Loading category: \(categoryMeta.name)")
            let tutorials = categoryMeta.tutorials.compactMap { tutorialID in
                loadTutorial(id: tutorialID)
            }
            
            guard !tutorials.isEmpty else {
                print("   ⚠️ No tutorials loaded for category: \(categoryMeta.name)")
                return nil
            }
            
            print("   ✅ Loaded \(tutorials.count) tutorials for '\(categoryMeta.name)'")
            
            return TutorialCategory(
                name: categoryMeta.name,
                icon: categoryMeta.icon,
                tutorials: tutorials
            )
        }
    }
    
    /// Load a single tutorial by ID (e.g., "01_introduction")
    private static func loadTutorial(id: String) -> Tutorial? {
        // Load metadata JSON (from bundle root where files actually are)
        guard let metaURL = Bundle.main.url(
            forResource: id,
            withExtension: "json"
        ) else {
            print("   ❌ Metadata not found: \(id).json")
            return nil
        }
        
        guard let metaData = try? Data(contentsOf: metaURL),
              let meta = try? JSONDecoder().decode(TutorialMetadata.self, from: metaData) else {
            print("   ❌ Failed to parse metadata: \(id)")
            return nil
        }
        
        // Load markdown content from the file specified in metadata
        let contentName = meta.contentFile.replacingOccurrences(of: ".md", with: "")
        guard let contentURL = Bundle.main.url(
            forResource: contentName,
            withExtension: "md"
        ) else {
            print("   ❌ Content file not found: \(meta.contentFile)")
            return nil
        }
        
        guard let content = try? String(contentsOf: contentURL, encoding: .utf8) else {
            print("   ❌ Failed to read content: \(meta.contentFile)")
            return nil
        }
        
        // Load sample code from the file specified in metadata (optional)
        var sampleCode: String? = nil
        if let codeFile = meta.sampleCodeFile, !codeFile.isEmpty {
            // Determine the extension from the filename
            let ext = (codeFile as NSString).pathExtension
            let codeName = (codeFile as NSString).deletingPathExtension
            
            if let codeURL = Bundle.main.url(
                forResource: codeName,
                withExtension: ext
            ) {
                sampleCode = try? String(contentsOf: codeURL, encoding: .utf8)
                print("      ✓ Loaded code: \(codeFile)")
            } else {
                print("      ⚠️ Code file not found: \(codeFile)")
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
        
        print("      ✅ Loaded: \(meta.title)")
        
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
