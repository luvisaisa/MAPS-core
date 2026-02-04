# Quick Reference: New Folder Selection Features

## What's New? 

### 1. Select Multiple Folders at Once 
**Before:** Click folders one-by-one, click Cancel when done  
**Now:** Cmd+Click (Mac) or Ctrl+Click (Windows) to select multiple folders simultaneously in Finder

### 2. Preview Your Selection 
**Before:** Simple list showing only folder names  
**Now:** Collapsible tree showing:
-  Folder names with XML file counts
-  Individual XML filenames (expandable)
- Live status: "Selected: X folder(s)"

### 3. Clear Help Instructions 
**Before:** Generic descriptions  
**Now:** Detailed explanations with examples:

```
 SINGLE EXPORT = 1 Excel file with multiple sheets
   Example: Folders 157, 185, 186 → One file with 3 sheets

 MULTI EXPORT = Multiple Excel files (one per folder)
   Example: Folders 157, 185, 186 → Three separate files
```

---

## How to Use

### Step 1: Select Folders
1. Click **" Select Folders"** in main GUI
2. Preview dialog opens (800x600)
3. Click **" Browse for Folders"**
4. In Finder/Explorer:
   - **Cmd+Click** (Mac) or **Ctrl+Click** (Win) to select multiple
   - **Shift+Click** to select a range
5. Click **"Choose"** ### Step 2: Review Selection
- Tree view shows all selected folders
- Click **** to expand and see XML files
- Click **** to collapse folder
- See XML file counts: ` 185 (30 XML files)`
- Optional: Click **" Add Another Folder"** to add more
- Optional: Click **" Clear All"** to start over

### Step 3: Confirm
- Click **" Confirm Selection"**
- Folders appear in main GUI listbox
- Ready to export!

### Step 4: Export
Choose your export mode:
- ** 1⃣ SINGLE EXPORT** - Combine into one file
- ** 2⃣ MULTI EXPORT** - Separate files per folder

---

## Quick Tips 

 **Preview before you commit** - See exactly what you're selecting  
 **Expand folders** - Verify correct XML files are present  
 **Check file counts** - Ensure expected number of XMLs  
 **Add more anytime** - Use "Add Another Folder" button  
 **Clear if needed** - "Clear All" button resets selection  
 **Read help** - Click Help button for detailed export explanations

---

## Troubleshooting

**Problem:** Can't select multiple folders at once  
**Solution:** Make sure you're using Cmd+Click (Mac) or Ctrl+Click (Windows)

**Problem:** Tree view is empty  
**Solution:** Click "Browse for Folders" and select at least one folder

**Problem:** No XML files showing under folder  
**Solution:** Expand the folder by clicking the  arrow

**Problem:** Not sure which export mode to use  
**Solution:** Click Help button and read the  EXPORT OPTIONS section

---

## Testing

**Run the test launcher:**
```bash
python3 tests/test_new_folder_selection.py
```

**Or launch GUI directly:**
```bash
python3 scripts/launch_gui.py
```

---

**Status:** Ready to Use!  
**Created:** October 11, 2025
