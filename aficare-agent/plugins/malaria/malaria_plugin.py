from typing import List, Dict, Any
import json
import os
import sys
from pathlib import Path

# Fix import path issues
current_file = Path(__file__)
src_dir = current_file.parent.parent.parent / "src"
sys.path.insert(0, str(src_dir))

try:
    from core.interfaces.plugin import AfiCarePlugin
except ImportError:
    # Create a simple base class if the interface doesn't exist
    from abc import ABC, abstractmethod
    
    class AfiCarePlugin(ABC):
        @property
        @abstractmethod
        def id(self) -> str:
            pass
        
        @property
        @abstractmethod
        def name(self) -> str:
            pass
        
        @abstractmethod
        def register_rules(self) -> List[Dict[str, Any]]:
            pass
        
        @abstractmethod
        def health_check(self) -> bool:
            pass

class MalariaPlugin(AfiCarePlugin):
    """
    The Official Malaria Module for AfiCare.
    Implements WHO/MOH Guidelines for Malaria management.
    """

    def __init__(self):
        # We assume assets are relative to this file
        self.assets_path = os.path.join(os.path.dirname(__file__), 'assets')
        
    @property
    def id(self) -> str:
        return "plugin_malaria_core_v1"

    @property
    def name(self) -> str:
        return "Malaria Control Module (MOH/WHO)"

    def health_check(self) -> bool:
        """Check if we can read our own asset files."""
        try:
            with open(os.path.join(self.assets_path, 'malaria.json'), 'r') as f:
                return True
        except Exception as e:
            print(f"Malaria Plugin Error: {e}")
            return False

    def register_rules(self) -> List[Dict[str, Any]]:
        # In a real app, this would load from the JSON
        # For the pilot, we also return hardcoded key logic
        return [
            {
                "trigger": "symptom_fever",
                "condition": "> 37.5",
                "action": "recommend_test",
                "test_type": "mRDT"
            },
            {
                "trigger": "test_result_positive",
                "test_type": "mRDT",
                "action": "prescribe_medication",
                "medication": "Artemether-Lumefantrine (AL)"
            }
        ]
