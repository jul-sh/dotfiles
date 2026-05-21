from __future__ import annotations

import json
import time
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Any

from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session
from tenacity import retry, stop_after_attempt, wait_fixed

from research_engine.antigravity_client import AntigravityClient
from research_engine.config import Settings
from research_engine.models import Artifact, Base, Job, JobStatus, QueueType

SYSTEM_PROMPT = """You are a security research orchestrator focused on adversarial robustness, prompt injection, and LLM agent security.
You MUST produce durable research artifacts in strict JSON:
artifact_type, title, content, confidence, next_tasks.
`content` must include explicit assumptions, evidence, counterevidence, and recommendation fields.
"""

SELF_EDIT_STAGES = [
    "evidence_check",
    "citation_check",
    "contradiction_check",
    "methodology_check",
    "threat_model_check",
    "novelty_check",
    "compression_pass",
]


@dataclass
class ResearchEngine:
    settings: Settings

    def __post_init__(self) -> None:
        self.db = create_engine(self.settings.database_url)
        Base.metadata.create_all(self.db)
        self.llm = AntigravityClient(api_key=self.settings.antigravity_api_key)

    def seed_background_work(self) -> None:
        with Session(self.db) as session:
            for queue in QueueType:
                pending_count = session.scalar(
                    select(func.count()).select_from(Job).where(Job.queue == queue, Job.status == JobStatus.PENDING)
                )
                if (pending_count or 0) < 2:
                    session.add(Job(queue=queue, payload={"auto": True, "queue": queue.value, "seeded_at": datetime.utcnow().isoformat()}))
            session.commit()

    def refresh_stale_beliefs(self) -> int:
        created = 0
        cutoff = datetime.utcnow() - timedelta(hours=24)
        with Session(self.db) as session:
            stale = session.scalars(
                select(Artifact).where(Artifact.created_at < cutoff).order_by(Artifact.created_at.asc()).limit(5)
            ).all()
            for artifact in stale:
                session.add(
                    Job(
                        queue=QueueType.STALE_REFRESH,
                        payload={"artifact_id": artifact.id, "reason": "stale_belief_refresh"},
                        priority=40,
                    )
                )
                created += 1
            session.commit()
        return created

    def enqueue_user_input(self, input_type: str, text: str) -> Job:
        route = {
            "hypothesis": QueueType.HYPOTHESIS_EVALUATION,
            "paper": QueueType.LITERATURE_INGESTION,
            "direction": QueueType.SYNTHESIS,
        }
        queue = route.get(input_type, QueueType.SYNTHESIS)
        with Session(self.db) as session:
            job = Job(queue=queue, payload={"input_type": input_type, "text": text, "auto": False}, priority=10)
            session.add(job)
            session.commit()
            session.refresh(job)
            return job

    def _validate_result(self, result: dict[str, Any], job: Job) -> dict[str, Any]:
        content = result.get("content") if isinstance(result.get("content"), dict) else {}
        for key in ["assumptions", "evidence", "counterevidence", "recommendation"]:
            content.setdefault(key, [])
        return {
            "artifact_type": result.get("artifact_type", "research_memo"),
            "title": result.get("title", f"Output for job {job.id}"),
            "content": content,
            "confidence": result.get("confidence", "medium"),
            "next_tasks": result.get("next_tasks", []),
        }

    @retry(stop=stop_after_attempt(3), wait=wait_fixed(2))
    def _run_job_with_retry(self, job: Job) -> dict[str, Any]:
        user_prompt = json.dumps({"job": job.payload, "self_edit_stages": SELF_EDIT_STAGES})
        raw = self.llm.run_structured_task(SYSTEM_PROMPT, user_prompt)
        return self._validate_result(raw, job)

    def process_tick(self) -> int:
        processed = 0
        with Session(self.db) as session:
            jobs = session.scalars(
                select(Job)
                .where(Job.status == JobStatus.PENDING)
                .order_by(Job.priority.asc(), Job.created_at.asc())
                .limit(self.settings.max_jobs_per_tick)
            ).all()

            for job in jobs:
                processed += 1
                job.status = JobStatus.RUNNING
                job.attempts += 1
                session.commit()
                try:
                    result = self._run_job_with_retry(job)
                    session.add(
                        Artifact(
                            artifact_type=result["artifact_type"],
                            title=result["title"],
                            content=result["content"],
                            confidence=result["confidence"],
                            provenance={
                                "job_id": job.id,
                                "queue": job.queue.value,
                                "self_edit_stages": SELF_EDIT_STAGES,
                            },
                        )
                    )
                    job.status = JobStatus.COMPLETED
                    for task in result["next_tasks"]:
                        queue = QueueType(task.get("queue", QueueType.SYNTHESIS.value))
                        session.add(Job(queue=queue, payload=task, priority=int(task.get("priority", 60))))
                except Exception as exc:
                    job.error = str(exc)
                    job.status = JobStatus.FAILED if job.attempts >= job.max_attempts else JobStatus.PENDING
                session.commit()

        self.refresh_stale_beliefs()
        self.seed_background_work()
        return processed

    def run_forever(self) -> None:
        self.seed_background_work()
        while True:
            self.process_tick()
            time.sleep(self.settings.poll_interval_seconds)
