"""Tkinter GUI application for MAPS."""

import tkinter as tk
from tkinter import filedialog, messagebox
import os
from .parser import parse_multiple, export_excel
import pandas as pd


class NYTXMLGuiApp:
    """Main GUI application for parsing XML files."""
    
    def __init__(self):
        """Initialize the GUI application."""
        self.root = tk.Tk()
        self.root.title("MAPS - Medical Annotation Processing System")
        self.root.geometry("800x600")
        
        self.selected_files = []
        self.output_folder = ""
        
        self._create_widgets()
    
    def _create_widgets(self):
        """Create and layout GUI widgets."""
        # Title label
        title_label = tk.Label(
            self.root, 
            text="MAPS XML Parser", 
            font=("Arial", 16, "bold")
        )
        title_label.pack(pady=20)
        
        # File selection frame
        file_frame = tk.Frame(self.root)
        file_frame.pack(pady=10)
        
        select_btn = tk.Button(
            file_frame,
            text="Select XML Files",
            command=self._select_files,
            width=20
        )
        select_btn.pack()
        
        self.file_label = tk.Label(file_frame, text="No files selected")
        self.file_label.pack(pady=5)
        
        # Output folder selection
        output_frame = tk.Frame(self.root)
        output_frame.pack(pady=10)
        
        output_btn = tk.Button(
            output_frame,
            text="Select Output Folder",
            command=self._select_output_folder,
            width=20
        )
        output_btn.pack()
        
        self.output_label = tk.Label(output_frame, text="No output folder selected")
        self.output_label.pack(pady=5)
        
        # Parse button
        parse_frame = tk.Frame(self.root)
        parse_frame.pack(pady=20)
        
        self.parse_btn = tk.Button(
            parse_frame,
            text="Parse Files",
            command=self._parse_files,
            width=20,
            height=2,
            bg="green",
            fg="white",
            font=("Arial", 12, "bold")
        )
        self.parse_btn.pack()
    
    def _select_files(self):
        """Open file dialog to select XML files."""
        files = filedialog.askopenfilenames(
            title="Select XML Files",
            filetypes=[("XML files", "*.xml"), ("All files", "*.*")]
        )
        
        if files:
            self.selected_files = list(files)
            self.file_label.config(text=f"{len(files)} files selected")
    
    def _select_output_folder(self):
        """Open dialog to select output folder."""
        folder = filedialog.askdirectory(title="Select Output Folder")
        
        if folder:
            self.output_folder = folder
            self.output_label.config(text=f"Output: {os.path.basename(folder)}")
    
    def _parse_files(self):
        """Parse selected files and export results."""
        if not self.selected_files:
            messagebox.showerror("Error", "Please select XML files to parse")
            return
        
        if not self.output_folder:
            messagebox.showerror("Error", "Please select an output folder")
            return
        
        try:
            # Parse files
            main_dfs, _ = parse_multiple(self.selected_files)
            
            # Combine results
            if main_dfs:
                combined_df = pd.concat(main_dfs.values(), ignore_index=True)
                
                # Export to Excel
                output_path = os.path.join(self.output_folder, "parsed_results.xlsx")
                export_excel(combined_df, output_path)
                
                messagebox.showinfo(
                    "Success", 
                    f"Parsed {len(main_dfs)} files\nSaved to: {output_path}"
                )
            else:
                messagebox.showwarning("Warning", "No data was parsed from the files")
        
        except Exception as e:
            messagebox.showerror("Error", f"Parsing failed: {str(e)}")
    
    def run(self):
        """Start the GUI application."""
        self.root.mainloop()


if __name__ == "__main__":
    app = NYTXMLGuiApp()
    app.run()
