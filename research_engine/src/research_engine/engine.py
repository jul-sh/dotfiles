from __future__ import annotations

import json
import time
from dataclasses import dataclass

from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session
from tenacity import retry, stop_after_attempt, wait_fixed

from research_engine.antigravity_client import AntigravityClient
from research_engine.config import Settings
from research_engine.models import Artifact, Base, Job, JobStatus, QueueType

SYSTEM_PROMPT = """You are a security research orchestrator focused on adversarial robustness, prompt injection, and LLM agent security.
Return strict JSON with keys: artifact_type, title, content, confidence, next_tasks.
"""


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
                exists = session.scalar(select(Job).where(Job.queue == queue, Job.status == JobStatus.PENDING).limit(1))
                if not exists:
                    session.add(Job(queue=queue, payload={"auto": True, "queue": queue.value}))
            session.commit()

    def enqueue_user_input(self, input_type: str, text: str) -> Job:
        queue = QueueType.HYPOTHESIS_EVALUATION if input_type == "hypothesis" else QueueType.SYNTHESIS
        with Session(self.db) as session:
            job = Job(queue=queue, payload={"input_type": input_type, "text": text, "auto": False}, priority=10)
            session.add(job)
            session.commit()
            session.refresh(job)
            return job

    @retry(stop=stop_after_attempt(3), wait=wait_fixed(2))
    def _run_job_with_retry(self, job: Job) -> dict:
        user_prompt = json.dumps(job.payload)
        return self.llm.run_structured_task(SYSTEM_PROMPT, user_prompt)

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
                    artifact = Artifact(
                        artifact_type=result.get("artifact_type", "research_memo"),
                        title=result.get("title", f"Output for job {job.id}"),
                        content=result.get("content", result),
                        confidence=result.get("confidence", "medium"),
                        provenance={"job_id": job.id, "queue": job.queue.value},
                    )
                    session.add(artifact)
                    job.status = JobStatus.COMPLETED
                    for task in result.get("next_tasks", []):
                        session.add(Job(queue=QueueType(task.get("queue", QueueType.SYNTHESIS.value)), payload=task))
                except Exception as exc:
                    job.error = str(exc)
                    job.status = JobStatus.FAILED if job.attempts >= job.max_attempts else JobStatus.PENDING
                session.commit()

        self.seed_background_work()
        return processed

    def run_forever(self) -> None:
        self.seed_background_work()
        while True:
            self.process_tick()
            time.sleep(self.settings.poll_interval_seconds)
