"""Tkinter GUI application for MAPS."""

import tkinter as tk
from tkinter import filedialog, messagebox, ttk
import os
from .parser import parse_multiple, export_excel
import pandas as pd


class NYTXMLGuiApp:
    """Main GUI application for parsing XML files."""
    
    def __init__(self):
        """Initialize the GUI application."""
        self.root = tk.Tk()
        self.root.title("MAPS - Medical Annotation Processing System")
        self.root.geometry("900x750")
        
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
        
        # Progress bar
        progress_frame = tk.Frame(self.root)
        progress_frame.pack(pady=10, padx=20, fill=tk.X)
        
        self.progress_var = tk.DoubleVar()
        self.progress_bar = ttk.Progressbar(
            progress_frame, 
            variable=self.progress_var, 
            maximum=100
        )
        self.progress_bar.pack(fill=tk.X)
        
        self.progress_label = tk.Label(progress_frame, text="Ready")
        self.progress_label.pack()
        
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
        
        # Log area
        self._create_log_area()
    
    def _create_log_area(self):
        """Create log/status display area."""
        log_frame = tk.Frame(self.root)
        log_frame.pack(pady=10, padx=20, fill=tk.BOTH, expand=True)
        
        log_label = tk.Label(log_frame, text="Status Log:", font=("Arial", 10, "bold"))
        log_label.pack(anchor=tk.W)
        
        # Text widget for logs
        self.log_text = tk.Text(log_frame, height=15, width=90, state=tk.DISABLED)
        self.log_text.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        
        # Scrollbar
        scrollbar = tk.Scrollbar(log_frame, command=self.log_text.yview)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        self.log_text.config(yscrollcommand=scrollbar.set)
    
    def _log_message(self, message: str):
        """Add message to log display."""
        self.log_text.config(state=tk.NORMAL)
        self.log_text.insert(tk.END, message + "\n")
        self.log_text.see(tk.END)
        self.log_text.config(state=tk.DISABLED)
    
    def _update_progress(self, value: float, message: str = ""):
        """Update progress bar and label."""
        self.progress_var.set(value)
        if message:
            self.progress_label.config(text=message)
        self.root.update_idletasks()
    
    def _select_files(self):
        """Open file dialog to select XML files."""
        files = filedialog.askopenfilenames(
            title="Select XML Files",
            filetypes=[("XML files", "*.xml"), ("All files", "*.*")]
        )
        
        if files:
            self.selected_files = list(files)
            self.file_label.config(text=f"{len(files)} files selected")
            self._log_message(f"Selected {len(files)} XML files")
    
    def _select_output_folder(self):
        """Open dialog to select output folder."""
        folder = filedialog.askdirectory(title="Select Output Folder")
        
        if folder:
            self.output_folder = folder
            self.output_label.config(text=f"Output: {os.path.basename(folder)}")
            self._log_message(f"Output folder: {folder}")
    
    def _parse_files(self):
        """Parse selected files and export results."""
        if not self.selected_files:
            messagebox.showerror("Error", "Please select XML files to parse")
            return
        
        if not self.output_folder:
            messagebox.showerror("Error", "Please select an output folder")
            return
        
        try:
            self._log_message("Starting parse operation...")
            self._update_progress(10, "Parsing XML files...")
            
            # Parse files
            main_dfs, _ = parse_multiple(self.selected_files)
            
            self._update_progress(70, "Combining results...")
            
            # Combine results
            if main_dfs:
                combined_df = pd.concat(main_dfs.values(), ignore_index=True)
                
                self._update_progress(85, "Exporting to Excel...")
                
                # Export to Excel
                output_path = os.path.join(self.output_folder, "parsed_results.xlsx")
                export_excel(combined_df, output_path)
                
                self._update_progress(100, "Complete!")
                
                self._log_message(f"Successfully parsed {len(main_dfs)} files")
                self._log_message(f"Exported {len(combined_df)} records to {output_path}")
                
                messagebox.showinfo(
                    "Success", 
                    f"Parsed {len(main_dfs)} files\nSaved to: {output_path}"
                )
            else:
                self._update_progress(0, "Failed")
                self._log_message("Warning: No data was parsed from the files")
                messagebox.showwarning("Warning", "No data was parsed from the files")
        
        except Exception as e:
            self._update_progress(0, "Error")
            error_msg = f"Parsing failed: {str(e)}"
            self._log_message(f"ERROR: {error_msg}")
            messagebox.showerror("Error", error_msg)
    
    def run(self):
        """Start the GUI application."""
        self.root.mainloop()


if __name__ == "__main__":
    app = NYTXMLGuiApp()
    app.run()
