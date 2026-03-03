# Tutorial Resources Structure

This directory contains all tutorial content for the ARM64 Learn app, organized in a clean, maintainable structure.

## Directory Structure

```
Resources/Tutorials/
├── catalog.json                    # Defines categories and tutorial order
├── 01_introduction.json            # Metadata for tutorial 1
├── 01_introduction.md              # Markdown content
├── 01_introduction.s               # Sample ARM64 assembly code
├── 02_registers.json               # Metadata for tutorial 2
├── 02_registers.md                 # Markdown content
├── 02_registers.s                  # Sample code
├── ...
├── 10_interfacing_c.json           # Metadata for tutorial 10
├── 10_interfacing_c.md             # Markdown content
└── 10_interfacing_c.c              # Sample C code (note: .c extension)
```

## File Types

### catalog.json
Defines the tutorial categories and which tutorials belong to each category.

```json
[
  {
    "name": "Getting Started",
    "icon": "star",
    "tutorials": [
      "01_introduction",
      "02_registers",
      "03_memory_addressing"
    ]
  }
]
```

### Tutorial Metadata (XX_name.json)
Each tutorial has a JSON metadata file containing:

```json
{
  "title": "Introduction to ARM64",
  "subtitle": "AArch64 architecture overview",
  "contentFile": "01_introduction.md",
  "sampleCodeFile": "01_introduction.s",
  "language": "arm64",
  "memoryHighlights": ["__TEXT", "__DATA"],
  "difficulty": "beginner"
}
```

**Fields:**
- `title`: Display title of the tutorial
- `subtitle`: Brief description shown in sidebar
- `contentFile`: Filename of the markdown content (usually matches the tutorial ID)
- `sampleCodeFile`: Filename of the sample code (`.s` for assembly, `.c` for C)
- `language`: Either `"arm64"` or `"c"`
- `memoryHighlights`: Array of memory segment names to highlight (`__TEXT`, `__DATA`, `STACK`, `HEAP`)
- `difficulty`: One of `"beginner"`, `"intermediate"`, or `"advanced"`

### Content Files (XX_name.md)
Markdown files containing the tutorial content. These support:
- Standard markdown formatting
- Code blocks with syntax highlighting
- Tables
- Lists

### Sample Code Files (XX_name.s or XX_name.c)
The actual code that appears in the editor when the tutorial is selected.
- `.s` files for ARM64 assembly
- `.c` files for C code

## Adding a New Tutorial

1. **Create the metadata file** (e.g., `11_my_tutorial.json`):
   ```json
   {
     "title": "My Tutorial",
     "subtitle": "Brief description",
     "contentFile": "11_my_tutorial.md",
     "sampleCodeFile": "11_my_tutorial.s",
     "language": "arm64",
     "memoryHighlights": ["__TEXT"],
     "difficulty": "beginner"
   }
   ```

2. **Create the markdown content** (`11_my_tutorial.md`)

3. **Create the sample code** (`11_my_tutorial.s` or `.c`)

4. **Add to catalog.json**:
   ```json
   {
     "name": "Your Category",
     "icon": "star",
     "tutorials": [
       "11_my_tutorial"
     ]
   }
   ```

5. **Add files to Xcode project** (important!):
   - Select all new files in Finder
   - Drag them into the Xcode project navigator
   - Ensure "Copy items if needed" is checked
   - Select the ARM64Learn target

## Migration from Old System

The old system stored tutorials inline in `TutorialLoader.swift`. The new system uses:
- `TutorialLoaderNew.swift` - Loads from Resources directory
- Falls back to old `TutorialLoader.swift` if resources aren't found

Once all tutorials are migrated, `TutorialLoader.swift` can be removed.

## Benefits of This Structure

1. **Separation of Concerns**: Content, code, and metadata are in separate files
2. **Easy Editing**: Edit markdown and code in proper editors, not Swift strings
3. **Version Control Friendly**: Changes to one tutorial don't affect others
4. **Maintainable**: Adding new tutorials doesn't require recompiling Swift code
5. **Syntax Highlighting**: Code editors can properly highlight `.s` and `.c` files
6. **Collaboration**: Different people can work on different tutorials without conflicts
7. **Localization Ready**: Easy to add additional language directories later

## Testing

After adding or modifying tutorials:
1. Build and run the app
2. Check the console for warnings (⚠️) about missing files
3. Verify tutorials load correctly in the sidebar
4. Verify content and code display properly

## Fallback System

The loader gracefully handles missing files:
- If `catalog.json` is missing → falls back to old system
- If a tutorial's metadata is missing → skips that tutorial
- If markdown content is missing → skips that tutorial  
- If sample code is missing → tutorial loads without code
- All errors are logged to console with ⚠️ prefix
