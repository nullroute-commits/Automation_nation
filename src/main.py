"""
Automation Nation - Python Development Template

This module provides a basic FastAPI application for integrating with
the existing Bash-based system information collection tools.
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import asyncio
import json
import subprocess
import os
from datetime import datetime
from typing import Dict, Any, Optional
import uvicorn

app = FastAPI(
    title="Automation Nation API",
    description="API for system information collection and automation",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "Automation Nation API",
        "timestamp": datetime.utcnow().isoformat(),
        "status": "running"
    }


@app.get("/health")
async def health_check():
    """Enhanced health check endpoint with actual validation"""
    health_status = {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "services": {}
    }
    
    # Database health check
    try:
        # Simple database connectivity test
        import psycopg2
        conn = psycopg2.connect(
            host="postgres",
            database="automation_nation_dev", 
            user="automation_dev",
            password="dev_password"
        )
        conn.close()
        health_status["services"]["database"] = "connected"
    except Exception as e:
        health_status["services"]["database"] = f"error: {str(e)}"
        health_status["status"] = "degraded"
    
    # API service health
    health_status["services"]["api"] = "running"
    
    # Dependency health
    import subprocess
    deps_ok = True
    for dep in ["bc", "jq", "curl"]:
        result = subprocess.run(["which", dep], capture_output=True)
        if result.returncode != 0:
            deps_ok = False
            break
    
    health_status["services"]["dependencies"] = "available" if deps_ok else "missing"
    if not deps_ok:
        health_status["status"] = "degraded"
    
    return health_status


@app.post("/collect/system-info")
async def collect_system_info(
    enable_sudo: bool = False,
    output_file: Optional[str] = None
):
    """
    Trigger system information collection using the existing bash script
    """
    try:
        # Build command
        cmd = ["./collect_info.sh"]
        
        if output_file:
            cmd.extend(["-o", output_file])
            
        # Set environment variables
        env = os.environ.copy()
        env["ENABLE_SUDO_SUPPORT"] = "1" if enable_sudo else "0"
        
        # Execute the bash script
        process = await asyncio.create_subprocess_exec(
            *cmd,
            env=env,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd="/app"
        )
        
        stdout, stderr = await process.communicate()
        
        if process.returncode != 0:
            raise HTTPException(
                status_code=500,
                detail=f"Collection failed: {stderr.decode()}"
            )
        
        # Parse JSON output
        try:
            result = json.loads(stdout.decode())
            return {
                "success": True,
                "data": result,
                "collected_at": datetime.utcnow().isoformat()
            }
        except json.JSONDecodeError:
            return {
                "success": True,
                "raw_output": stdout.decode(),
                "collected_at": datetime.utcnow().isoformat()
            }
            
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Internal error: {str(e)}"
        )


@app.get("/plugins")
async def list_plugins():
    """List available collection plugins"""
    try:
        plugins_dir = "/app/plugins"
        if not os.path.exists(plugins_dir):
            return {"plugins": []}
            
        plugins = []
        for file in os.listdir(plugins_dir):
            if file.endswith(".sh"):
                plugins.append({
                    "name": file,
                    "path": os.path.join(plugins_dir, file)
                })
        
        return {"plugins": plugins}
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to list plugins: {str(e)}"
        )


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )