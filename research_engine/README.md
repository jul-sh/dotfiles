# Always-On Autonomous Research Engine (antigravity SDK)

This service is a 24/7 research orchestrator for adversarial robustness, prompt injection, and LLM agent security.
It continuously turns hypotheses, notes, paper links, and research directions into durable artifacts.

## Guarantees implemented

- Always-on worker loop with durable SQL queue + retries + failed-job recovery.
- Mandatory artifact output for each completed job (claim cards, memos, plans, etc.).
- Queue families for ingestion, hypothesis testing, contradiction search, replication planning, experiment design, synthesis, and stale-belief refresh.
- Self-propagating task graph (`next_tasks`) so completed work generates follow-on work.
- Literature-grounded JSON output contract and concise decision artifacts.

## Install

```bash
cd research_engine
python -m venv .venv
source .venv/bin/activate
pip install -e .
# install antigravity SDK provided by your environment
pip install antigravity
```

## Configure

```bash
export ANTIGRAVITY_API_KEY="AIzaSyC1jhbIxi0CE9giyPQLdLTmwgGpXGBMxXg"
export RESEARCH_ENGINE_DB="sqlite:///research_engine.db"
export RESEARCH_ENGINE_POLL_SECONDS=10
export RESEARCH_ENGINE_MAX_JOBS_PER_TICK=3
```

## Run always-on daemon

```bash
research-engine run
```

## Feed new thoughts

```bash
research-engine enqueue hypothesis "Instruction hierarchy defenses reduce indirect prompt injection success rates in tool-enabled agents."
research-engine enqueue paper "https://arxiv.org/abs/2402.00898"
research-engine enqueue direction "Build a taxonomy of adaptive vs non-adaptive prompt injection defenses"
```

## Operate

```bash
research-engine tick
research-engine status
```

## Deployment notes

- Run under systemd, Docker restart policy, or Kubernetes Deployment with `Always` restart.
- Persist the SQLite file on a durable volume, or switch to Postgres by setting `RESEARCH_ENGINE_DB`.
- Add external executors for replication/benchmark jobs while keeping this orchestrator as control plane.
