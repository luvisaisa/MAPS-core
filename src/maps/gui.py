"""Tkinter GUI application for MAPS."""

import tkinter as tk
from tkinter import filedialog, messagebox
import os


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
    
    def run(self):
        """Start the GUI application."""
        self.root.mainloop()


if __name__ == "__main__":
    app = NYTXMLGuiApp()
    app.run()
