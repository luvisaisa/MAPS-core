"""Launch script for MAPS GUI application."""

from src.maps.gui import NYTXMLGuiApp


def main():
    """Launch the GUI application."""
    app = NYTXMLGuiApp()
    app.run()


if __name__ == "__main__":
    main()
