#  GUI Testing Instructions

## Complete Workflow Test

### Setup
1. Close any running GUI windows
2. Run: `python3 -m src.maps`
3. Watch terminal for debug output ( DEBUG messages)

---

## Test Case 1: Add Single Folder
**Steps:**
1. Click "Select Folders" button in main GUI
2. Preview dialog opens with tree view
3. Click " Add Single Folder" button
4. Select folder "185" (or any folder with XML files)
5. **CHECK**: Tree view should show folder with XML file count
6. **CHECK**: Status at bottom should say "Selected: 1 folder(s)"
7. Click " Confirm Selection" button
8. **CHECK**: Preview dialog closes
9. **CHECK**: Main GUI listbox shows selected folder
10. **CHECK**: Folder count label shows " 1 folders selected"

**Expected Debug Output:**
```
 DEBUG: add_single_folder called
 DEBUG: User selected folder: /path/to/folder
 DEBUG: Added folder. Total folders: 1
 DEBUG: update_tree_view called with 1 folders
 DEBUG: Folder 'foldername' has X XML files
 DEBUG: Tree view updated, status: 1 folder(s)
 DEBUG: confirm_selection called with 1 folders
 DEBUG: Transferring 1 folders to main GUI
 DEBUG: Main GUI updated, closing preview dialog
```

---

## Test Case 2: Browse Parent Folder
**Steps:**
1. Click "Select Folders" button in main GUI
2. Preview dialog opens
3. Click " Browse Parent Folder" button
4. Select parent folder (e.g., "/Users/isa/Desktop/XML files parse")
5. **CHECK**: Checkbox dialog appears showing subfolders
6. **CHECK**: Subfolders with XML files are auto-checked ()
7. Select/deselect folders as needed
8. Click " Add Selected" button
9. **CHECK**: Checkbox dialog closes
10. **CHECK**: Tree view shows all selected folders
11. **CHECK**: Status shows "Selected: X folder(s)"
12. Click " Confirm Selection" button
13. **CHECK**: Preview dialog closes
14. **CHECK**: Main GUI shows all folders
15. **CHECK**: Folder count label updates

**Expected Debug Output:**
```
 DEBUG: browse_parent_folder called
 DEBUG: User selected: /path/to/parent
 DEBUG: Scanning subfolders in /path/to/parent
 DEBUG: Found X items in parent folder
 DEBUG: Checking item: folder1 (isdir=True)
 DEBUG:   → Subfolder 'folder1' has Y XML files
 DEBUG: Found X subfolders total
 DEBUG: Creating checkbox dialog
 DEBUG: Checkbox dialog created successfully
 DEBUG: update_tree_view called with X folders
 DEBUG: confirm_selection called with X folders
```

---

## Test Case 3: No Subfolders Found
**Steps:**
1. Click "Browse Parent Folder"
2. Select folder "185" (a folder with XML files directly, no subfolders)
3. **CHECK**: Popup appears: "No subfolders found"
4. Click OK
5. **Alternative**: Use "Add Single Folder" for folders like this

**Expected Debug Output:**
```
 DEBUG: browse_parent_folder called
 DEBUG: User selected: /path/to/folder
 DEBUG: Scanning subfolders in /path/to/folder
 DEBUG: Found X items in parent folder
 DEBUG: Checking item: file.xml (isdir=False)
 DEBUG: Found 0 subfolders total
 DEBUG: No subfolders - showing info dialog
```

---

## Common Issues & Solutions

### Issue: "Nothing happens when I click buttons"
- **Check**: Are debug messages appearing in terminal?
- **If NO**: Function not being called - check button wiring
- **If YES**: Follow debug messages to see where it stops

### Issue: "Folders don't appear in main GUI"
- **Check**: Did you click " Confirm Selection" in preview dialog?
- **Solution**: Must click confirm button to transfer folders

### Issue: "Browse Parent Folder shows 'No subfolders'"
- **Reason**: Selected folder contains XML files directly, not in subfolders
- **Solution**: Use "Add Single Folder" instead for such folders

### Issue: "Tree view is empty after selecting"
- **Check**: Terminal shows folders were added?
- **Check**: Status label shows "Selected: X folder(s)"?
- **Try**: Click "Clear All" then try again

---

## Understanding the Workflow

```

         Main GUI Window                 
                                         
  [Select Folders] ← Click here first   
                                         
  Listbox: (empty until confirmed)      
                                         

                  ↓

      Preview Dialog (Selection)         
                                         
  [ Add Single] [ Browse Parent]    
                                         
  Tree View:                             
    Folder1 (5 XML files)             
       file1.xml                       
       file2.xml                       
                                         
  Status: Selected: 1 folder(s)          
                                         
  [ Confirm Selection] ← Click to     
                           transfer!     

                  ↓

         Main GUI Window                 
                                         
  Listbox:                               
   • /path/to/Folder1                   
                                         
   1 folders selected                 
                                         
  [1⃣ Single Export] [2⃣ Multi Export] 

```

---

## Summary

1. **Preview Dialog** = Selection workspace (add/remove folders here)
2. **Tree View** = Preview of what you've selected
3. **Confirm Button** = Transfer selections to main GUI
4. **Main GUI** = Final list for export

**You must click " Confirm Selection" to transfer folders from preview to main GUI!**
