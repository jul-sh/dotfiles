from __future__ import annotations

from dataclasses import dataclass


@dataclass
class AntigravityClient:
    api_key: str

    def run_structured_task(self, system_prompt: str, user_prompt: str) -> dict:
        """Minimal adapter for antigravity SDK.

        The only SDK-specific dependency is concentrated here so the rest of the engine remains stable.
        """
        try:
            import antigravity  # type: ignore
        except Exception as exc:  # pragma: no cover
            raise RuntimeError(
                "antigravity SDK not installed. Install it and keep this adapter aligned with SDK API."
            ) from exc

        # SDK call lives in one place; adjust to your exact antigravity API surface.
        client = antigravity.Client(api_key=self.api_key)
        response = client.responses.create(
            model="ag-research-1",
            input=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            response_format={"type": "json_object"},
        )

        output = getattr(response, "output", None)
        if isinstance(output, dict):
            return output
        if hasattr(response, "output_text"):
            return {"text": response.output_text}
        return {"raw": str(response)}
