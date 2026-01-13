from abc import ABC, abstractmethod
from typing import Dict, Any, List

class AfiCarePlugin(ABC):
    """
    Abstract Base Class for all AfiCare Disease Plugins.
    Every disease module (Malaria, TB, etc.) must inherit from this.
    """
    
    @property
    @abstractmethod
    def id(self) -> str:
        """Unique identifier for the plugin (e.g., 'malaria_v1')"""
        pass

    @property
    @abstractmethod
    def name(self) -> str:
        """Human readable name (e.g., 'Malaria Control Module')"""
        pass

    @abstractmethod
    def register_rules(self) -> List[Dict[str, Any]]:
        """
        Return a list of medical rules/decision trees.
        Example: IF fever > 38 AND rdt == positive THEN treat_malaria
        """
        pass

    @abstractmethod
    def health_check(self) -> bool:
        """Self-check to ensure plugin assets/models are loaded"""
        pass
