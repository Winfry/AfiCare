"""
Configuration Management for AfiCare Agent
"""

import yaml
import os
from pathlib import Path
from typing import Any, Dict, Optional
import logging

logger = logging.getLogger(__name__)


class Config:
    """Configuration manager for AfiCare Agent"""
    
    def __init__(self, config_path: str = "config/default.yaml"):
        self.config_path = config_path
        self.config_data = {}
        self._load_config()
    
    def _load_config(self):
        """Load configuration from YAML file"""
        
        try:
            config_file = Path(self.config_path)
            
            if not config_file.exists():
                logger.warning(f"Config file not found: {self.config_path}")
                self._create_default_config()
                return
            
            with open(config_file, 'r', encoding='utf-8') as f:
                self.config_data = yaml.safe_load(f) or {}
            
            # Override with environment variables
            self._load_env_overrides()
            
            logger.info(f"Configuration loaded from {self.config_path}")
            
        except Exception as e:
            logger.error(f"Error loading config: {str(e)}")
            self.config_data = {}
    
    def _load_env_overrides(self):
        """Load configuration overrides from environment variables"""
        
        env_mappings = {
            'AFICARE_DB_URL': 'database.url',
            'AFICARE_LLM_MODEL_PATH': 'llm.model_path',
            'AFICARE_API_HOST': 'api.host',
            'AFICARE_API_PORT': 'api.port',
            'AFICARE_SECRET_KEY': 'security.secret_key',
            'AFICARE_LOG_LEVEL': 'app.log_level',
            'AFICARE_DEBUG': 'app.debug'
        }
        
        for env_var, config_key in env_mappings.items():
            env_value = os.getenv(env_var)
            if env_value is not None:
                self._set_nested_value(config_key, env_value)
                logger.debug(f"Config override from {env_var}: {config_key}")
    
    def _set_nested_value(self, key_path: str, value: Any):
        """Set a nested configuration value using dot notation"""
        
        keys = key_path.split('.')
        current = self.config_data
        
        # Navigate to the parent of the target key
        for key in keys[:-1]:
            if key not in current:
                current[key] = {}
            current = current[key]
        
        # Set the final value
        final_key = keys[-1]
        
        # Convert string values to appropriate types
        if isinstance(value, str):
            if value.lower() in ('true', 'false'):
                value = value.lower() == 'true'
            elif value.isdigit():
                value = int(value)
            elif value.replace('.', '').isdigit():
                value = float(value)
        
        current[final_key] = value
    
    def get(self, key_path: str, default: Any = None) -> Any:
        """
        Get configuration value using dot notation
        
        Args:
            key_path: Dot-separated path to the config value (e.g., 'database.url')
            default: Default value if key not found
            
        Returns:
            Configuration value or default
        """
        
        keys = key_path.split('.')
        current = self.config_data
        
        try:
            for key in keys:
                current = current[key]
            return current
        except (KeyError, TypeError):
            return default
    
    def set(self, key_path: str, value: Any):
        """
        Set configuration value using dot notation
        
        Args:
            key_path: Dot-separated path to the config value
            value: Value to set
        """
        
        self._set_nested_value(key_path, value)
    
    def get_section(self, section: str) -> Dict[str, Any]:
        """
        Get entire configuration section
        
        Args:
            section: Section name (e.g., 'database', 'llm')
            
        Returns:
            Dictionary containing section configuration
        """
        
        return self.config_data.get(section, {})
    
    def _create_default_config(self):
        """Create default configuration"""
        
        self.config_data = {
            'app': {
                'name': 'AfiCare Medical Agent',
                'version': '0.1.0',
                'debug': False,
                'log_level': 'INFO'
            },
            'database': {
                'url': 'sqlite:///./aficare.db',
                'echo': False
            },
            'llm': {
                'model_path': './data/models/llama-3.2-3b-instruct.Q4_K_M.gguf',
                'context_length': 4096,
                'temperature': 0.3,
                'max_tokens': 512,
                'n_gpu_layers': 0
            },
            'api': {
                'host': '0.0.0.0',
                'port': 8000
            },
            'ui': {
                'host': 'localhost',
                'port': 8501
            },
            'security': {
                'secret_key': 'change-this-in-production',
                'algorithm': 'HS256'
            }
        }
        
        # Save default config
        try:
            config_dir = Path(self.config_path).parent
            config_dir.mkdir(parents=True, exist_ok=True)
            
            with open(self.config_path, 'w', encoding='utf-8') as f:
                yaml.dump(self.config_data, f, default_flow_style=False)
            
            logger.info(f"Created default configuration at {self.config_path}")
            
        except Exception as e:
            logger.error(f"Failed to create default config: {str(e)}")
    
    def save(self, config_path: Optional[str] = None):
        """
        Save current configuration to file
        
        Args:
            config_path: Optional path to save to (defaults to current config path)
        """
        
        save_path = config_path or self.config_path
        
        try:
            config_dir = Path(save_path).parent
            config_dir.mkdir(parents=True, exist_ok=True)
            
            with open(save_path, 'w', encoding='utf-8') as f:
                yaml.dump(self.config_data, f, default_flow_style=False)
            
            logger.info(f"Configuration saved to {save_path}")
            
        except Exception as e:
            logger.error(f"Failed to save config: {str(e)}")
            raise
    
    def reload(self):
        """Reload configuration from file"""
        
        self._load_config()
        logger.info("Configuration reloaded")
    
    def validate(self) -> bool:
        """
        Validate configuration
        
        Returns:
            True if configuration is valid, False otherwise
        """
        
        required_sections = ['app', 'database', 'llm', 'api']
        
        for section in required_sections:
            if section not in self.config_data:
                logger.error(f"Missing required configuration section: {section}")
                return False
        
        # Validate specific settings
        llm_model_path = self.get('llm.model_path')
        if llm_model_path and not Path(llm_model_path).exists():
            logger.warning(f"LLM model file not found: {llm_model_path}")
        
        return True
    
    def get_database_url(self) -> str:
        """Get database URL with proper formatting"""
        
        db_url = self.get('database.url', 'sqlite:///./aficare.db')
        
        # Ensure SQLite path is absolute for proper handling
        if db_url.startswith('sqlite:///'):
            db_path = db_url[10:]  # Remove 'sqlite:///'
            if not os.path.isabs(db_path):
                db_path = os.path.abspath(db_path)
                db_url = f'sqlite:///{db_path}'
        
        return db_url
    
    def __str__(self) -> str:
        """String representation of configuration"""
        
        return f"Config(path={self.config_path}, sections={list(self.config_data.keys())})"
    
    def __repr__(self) -> str:
        """Detailed string representation"""
        
        return f"Config(path='{self.config_path}', data={self.config_data})"