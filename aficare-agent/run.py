#!/usr/bin/env python3
"""
AfiCare Agent - Main Entry Point
Launches the medical AI assistant application
"""

import sys
import os
import asyncio
import argparse
from pathlib import Path

# Add src to Python path
sys.path.insert(0, str(Path(__file__).parent / "src"))

from src.utils.config import Config
from src.utils.logger import setup_logging
from src.core.agent import AfiCareAgent
from src.api.main import create_app
from src.ui.app import launch_ui

import logging

logger = logging.getLogger(__name__)


async def main():
    """Main application entry point"""
    
    parser = argparse.ArgumentParser(description="AfiCare Medical AI Agent")
    parser.add_argument(
        "--mode",
        choices=["api", "ui", "both"],
        default="both",
        help="Run mode: API server, UI only, or both (default: both)"
    )
    parser.add_argument(
        "--config",
        default="config/default.yaml",
        help="Configuration file path"
    )
    parser.add_argument(
        "--host",
        default="localhost",
        help="Host address to bind to"
    )
    parser.add_argument(
        "--api-port",
        type=int,
        default=8000,
        help="API server port"
    )
    parser.add_argument(
        "--ui-port",
        type=int,
        default=8501,
        help="UI server port"
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Enable debug mode"
    )
    
    args = parser.parse_args()
    
    try:
        # Load configuration
        config = Config(args.config)
        
        # Setup logging
        log_level = "DEBUG" if args.debug else config.get("app.log_level", "INFO")
        setup_logging(log_level)
        
        logger.info("Starting AfiCare Medical Agent")
        logger.info(f"Mode: {args.mode}")
        logger.info(f"Config: {args.config}")
        
        # Initialize the agent
        agent = AfiCareAgent(config)
        
        # Check system status
        status = agent.get_system_status()
        logger.info(f"System Status: {status}")
        
        if not status.get("llm_loaded", False):
            logger.warning("LLM not loaded - some features may be limited")
        
        # Launch based on mode
        if args.mode == "api":
            await run_api_server(config, args.host, args.api_port, args.debug)
            
        elif args.mode == "ui":
            await run_ui_server(config, args.host, args.ui_port)
            
        elif args.mode == "both":
            # Run both API and UI servers
            await run_both_servers(
                config, args.host, args.api_port, args.ui_port, args.debug
            )
        
    except KeyboardInterrupt:
        logger.info("Shutting down AfiCare Agent...")
        
    except Exception as e:
        logger.error(f"Fatal error: {str(e)}")
        sys.exit(1)


async def run_api_server(config: Config, host: str, port: int, debug: bool):
    """Run the FastAPI server"""
    
    try:
        import uvicorn
        from src.api.main import create_app
        
        app = create_app(config)
        
        logger.info(f"Starting API server on {host}:{port}")
        
        uvicorn_config = uvicorn.Config(
            app=app,
            host=host,
            port=port,
            reload=debug,
            log_level="debug" if debug else "info"
        )
        
        server = uvicorn.Server(uvicorn_config)
        await server.serve()
        
    except ImportError:
        logger.error("uvicorn not installed. Install with: pip install uvicorn")
        sys.exit(1)
    except Exception as e:
        logger.error(f"API server error: {str(e)}")
        raise


async def run_ui_server(config: Config, host: str, port: int):
    """Run the Streamlit UI server"""
    
    try:
        import subprocess
        import sys
        
        logger.info(f"Starting UI server on {host}:{port}")
        
        # Set environment variables for Streamlit
        env = os.environ.copy()
        env["AFICARE_CONFIG"] = config.config_path
        env["STREAMLIT_SERVER_PORT"] = str(port)
        env["STREAMLIT_SERVER_ADDRESS"] = host
        
        # Launch Streamlit
        cmd = [
            sys.executable, "-m", "streamlit", "run",
            "src/ui/app.py",
            "--server.port", str(port),
            "--server.address", host,
            "--server.headless", "true"
        ]
        
        process = subprocess.Popen(cmd, env=env)
        
        # Wait for the process
        try:
            await asyncio.create_subprocess_exec(*cmd, env=env)
        except KeyboardInterrupt:
            process.terminate()
            process.wait()
        
    except ImportError:
        logger.error("streamlit not installed. Install with: pip install streamlit")
        sys.exit(1)
    except Exception as e:
        logger.error(f"UI server error: {str(e)}")
        raise


async def run_both_servers(
    config: Config, host: str, api_port: int, ui_port: int, debug: bool
):
    """Run both API and UI servers concurrently"""
    
    logger.info("Starting both API and UI servers...")
    
    # Create tasks for both servers
    api_task = asyncio.create_task(
        run_api_server(config, host, api_port, debug)
    )
    
    ui_task = asyncio.create_task(
        run_ui_server(config, host, ui_port)
    )
    
    try:
        # Wait for both tasks
        await asyncio.gather(api_task, ui_task)
    except KeyboardInterrupt:
        logger.info("Shutting down servers...")
        api_task.cancel()
        ui_task.cancel()
        
        # Wait for tasks to complete cancellation
        await asyncio.gather(api_task, ui_task, return_exceptions=True)


def check_dependencies():
    """Check if required dependencies are installed"""
    
    required_packages = [
        "fastapi",
        "uvicorn", 
        "streamlit",
        "pydantic",
        "sqlalchemy",
        "pyyaml"
    ]
    
    missing_packages = []
    
    for package in required_packages:
        try:
            __import__(package)
        except ImportError:
            missing_packages.append(package)
    
    if missing_packages:
        logger.error(f"Missing required packages: {', '.join(missing_packages)}")
        logger.error("Install with: pip install -r requirements.txt")
        return False
    
    return True


def setup_directories():
    """Create necessary directories if they don't exist"""
    
    directories = [
        "data/models",
        "data/knowledge_base",
        "backups",
        "logs"
    ]
    
    for directory in directories:
        Path(directory).mkdir(parents=True, exist_ok=True)


if __name__ == "__main__":
    # Check dependencies
    if not check_dependencies():
        sys.exit(1)
    
    # Setup directories
    setup_directories()
    
    # Run the application
    asyncio.run(main())