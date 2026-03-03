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

**Structure:**
- Each category has a `name`, `icon` (SF Symbol name), and `tutorials` array
- The `tutorials` array contains tutorial IDs (without file extensions)
- Tutorial IDs correspond to the metadata filename (e.g., `"01_introduction"` → `01_introduction.json`)
- All file paths are specified in the individual tutorial metadata files

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
   
   ### Method 1: Add as Folder Reference (Recommended)
   
   This preserves the directory structure in the bundle:
   
   a. **Remove any existing tutorial files** from the project (if already added):
      - Select all tutorial files in Xcode's Project Navigator
      - Press Delete → Choose "Remove References" (NOT "Move to Trash")
   
   b. **Add the Tutorials folder as a folder reference**:
      - In Xcode, right-click in Project Navigator
      - Select "Add Files to 'ARM64Learn'..."
      - Navigate to your `ARM64Learn/Resources/Tutorials/` folder
      - Select the `Tutorials` folder (or the entire `Resources` folder)
      - **IMPORTANT**: In the dialog, ensure:
        - ✅ "Create folder references" is selected (blue folder icon)
        - ❌ NOT "Create groups" (yellow folder icon)
        - ✅ "Copy items if needed" is checked (if folder is outside project)
        - ✅ Your app target is selected under "Add to targets"
      - Click "Add"
   
   c. **Verify the setup**:
      - The folder should appear as a **blue folder** 📁 in Project Navigator
      - Select your target → Build Phases → Copy Bundle Resources
      - The folder should be listed there (e.g., `Tutorials` or `Resources`)
   
   ### Method 2: Add Individual Files
   
   If you prefer not to use folder references:
   
   a. Add all files individually to the project
   b. In Build Phases → Copy Bundle Resources
   c. For each file, you'll need to manually preserve the path structure
      - This is more complex and not recommended
   
   ### Verifying the Bundle Structure
   
   After building, check that files are in the correct location:
   
   1. **Build your app** (⌘B)
   2. **In Xcode**, select Product → Show Build Folder in Finder
   3. Navigate to: `Products/Debug/ARM64Learn.app`
   4. Right-click the app → Show Package Contents
   5. Go to `Contents/Resources/`
   6. You should see either:
      - `Resources/Tutorials/` (if you added the Resources folder)
      - `Tutorials/` (if you added just the Tutorials folder)
      - All files in the root (if folder structure wasn't preserved)
   
   The code will automatically detect which structure is present.

## Tutorial System

The tutorial system loads content from the Resources directory:
- `TutorialLoader.swift` - Loads tutorials from the catalog and resource files
- `catalog.json` - Defines tutorial categories and explicit file references

All tutorials are defined in the `Resources/Tutorials/` directory with:
- `.json` files for metadata
- `.md` files for markdown content
- `.s.txt` or `.c` files for sample code

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
2. **Check the console output** - it will show:
   - 📦 Bundle resource path
   - 📂 Contents of Resources folder
   - ✅ Where tutorials were found (e.g., "Resources/Tutorials", "Tutorials", or "bundle root")
   - Any missing files with ❌ or ⚠️ warnings
3. Verify tutorials load correctly in the sidebar
4. Verify content and code display properly

## Troubleshooting

### Warning: "unexpected C compiler invocation" for .s files

**Problem**: Xcode tries to compile `.s` assembly files even when they're in "Copy Bundle Resources"

**Solution**: Rename all `.s` files to `.s.txt`:
- `01_introduction.s` → `01_introduction.s.txt`
- Update the `sampleCodeFile` in `catalog.json` to use `.s.txt` extension
- The loader will correctly handle the extension automatically

### Tutorials not loading / Console shows "❌ Tutorial catalog not found"

**Problem**: The Tutorials folder structure isn't being preserved in the bundle

**Solution**: 
1. Check Build Phases → Copy Bundle Resources
2. Ensure the folder is added as a **folder reference** (blue folder), not a group
3. Run the app and check console output for detected path
4. The code will automatically try these locations:
   - `Resources/Tutorials/` (preferred)
   - `Tutorials/` (if only Tutorials folder added)
   - Bundle root (if files copied without folder structure)

### Files are in the bundle but not in subdirectory

**Problem**: Files are copied to the bundle root instead of preserving folder structure

**Solution**:
1. Remove files from project (Remove References only)
2. Re-add using "Add Files to..." with "Create folder references" option
3. Make sure the folder icon is **blue** (📁), not yellow
4. Rebuild and check the console output

### Console shows file paths but files still not loading

**Problem**: File encoding or permissions issue

**Solution**:
1. Check file permissions in Finder (should be readable)
2. Verify files are UTF-8 encoded
3. Check for invisible characters in filenames
4. Ensure no extra spaces in `catalog.json` file names

## How the Loader Works

The `TutorialLoader` automatically detects where tutorials are located:

1. **Auto-detection**: Tries multiple paths in order:
   - `Resources/Tutorials/` (preferred structure)
   - `Tutorials/` (if only Tutorials folder was added)
   - Bundle root (if files are flat in the bundle)

2. **Graceful error handling**:
   - If `catalog.json` is missing → returns empty array, logs error
   - If a tutorial's metadata is missing → skips that tutorial
   - If markdown content is missing → skips that tutorial  
   - If sample code is missing → tutorial loads without code
   - All errors are logged to console with ❌ or ⚠️ prefix

3. **Debug output**: The loader prints detailed information:
   - Bundle resource path
   - Contents of Resources folder
   - Detected tutorials location
   - Each file as it's loaded
   - Any errors encountered
