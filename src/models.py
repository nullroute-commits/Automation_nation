"""
Database models for Automation Nation
"""

from sqlalchemy import create_engine, Column, Integer, String, DateTime, Boolean, Text, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
from sqlalchemy.dialects.postgresql import JSONB
from datetime import datetime
import os

# Database configuration
DATABASE_URL = os.getenv(
    "DATABASE_URL", 
    "postgresql://automation_dev:dev_password@postgres:5432/automation_nation_dev"
)

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


class SystemInfo(Base):
    """System information collection results"""
    __tablename__ = "system_info"
    
    id = Column(Integer, primary_key=True, index=True)
    collected_at = Column(DateTime, default=datetime.utcnow, index=True)
    hostname = Column(String(255), index=True)
    architecture = Column(String(50), index=True)
    os_name = Column(String(255))
    os_version = Column(String(255))
    kernel_version = Column(String(255))
    data = Column(JSONB)
    checksum = Column(String(64))


class CollectionRun(Base):
    """Collection run metadata"""
    __tablename__ = "collection_runs"
    
    id = Column(Integer, primary_key=True, index=True)
    started_at = Column(DateTime, default=datetime.utcnow, index=True)
    completed_at = Column(DateTime, nullable=True)
    status = Column(String(20), default="running")
    plugin_count = Column(Integer)
    duration_ms = Column(Integer)
    error_message = Column(Text)
    
    # Relationship
    plugin_results = relationship("PluginResult", back_populates="collection_run")


class PluginResult(Base):
    """Individual plugin execution results"""
    __tablename__ = "plugin_results"
    
    id = Column(Integer, primary_key=True, index=True)
    collection_run_id = Column(Integer, ForeignKey("collection_runs.id"), index=True)
    plugin_name = Column(String(100), index=True)
    executed_at = Column(DateTime, default=datetime.utcnow)
    success = Column(Boolean, default=True)
    execution_time_ms = Column(Integer)
    data = Column(JSONB)
    error_message = Column(Text)
    
    # Relationship
    collection_run = relationship("CollectionRun", back_populates="plugin_results")


def get_db():
    """Database dependency"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def create_tables():
    """Create all tables"""
    Base.metadata.create_all(bind=engine)