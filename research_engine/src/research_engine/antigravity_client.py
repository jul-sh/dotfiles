from __future__ import annotations

import json
import os
from dataclasses import dataclass
from typing import Any


@dataclass
class AntigravityClient:
    api_key: str

    def _mock_response(self, user_prompt: str) -> dict[str, Any]:
        payload = json.loads(user_prompt)
        job = payload.get("job", {})
        text = job.get("text", "autonomous background research")
        return {
            "artifact_type": "hypothesis_verdict",
            "title": f"Research output: {str(text)[:80]}",
            "content": {
                "assumptions": ["Threat model explicitly scoped to tool-enabled LLM agents."],
                "evidence": ["Seed artifact generated to keep autonomous queue active."],
                "counterevidence": ["No external literature fetch configured in local mock mode."],
                "recommendation": "Schedule literature ingestion and contradiction search next.",
            },
            "confidence": "low",
            "next_tasks": [
                {"queue": "literature_ingestion", "topic": text, "priority": 50},
                {"queue": "contradiction_search", "topic": text, "priority": 55},
            ],
        }

    def run_structured_task(self, system_prompt: str, user_prompt: str) -> dict[str, Any]:
        """Adapter for antigravity SDK.

        Set ANTIGRAVITY_MOCK=1 for deterministic offline testing.
        """
        if os.getenv("ANTIGRAVITY_MOCK", "0") == "1":
            return self._mock_response(user_prompt)

        try:
            from antigravity_sdk import Client  # type: ignore
        except Exception as exc:  # pragma: no cover
            raise RuntimeError(
                "antigravity_sdk is unavailable. Install the correct antigravity SDK or set ANTIGRAVITY_MOCK=1 for local tests."
            ) from exc

        client = Client(api_key=self.api_key)
        response = client.responses.create(
            model="ag-research-1",
            input=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            response_format={"type": "json_object"},
        )
        output = getattr(response, "output", None)
        return output if isinstance(output, dict) else {"artifact_type": "raw", "content": {"raw": str(response)}}
