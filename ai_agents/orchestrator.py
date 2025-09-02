#!/usr/bin/env python3
"""
AI Sprint Orchestrator

Central coordination system for managing AI agents during sprint execution.
Analyzes sprint plan, assigns tasks to agents, and coordinates execution.
"""

import json
import argparse
import sys
from typing import Dict, List, Any
from datetime import datetime
from pathlib import Path

from base_agent import BaseAgent
from dependency_agent import DependencyAgent
from security_agent import SecurityAgent
from performance_agent import PerformanceAgent
from license_agent import LicenseAgent
from qa_agent import QualityAssuranceAgent
from documentation_agent import DocumentationAgent


class SprintOrchestrator(BaseAgent):
    """Orchestrates AI agents for sprint execution"""
    
    def __init__(self, github_token: str, repository: str, sprint_phase: str = "week1", mode: str = "parallel"):
        super().__init__("orchestrator", github_token, repository)
        self.sprint_phase = sprint_phase
        self.execution_mode = mode
        self.agents = {}
        self.sprint_plan = self._load_sprint_plan()
        
    def _load_sprint_plan(self) -> Dict[str, Any]:
        """Load and parse the sprint plan"""
        try:
            sprint_content = self.read_file("SPRINT_PLAN.md")
            if not sprint_content:
                raise Exception("Sprint plan not found")
                
            # Parse sprint plan structure (simplified parsing for demo)
            plan = {
                "week1_tasks": self._extract_week_tasks(sprint_content, "Week 1"),
                "week2_tasks": self._extract_week_tasks(sprint_content, "Week 2"), 
                "week3_tasks": self._extract_week_tasks(sprint_content, "Week 3"),
                "success_criteria": self._extract_success_criteria(sprint_content),
                "performance_targets": self._extract_performance_targets(sprint_content)
            }
            
            self.log_progress("load_sprint_plan", "✅ Success", f"Loaded {len(plan)} plan sections")
            return plan
            
        except Exception as e:
            self.log_error("load_sprint_plan", str(e))
            return {}
    
    def _extract_week_tasks(self, content: str, week: str) -> List[Dict[str, Any]]:
        """Extract tasks for a specific week from sprint plan"""
        tasks = []
        lines = content.split('\n')
        in_week_section = False
        
        for line in lines:
            if f"## {week}:" in line:
                in_week_section = True
                continue
            elif line.startswith("## ") and in_week_section:
                break
            elif in_week_section and "- [ ]" in line:
                task_name = line.split("**Task")[1].split("**:")[0].strip() if "**Task" in line else line.strip()
                tasks.append({
                    "name": task_name,
                    "description": line.strip(),
                    "completed": False
                })
                
        return tasks
    
    def _extract_success_criteria(self, content: str) -> Dict[str, List[str]]:
        """Extract success criteria from sprint plan"""
        criteria = {"must_have": [], "should_have": [], "could_have": []}
        lines = content.split('\n')
        current_section = None
        
        for line in lines:
            if "Must-Have" in line:
                current_section = "must_have"
            elif "Should-Have" in line:
                current_section = "should_have"
            elif "Could-Have" in line:
                current_section = "could_have"
            elif current_section and "- [ ]" in line:
                criteria[current_section].append(line.strip())
                
        return criteria
    
    def _extract_performance_targets(self, content: str) -> Dict[str, str]:
        """Extract performance targets from sprint plan"""
        targets = {}
        lines = content.split('\n')
        
        for line in lines:
            if "Collection Time" in line and "Target" in line:
                targets["collection_time"] = "<3s"
            elif "API Response Time" in line and "Target" in line:
                targets["api_response"] = "<200ms"
            elif "Test Coverage" in line and "Target" in line:
                targets["test_coverage"] = "95%+"
                
        return targets
    
    def initialize_agents(self) -> Dict[str, BaseAgent]:
        """Initialize all AI agents for sprint execution"""
        self.log_progress("initialize_agents", "🚀 Starting", "Creating AI agent team")
        
        agents = {
            "dependency-agent": DependencyAgent(self.github_token, self.repository),
            "security-agent": SecurityAgent(self.github_token, self.repository),
            "performance-agent": PerformanceAgent(self.github_token, self.repository),
            "license-agent": LicenseAgent(self.github_token, self.repository),
            "qa-agent": QualityAssuranceAgent(self.github_token, self.repository),
            "docs-agent": DocumentationAgent(self.github_token, self.repository)
        }
        
        self.log_progress("initialize_agents", "✅ Complete", f"Initialized {len(agents)} agents")
        return agents
    
    def create_execution_plan(self) -> Dict[str, Any]:
        """Create execution plan based on sprint phase and mode"""
        plan = {
            "sprint_phase": self.sprint_phase,
            "execution_mode": self.execution_mode,
            "timestamp": datetime.utcnow().isoformat(),
            "agent_assignments": [],
            "task_dependencies": {},
            "success_criteria": self.sprint_plan.get("success_criteria", {})
        }
        
        # Determine which agents to activate based on sprint phase
        if self.sprint_phase == "week1" or self.sprint_phase == "full-sprint":
            plan["agent_assignments"].extend([
                "dependency-agent",
                "license-agent", 
                "security-agent"
            ])
            
        if self.sprint_phase == "week2" or self.sprint_phase == "full-sprint":
            plan["agent_assignments"].extend([
                "performance-agent"
            ])
            
        if self.sprint_phase == "week3" or self.sprint_phase == "full-sprint":
            plan["agent_assignments"].extend([
                "qa-agent",
                "docs-agent"
            ])
        
        # Define task dependencies
        plan["task_dependencies"] = {
            "performance-agent": ["dependency-agent"],  # Performance needs dependencies fixed
            "qa-agent": ["security-agent", "performance-agent"],  # QA needs other components ready
            "docs-agent": ["qa-agent"]  # Docs come after testing is complete
        }
        
        self.log_progress("create_execution_plan", "✅ Complete", f"Plan for {len(plan['agent_assignments'])} agents")
        return plan
    
    def validate_prerequisites(self) -> bool:
        """Validate that all prerequisites for sprint execution are met"""
        self.log_progress("validate_prerequisites", "🔍 Checking", "Validating sprint prerequisites")
        
        requirements = self.validate_sprint_requirements()
        missing_requirements = [req for req, status in requirements.items() if not status]
        
        if missing_requirements:
            self.log_error("validate_prerequisites", f"Missing: {missing_requirements}")
            return False
            
        # Check GitHub connectivity
        try:
            url = f"https://api.github.com/repos/{self.repository}"
            response = requests.get(url, headers=self.github_headers)
            response.raise_for_status()
            self.log_progress("validate_prerequisites", "✅ GitHub", "API connectivity verified")
        except Exception as e:
            self.log_error("validate_prerequisites", f"GitHub API error: {e}")
            return False
            
        self.log_progress("validate_prerequisites", "✅ Complete", "All prerequisites met")
        return True
    
    def create_sprint_tracking_issue(self, execution_plan: Dict[str, Any]) -> Optional[int]:
        """Create GitHub issue for tracking sprint progress"""
        title = f"🚀 AI Sprint Execution - {self.sprint_phase.title()} Phase"
        
        body = f"""## AI Sprint Execution Tracking

**Phase**: {self.sprint_phase}
**Mode**: {self.execution_mode}
**Started**: {datetime.utcnow().isoformat()}

### Assigned AI Agents:
{chr(10).join([f"- **{agent.replace('-', ' ').title()}**" for agent in execution_plan['agent_assignments']])}

### Sprint Goals:
{chr(10).join([f"- {criteria}" for criteria in execution_plan['success_criteria'].get('must_have', [])])}

### Progress Tracking:
- [ ] Prerequisites validated
- [ ] Agents initialized
- [ ] Tasks assigned
- [ ] Execution started
- [ ] Progress monitoring active
- [ ] Results validated
- [ ] Sprint completed

### Agent Status:
{chr(10).join([f"- [ ] {agent.replace('-', ' ').title()}: Not started" for agent in execution_plan['agent_assignments']])}

---
*This issue is automatically managed by the AI Sprint Orchestrator*
"""
        
        issue = self.create_github_issue(
            title=title,
            body=body,
            labels=["ai-sprint", "automation", "tracking", f"phase-{self.sprint_phase}"]
        )
        
        if issue:
            self.log_progress("create_tracking_issue", "✅ Created", f"Issue #{issue.get('number')}")
            return issue.get('number')
        else:
            self.log_error("create_tracking_issue", "Failed to create tracking issue")
            return None
    
    def execute_tasks(self) -> Dict[str, Any]:
        """Execute the orchestration tasks"""
        self.log_progress("execute_tasks", "🚀 Starting", "AI Sprint Orchestration")
        
        # Validate prerequisites
        if not self.validate_prerequisites():
            return {"success": False, "error": "Prerequisites validation failed"}
        
        # Create execution plan
        execution_plan = self.create_execution_plan()
        
        # Create tracking issue
        tracking_issue = self.create_sprint_tracking_issue(execution_plan)
        execution_plan["tracking_issue"] = tracking_issue
        
        # Output execution plan for GitHub Actions
        if os.getenv('GITHUB_ACTIONS'):
            print(f"::set-output name=plan::{json.dumps(execution_plan)}")
            print(f"::set-output name=assignments::{json.dumps(execution_plan['agent_assignments'])}")
        
        self.log_progress("execute_tasks", "✅ Complete", f"Orchestration plan created with {len(execution_plan['agent_assignments'])} agents")
        
        return {
            "success": True,
            "execution_plan": execution_plan,
            "agents_count": len(execution_plan['agent_assignments']),
            "tracking_issue": tracking_issue
        }
    
    def get_success_metrics(self) -> Dict[str, Any]:
        """Return orchestration success metrics"""
        return {
            "agents_initialized": len(self.agents),
            "sprint_phase": self.sprint_phase,
            "execution_mode": self.execution_mode,
            "prerequisites_valid": True,
            "github_integration": True
        }


def main():
    """Main entry point for the orchestrator"""
    parser = argparse.ArgumentParser(description="AI Sprint Orchestrator")
    parser.add_argument("--sprint-phase", default="week1", choices=["week1", "week2", "week3", "full-sprint"])
    parser.add_argument("--mode", default="parallel", choices=["parallel", "sequential", "interactive"])
    parser.add_argument("--github-token", required=True, help="GitHub API token")
    parser.add_argument("--repository", required=True, help="GitHub repository (owner/repo)")
    
    args = parser.parse_args()
    
    try:
        orchestrator = SprintOrchestrator(
            github_token=args.github_token,
            repository=args.repository,
            sprint_phase=args.sprint_phase,
            mode=args.mode
        )
        
        result = orchestrator.execute_tasks()
        
        if result["success"]:
            print(f"🚀 AI Sprint Orchestration successful!")
            print(f"📊 Agents assigned: {result['agents_count']}")
            print(f"📋 Tracking issue: #{result['tracking_issue']}")
            sys.exit(0)
        else:
            print(f"❌ AI Sprint Orchestration failed: {result.get('error')}")
            sys.exit(1)
            
    except Exception as e:
        print(f"💥 Critical error in orchestrator: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()