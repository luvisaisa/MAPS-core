"""Utility functions for MAPS."""

import logging
from typing import Any


def setup_logger(name: str, level: int = logging.INFO) -> logging.Logger:
    """
    Set up a logger with consistent formatting.
    
    Args:
        name: Logger name
        level: Logging level
        
    Returns:
        Configured logger instance
    """
    logger = logging.getLogger(name)
    logger.setLevel(level)
    
    if not logger.handlers:
        handler = logging.StreamHandler()
        formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        handler.setFormatter(formatter)
        logger.addHandler(handler)
    
    return logger


def format_parse_summary(parse_case: str, record_count: int, file_name: str) -> str:
    """
    Format a summary string for parse results.
    
    Args:
        parse_case: Detected parse case
        record_count: Number of records parsed
        file_name: Name of parsed file
        
    Returns:
        Formatted summary string
    """
    return f"[{parse_case}] {file_name}: {record_count} records"
