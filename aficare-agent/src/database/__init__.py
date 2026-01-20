"""
Database module for AfiCare MediLink
Provides persistent data storage using SQLite
"""

from .database_manager import DatabaseManager, get_database

__all__ = ['DatabaseManager', 'get_database']