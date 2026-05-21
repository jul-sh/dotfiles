from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Any

from sqlalchemy import JSON, DateTime, Enum as SqlEnum, Integer, String, Text
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class QueueType(str, Enum):
    LITERATURE_INGESTION = "literature_ingestion"
    HYPOTHESIS_EVALUATION = "hypothesis_evaluation"
    CONTRADICTION_SEARCH = "contradiction_search"
    REPLICATION_PLANNING = "replication_planning"
    EXPERIMENT_DESIGN = "experiment_design"
    CODE_EXECUTION = "code_execution"
    RESULT_GRADING = "result_grading"
    SELF_EDITING = "self_editing"
    SYNTHESIS = "synthesis"
    STALE_REFRESH = "stale_refresh"
    FAILED_RECOVERY = "failed_recovery"


class JobStatus(str, Enum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"


class Job(Base):
    __tablename__ = "jobs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    queue: Mapped[QueueType] = mapped_column(SqlEnum(QueueType), nullable=False)
    status: Mapped[JobStatus] = mapped_column(SqlEnum(JobStatus), default=JobStatus.PENDING)
    priority: Mapped[int] = mapped_column(Integer, default=100)
    payload: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict)
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    max_attempts: Mapped[int] = mapped_column(Integer, default=3)
    error: Mapped[str | None] = mapped_column(Text, default=None)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class Artifact(Base):
    __tablename__ = "artifacts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    artifact_type: Mapped[str] = mapped_column(String(128), nullable=False)
    title: Mapped[str] = mapped_column(String(512), nullable=False)
    content: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict)
    provenance: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict)
    confidence: Mapped[str] = mapped_column(String(32), default="medium")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
