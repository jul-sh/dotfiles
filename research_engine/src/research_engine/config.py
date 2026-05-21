from __future__ import annotations

from pydantic import BaseModel, Field
import os


class Settings(BaseModel):
    database_url: str = Field(default="sqlite:///research_engine.db")
    antigravity_api_key: str = Field(default="")
    poll_interval_seconds: int = Field(default=10)
    max_jobs_per_tick: int = Field(default=3)

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            database_url=os.getenv("RESEARCH_ENGINE_DB", "sqlite:///research_engine.db"),
            antigravity_api_key=os.getenv("ANTIGRAVITY_API_KEY", os.getenv("GOOGLE_API_KEY", "")),
            poll_interval_seconds=int(os.getenv("RESEARCH_ENGINE_POLL_SECONDS", "10")),
            max_jobs_per_tick=int(os.getenv("RESEARCH_ENGINE_MAX_JOBS_PER_TICK", "3")),
        )
