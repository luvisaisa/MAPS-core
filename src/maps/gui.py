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
    
    def _select_files(self):
        """Open file dialog to select XML files."""
        files = filedialog.askopenfilenames(
            title="Select XML Files",
            filetypes=[("XML files", "*.xml"), ("All files", "*.*")]
        )
        
        if files:
            self.selected_files = list(files)
            self.file_label.config(text=f"{len(files)} files selected")
    
    def run(self):
        """Start the GUI application."""
        self.root.mainloop()


if __name__ == "__main__":
    app = NYTXMLGuiApp()
    app.run()
