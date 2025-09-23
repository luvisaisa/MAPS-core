"""Example of launching the GUI application."""

from src.maps import NYTXMLGuiApp


def main():
    """
    Launch the MAPS GUI application.
    
    This provides a user-friendly interface for:
    - Selecting XML files or folders
    - Parsing medical imaging annotation data
    - Exporting results to Excel
    - Tracking progress in real-time
    """
    print("Launching MAPS GUI...")
    app = NYTXMLGuiApp()
    app.run()


if __name__ == "__main__":
    main()
