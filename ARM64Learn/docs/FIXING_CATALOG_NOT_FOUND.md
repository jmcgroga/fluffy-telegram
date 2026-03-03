# Fixing "Tutorial catalog not found" Error

## Problem

You're seeing:
```
⚠️ Tutorial catalog not found, using fallback
```

This means the new tutorial resource files exist in your file system, but **Xcode doesn't know about them** and hasn't included them in the app bundle.

## What's the Fallback?

The fallback is the old `TutorialLoader.swift` system which:
- Has all tutorial content hardcoded as Swift string literals
- Loads markdown from Resources/Tutorials/ (the .md files that already existed)
- Uses inline sample code stored in variables like `t01`, `t02`, etc.

So your app still works, but it's using the old system instead of the new clean file-based system.

## Why This Happens

When you create files using tools or scripts, they exist in the file system but:
1. Xcode project doesn't know they exist
2. They're not in the Xcode project navigator
3. They won't be copied to the app bundle during build
4. `Bundle.main.url()` can't find them at runtime

## The Solution

You need to **add the resource files to your Xcode project**.

### Step 1: Add Files to Xcode Project

1. **In Xcode**, right-click on the project navigator (left sidebar)
2. Select **"Add Files to ARM64Learn..."**
3. **Navigate to** your `Resources/Tutorials/` folder
4. **Select ALL these files**:
   ```
   catalog.json
   01_introduction.json
   01_introduction.s
   02_registers.json
   02_registers.s
   03_memory_addressing.json
   03_memory_addressing.s
   04_data_movement.json
   04_data_movement.s
   05_arithmetic.json
   05_arithmetic.s
   06_logical_ops.json
   06_logical_ops.s
   07_branches.json
   07_branches.s
   08_stack_functions.json
   08_stack_functions.s
   09_simd_neon.json
   09_simd_neon.s
   10_interfacing_c.json
   10_interfacing_c.c
   ```
   
   (The .md files should already be in the project)

5. **Important options**:
   - ☑️ **"Copy items if needed"** (check this)
   - ☑️ **"Create folder references"** (NOT "Create groups")
   - ☑️ **Add to targets: "ARM64Learn"** (check this)
   
6. Click **"Add"**

### Step 2: Verify Build Phases

After adding files, make sure they'll be copied to the app bundle:

1. **Click** on the ARM64Learn project (top of navigator)
2. **Select** the ARM64Learn target (in the middle pane)
3. Click the **"Build Phases"** tab
4. **Expand** "Copy Bundle Resources"
5. **Verify** all your new files are listed there:
   - catalog.json
   - All .json files (10 files)
   - All .s files (9 files)
   - All .c files (1 file)
   - All .md files (10 files)

If any are missing:
1. Click the **"+"** button at the bottom of the list
2. Find and add the missing files

### Step 3: Clean and Rebuild

1. **Clean build folder**: Product → Clean Build Folder (⇧⌘K)
2. **Build**: ⌘B
3. **Run**: ⌘R

### Step 4: Check Console Output

With the updated `TutorialLoaderNew.swift`, you'll now see detailed logging:

**If files are found:**
```
📦 Bundle resource path: /path/to/app.app/Contents/Resources
📂 Looking for tutorials in: /path/to/app.app/Contents/Resources/Resources/Tutorials
✅ Found 31 files in Resources/Tutorials/:
   - 01_introduction.json
   - 01_introduction.md
   - 01_introduction.s
   - catalog.json
   ...
✅ Successfully loaded catalog with 3 categories
📖 Loading category: Getting Started with 3 tutorials
      Loading tutorial: 01_introduction
      ✓ Found metadata at: 01_introduction.json
      ✓ Found content: 01_introduction.md
      ✓ Found sample code: 01_introduction.s
      ✅ Tutorial 'Introduction to ARM64' loaded successfully
...
🎉 Total categories loaded: 3
```

**If files are NOT found:**
```
📦 Bundle resource path: /path/to/app.app/Contents/Resources
📂 Looking for tutorials in: /path/to/app.app/Contents/Resources/Resources/Tutorials
❌ Resources/Tutorials/ directory does not exist in bundle
⚠️ Tutorial catalog not found, using fallback
```

## Alternative: Check Bundle Manually

You can also manually inspect what's in your app bundle:

1. **Build** the app (⌘B)
2. In Xcode, go to **Product → Show Build Folder in Finder**
3. Navigate to: `Debug/ARM64Learn.app/Contents/Resources/`
4. Check if `Resources/Tutorials/` folder exists
5. Check if all your files are there

## Common Issues

### Issue: "Create groups" vs "Create folder references"

**Problem**: If you used "Create groups", Xcode flattens the structure.

**Solution**: 
1. Delete the added files from Xcode (just remove reference, don't delete from disk)
2. Add them again, but choose "Create folder references" this time
3. You'll see a blue folder icon (not yellow) in the project navigator

### Issue: Files added but not in target

**Problem**: Files were added but ARM64Learn target wasn't selected.

**Solution**:
1. Select any of the new files in the project navigator
2. Open the **File Inspector** (⌥⌘1)
3. Under "Target Membership", check **ARM64Learn**

### Issue: Build cache issue

**Problem**: Old build is cached.

**Solution**:
1. Product → Clean Build Folder (⇧⌘K)
2. Quit and restart Xcode
3. Build again (⌘B)

## Verification Checklist

- [ ] All resource files added to Xcode project
- [ ] Files visible in project navigator
- [ ] Files show blue folder icon (folder references)
- [ ] All files checked in "Copy Bundle Resources"
- [ ] Clean build performed
- [ ] Console shows "✅ Successfully loaded catalog"
- [ ] No "⚠️ Tutorial catalog not found" warning
- [ ] Tutorials load and display correctly in app

## Quick Diagnostic

Run the app and look at the console output. The new detailed logging will tell you exactly what's wrong:

- **"❌ Resources/Tutorials/ directory does not exist"** → Files not in bundle, check Build Phases
- **"❌ Metadata not found for tutorial: XX"** → .json files missing
- **"❌ Content file not found: XX.md"** → .md files missing
- **"⚠️ Sample code file not found: XX.s"** → .s/.c files missing

The emoji-prefixed logs make it easy to spot issues! 📦 ✅ ❌ ⚠️

## Success!

When everything works, you'll see:
```
🎉 Total categories loaded: 3
```

And no warning about fallback!
