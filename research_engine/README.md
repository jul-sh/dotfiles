# Always-On Autonomous Research Engine (antigravity SDK)

24/7 research control-plane for adversarial robustness, prompt injection, and LLM agent security.

## What is improved

- **Truly always-on behavior:** when queues thin out, engine auto-seeds all queue families and refreshes stale beliefs.
- **Artifact-first outputs:** each completed job must write durable artifacts with assumptions/evidence/counterevidence/recommendation.
- **Self-editing contract:** each task is executed with required validation stages (evidence, citations, contradiction, methodology, threat model, novelty, compression).
- **Autonomous follow-on work:** every output can emit `next_tasks`, which are queued automatically.
- **Failure tolerance:** retries, attempt limits, failed-job state, and recovery queue support.

## Install

```bash
cd research_engine
python -m venv .venv
source .venv/bin/activate
pip install -e .
```

## Configure

```bash
export ANTIGRAVITY_API_KEY="AIzaSyC1jhbIxi0CE9giyPQLdLTmwgGpXGBMxXg"
export RESEARCH_ENGINE_DB="sqlite:///research_engine.db"
export RESEARCH_ENGINE_POLL_SECONDS=10
export RESEARCH_ENGINE_MAX_JOBS_PER_TICK=3
```

### Local/offline test mode

```bash
export ANTIGRAVITY_MOCK=1
```

## Run

```bash
research-engine run
```

## Steer the system

```bash
research-engine enqueue hypothesis "Hierarchy-aware tool mediation reduces indirect prompt injection success."
research-engine enqueue paper "https://arxiv.org/abs/2402.00898"
research-engine enqueue direction "Map adaptive vs non-adaptive defenses for LLM agents"
```

## Operate and inspect

```bash
research-engine tick
research-engine status
```
