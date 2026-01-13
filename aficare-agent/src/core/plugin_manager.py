import importlib
import os
import pkgutil
from typing import Dict, List, Type
from .interfaces.plugin import AfiCarePlugin

class PluginManager:
    """
    The 'Kernel' of AfiCare.
    Responsible for discovering and loading disease modules from the /plugins directory.
    """
    
    def __init__(self, plugin_dir: str = "plugins"):
        self.plugin_dir = plugin_dir
        self.plugins: Dict[str, AfiCarePlugin] = {}

    def discover_plugins(self):
        """Scans the plugins directory and imports found modules."""
        # Logic to walk through the plugins/ directory
        # For now, we will perform a manual import simulation for the Pilot
        pass

    def register_plugin(self, plugin: AfiCarePlugin):
        """Registers a verified plugin into the core system."""
        print(f"🔌 Loading Plugin: {plugin.name} ({plugin.id})...")
        if plugin.health_check():
            self.plugins[plugin.id] = plugin
            print(f"✅ {plugin.name} ready.")
        else:
            print(f"❌ {plugin.name} failed health check!")

    def get_all_rules(self) -> List[dict]:
        """Aggregates medical rules from ALL loaded plugins."""
        all_rules = []
        for plugin in self.plugins.values():
            all_rules.extend(plugin.register_rules())
        return all_rules
