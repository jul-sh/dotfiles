from __future__ import annotations

import json

import typer
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session

from research_engine.config import Settings
from research_engine.engine import ResearchEngine
from research_engine.models import Artifact, Job, JobStatus

app = typer.Typer(help="Always-on autonomous research engine")


@app.command()
def run() -> None:
    settings = Settings.from_env()
    engine = ResearchEngine(settings)
    engine.run_forever()


@app.command()
def enqueue(input_type: str, text: str) -> None:
    settings = Settings.from_env()
    engine = ResearchEngine(settings)
    job = engine.enqueue_user_input(input_type=input_type, text=text)
    typer.echo(f"enqueued job={job.id} queue={job.queue.value}")


@app.command()
def tick() -> None:
    settings = Settings.from_env()
    engine = ResearchEngine(settings)
    processed = engine.process_tick()
    typer.echo(f"processed={processed}")


@app.command()
def status() -> None:
    settings = Settings.from_env()
    db = create_engine(settings.database_url)
    with Session(db) as session:
        pending = session.scalar(select(func.count()).select_from(Job).where(Job.status == JobStatus.PENDING))
        failed = session.scalar(select(func.count()).select_from(Job).where(Job.status == JobStatus.FAILED))
        artifacts = session.scalar(select(func.count()).select_from(Artifact))
    typer.echo(json.dumps({"pending_jobs": pending, "failed_jobs": failed, "artifacts": artifacts}, indent=2))


if __name__ == "__main__":
    app()
