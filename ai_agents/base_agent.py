"""
Base AI Agent Class for Sprint Execution

Provides common functionality for all AI agents including GitHub integration,
logging, task tracking, and communication protocols.
"""

import os
import json
import logging
import asyncio
from abc import ABC, abstractmethod
from typing import Dict, List, Any, Optional
from datetime import datetime
import subprocess
import requests
from pathlib import Path


class BaseAgent(ABC):
    """Base class for all AI sprint execution agents"""
    
    def __init__(self, name: str, github_token: str, repository: str):
        self.name = name
        self.github_token = github_token
        self.repository = repository
        self.workspace_path = Path("/workspace")
        self.logger = self._setup_logging()
        self.github_headers = {
            "Authorization": f"token {github_token}",
            "Accept": "application/vnd.github.v3+json"
        }
        
    def _setup_logging(self) -> logging.Logger:
        """Setup logging for the agent"""
        logger = logging.getLogger(f"ai_agent.{self.name}")
        logger.setLevel(logging.INFO)
        
        if not logger.handlers:
            handler = logging.StreamHandler()
            formatter = logging.Formatter(
                f'%(asctime)s - {self.name} - %(levelname)s - %(message)s'
            )
            handler.setFormatter(formatter)
            logger.addHandler(handler)
            
        return logger
    
    def log_progress(self, task: str, status: str, details: str = ""):
        """Log agent progress for tracking"""
        self.logger.info(f"Task: {task} | Status: {status} | Details: {details}")
        
        # Also log to GitHub Actions
        if os.getenv('GITHUB_ACTIONS'):
            print(f"::notice title={self.name}::{task} - {status}: {details}")
    
    def log_error(self, task: str, error: str):
        """Log agent errors"""
        self.logger.error(f"Task: {task} | Error: {error}")
        
        if os.getenv('GITHUB_ACTIONS'):
            print(f"::error title={self.name}::{task} failed: {error}")
    
    def run_command(self, command: str, cwd: Optional[str] = None) -> Dict[str, Any]:
        """Execute shell command and return result"""
        try:
            result = subprocess.run(
                command,
                shell=True,
                capture_output=True,
                text=True,
                cwd=cwd or self.workspace_path,
                timeout=300  # 5 minute timeout
            )
            
            return {
                "success": result.returncode == 0,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "returncode": result.returncode
            }
        except subprocess.TimeoutExpired:
            return {
                "success": False,
                "stdout": "",
                "stderr": "Command timed out after 5 minutes",
                "returncode": -1
            }
        except Exception as e:
            return {
                "success": False,
                "stdout": "",
                "stderr": str(e),
                "returncode": -1
            }
    
    def create_github_issue(self, title: str, body: str, labels: List[str] = None) -> Dict[str, Any]:
        """Create a GitHub issue for tracking"""
        url = f"https://api.github.com/repos/{self.repository}/issues"
        data = {
            "title": title,
            "body": body,
            "labels": labels or []
        }
        
        try:
            response = requests.post(url, headers=self.github_headers, json=data)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            self.log_error("create_github_issue", str(e))
            return {}
    
    def update_github_issue(self, issue_number: int, title: str = None, body: str = None, state: str = None) -> Dict[str, Any]:
        """Update an existing GitHub issue"""
        url = f"https://api.github.com/repos/{self.repository}/issues/{issue_number}"
        data = {}
        
        if title:
            data["title"] = title
        if body:
            data["body"] = body
        if state:
            data["state"] = state
            
        try:
            response = requests.patch(url, headers=self.github_headers, json=data)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            self.log_error("update_github_issue", str(e))
            return {}
    
    def read_file(self, file_path: str) -> str:
        """Read file contents safely"""
        try:
            with open(self.workspace_path / file_path, 'r') as f:
                return f.read()
        except Exception as e:
            self.log_error("read_file", f"Failed to read {file_path}: {e}")
            return ""
    
    def write_file(self, file_path: str, content: str) -> bool:
        """Write file contents safely"""
        try:
            file_full_path = self.workspace_path / file_path
            file_full_path.parent.mkdir(parents=True, exist_ok=True)
            
            with open(file_full_path, 'w') as f:
                f.write(content)
            return True
        except Exception as e:
            self.log_error("write_file", f"Failed to write {file_path}: {e}")
            return False
    
    def validate_sprint_requirements(self) -> Dict[str, bool]:
        """Validate that sprint requirements are met"""
        requirements = {
            "sprint_plan_exists": (self.workspace_path / "SPRINT_PLAN.md").exists(),
            "src_directory_exists": (self.workspace_path / "src").exists(),
            "plugins_directory_exists": (self.workspace_path / "plugins").exists(),
            "test_directory_exists": (self.workspace_path / "test").exists(),
            "requirements_file_exists": (self.workspace_path / "requirements.txt").exists()
        }
        
        for req, status in requirements.items():
            self.log_progress("validate_requirements", f"{req}: {'✅' if status else '❌'}")
            
        return requirements
    
    @abstractmethod
    def execute_tasks(self) -> Dict[str, Any]:
        """Execute the agent's assigned sprint tasks"""
        pass
    
    @abstractmethod
    def get_success_metrics(self) -> Dict[str, Any]:
        """Return metrics indicating task completion success"""
        pass