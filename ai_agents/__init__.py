"""
AI Agents for Sprint Execution - Automation Nation

This package contains AI agents designed to autonomously execute sprint tasks
using GitHub integration and intelligent automation.
"""

__version__ = "1.0.0"
__author__ = "AI Sprint Execution System"

from .orchestrator import SprintOrchestrator
from .base_agent import BaseAgent
from .dependency_agent import DependencyAgent
from .security_agent import SecurityAgent
from .performance_agent import PerformanceAgent
from .license_agent import LicenseAgent
from .qa_agent import QualityAssuranceAgent
from .documentation_agent import DocumentationAgent

__all__ = [
    "SprintOrchestrator",
    "BaseAgent",
    "DependencyAgent", 
    "SecurityAgent",
    "PerformanceAgent",
    "LicenseAgent",
    "QualityAssuranceAgent",
    "DocumentationAgent"
]