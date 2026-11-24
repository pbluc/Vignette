# Vignette: Instructions for the Coding Agent

Vignette is an AI interior decorator for mixed reality. The user scans a real room and asks for a change in plain language ("make this feel cozier"). An LLM agent then proposes a design and places virtual furniture and decor on real surfaces. It explains its choices, and the user can swap or remove items by voice.

This is a portfolio project. The code, the commit history and the eval results are all part of what gets shown, so keep them clean and easy to read.

**Read `SPEC.md` before starting any task.** It is the source of truth for scope, architecture and milestones. If a request conflicts with the spec, say so instead of quietly changing the design.

## Repo layout

> Proposed layout. Update this section if the structure changes.

```
README.md          Public front page: demo video, architecture diagram, eval results, "How I built this"
SPEC.md            Project spec (source of truth)
CLAUDE.md          This file
unity/             Unity client: perception, rendering, voice, anchoring
backend/           Python agent service
  agent/           Agent loop, prompts, tool definitions
  tools/           Tool implementations (search, place, swap, remove, state)
  constraints/     Spatial validation (collision, walkways, surface rules)
  catalog/         Item metadata, embeddings, vector index
  observability/   Structured logging and traces
eval/              Evaluation harness, saved room models, request set, results, top-down 2D viewer
infra/             Terraform for AWS (ECS Express Mode, S3, IAM, Secrets Manager)
docs/              Architecture diagram, write-up, notes on agent corrections
scripts/           Repo utilities (e.g. GitHub milestone and issue setup)
```

## Architecture in brief

1. **Unity client** reads the room's scene data and turns it into a compact **JSON room model**: bounds, labeled surfaces, existing furniture as bounding boxes, and walkway zones. It never sends raw meshes.
2. **Agent service** (Python) takes the room model, the user's request and the current design state. It runs an LLM tool-calling loop and returns validated actions plus a short explanation.
3. **Tools** are the agent's only way to change the scene:
   - `search_catalog(query, filters)`
   - `place_item(item_id, surface_id, position, rotation)`
   - `swap_item(placed_id, item_id)`
   - `remove_item(placed_id)`
   - `get_design_state()`
4. **Constraint validation** runs on every placement. When a placement fails, it returns a *specific* violation (for example `collision_with: sofa_01` or `blocks_walkway: door_2`) so the agent can retry.

## Hard rules

- **The model never writes scene state directly.** Every change goes through a tool and passes validation.
- **Never change the room model schema or tool signatures without asking.** The Unity client, the backend and the saved eval rooms all depend on them. If a change is needed, propose it first along with every file it affects.
- **Do not weaken constraint checks to make a test or an eval pass.** If a check seems wrong, flag it.
- **Cap agent steps per request** and always handle timeouts. Never write an unbounded loop around a model call.
- **Never commit API keys.** Load them from environment variables. `.env` stays gitignored, and `.env.example` documents the variables.
- **Protect client data.** Vignette will be used with real decorating clients, and a room scan is a map of their home. Store all saved data per client ID, never log names, addresses or other identifying details, and never put real client rooms in the repo or the eval set.
- **The hosted endpoint is public, so never remove or weaken its safeguards**: a required access key on every request, rate limits, caps on request size and agent steps, and HTTPS only. Never ship a client build with the Anthropic API key in it; only the backend holds that key.
- **Catalog assets must have permissive licenses.** Record the source and license for each item in its metadata.

## Who owns what

**Good tasks for the agent:**
- Backend service scaffolding, routing and config
- Tool schemas and their plumbing
- Unit tests
- The evaluation harness and results reporting
- Logging, traces and fallbacks
- Catalog ingestion and embedding scripts

**Patricia owns these (propose changes, don't rewrite them unasked):**
- Spatial math (transforms, coordinate frames, anchoring)
- How scene data is read and converted to the room model
- Constraint logic in `backend/constraints/`
- Anything that has to be verified on a device

When working near these areas, explain what you plan to do and wait for a go-ahead.

## Development environment

- The only headset on hand is a **Meta Quest 1**, which has no color passthrough or full Scene support. Development is **simulator-first**: build against saved room models and the Unity editor or XR simulator. The **target platform is Meta Quest 3** (Unity + Meta XR SDK scene data); see `SPEC.md` → Target platform. A Quest 3 is needed by about week 4. Until then, nothing should require a device, and Quest-specific code stays in `unity/` so a later port (e.g. Vision Pro) only touches the client.
- Keep the backend and the eval suite fully runnable **without a headset**.
- **Main agent model: Claude Sonnet 5.5.** Keep it behind a thin provider interface so the eval suite can run other models (budget, mid-tier and top-tier, from any provider) by changing config. Never hard-code a model ID outside config.
- **Embedding model: Qwen3-Embedding, run locally** (open weights, Apache 2.0). Catalog search must work offline with no API key. If the embedding model changes, rebuild the vector index; never mix embeddings from different models in one index.
- **Deployment:** the backend runs locally during development and is **hosted on AWS** for the demo and client sessions (ECS Express Mode on Fargate, S3, Secrets Manager; see `SPEC.md` → Deployment). Keep it containerized and configured only through environment variables, so local and hosted builds are identical. Infrastructure is defined in **Terraform** under `infra/`, with remote state in S3 with locking. Never commit state files or `.tfvars` files that contain secrets, and change infrastructure only through Terraform, not the AWS console. The Unity client reads the backend URL from a setting; never hard-code it.
- **Stay cloud-portable:** only the storage adapter talks to S3, and only the auth module checks access keys. No other code imports AWS SDKs directly.
- **Catalog:** give every item a stable ID (never a list position), and make catalog loading tolerate missing optional fields so new fields can be added later.
- **Future phases** in `SPEC.md` (client tool, product scanning, public app) are out of scope unless Patricia asks. Don't build ahead for them beyond the design choices listed here.

## Commands

> Fill these in once the project has been scaffolded.

```
# Backend
cd backend && <install command>
<run service>
<run unit tests>

# Eval
<run eval suite>   # writes results to eval/results/
```

## Testing and evaluation

- Add or update unit tests with every backend change, and run them before calling a task done.
- Any change to prompts, the model or tool behavior must come with an **eval run**. Commit the results to `eval/results/` along with a one-line summary of what changed.
- Eval metrics: valid placement rate, constraint violations per request, request success rate (scored against a rubric), agent steps per request, latency, and cost per request.
- Never edit saved room models or the request set to raise a score.

## Observability

Log every agent step as structured data: prompt version, model, tool calls with their arguments, validation results, latency and token cost. Version prompts so each log line and eval result can be traced back to the exact prompt that produced it.

## Code style

- Python: type hints everywhere, small pure functions in `constraints/`, and Pydantic (or dataclasses) for the room model and tool I/O.
- C# (Unity): keep perception and serialization apart from rendering and interaction.
- Write comments that explain *why*, especially for spatial math and constraint rules.

## Commits and the "How I built this" record

- Keep commits small, one logical change each, with messages in the imperative mood.
- The README is a public front page linked from job applications. Keep its status section accurate, and never claim a feature works before it does.
- **When the agent's output needed correcting**, note it in the commit message (for example `Fix: agent-generated walkway check ignored door swing`) and add a line to `docs/agent-corrections.md` saying what went wrong and how it was caught. This record feeds the README's "How I built this" section.
- AI-assisted code review runs in CI alongside the tests.

## Task tracking

Work is tracked in GitHub Issues, grouped into one GitHub milestone per milestone in `SPEC.md`.

- Work from an issue when one exists, and reference it in commits and pull requests (`Fixes #12`).
- `agent-task` issues can be handed to you. `patricia-owned` issues are hers: propose changes, don't implement them unasked.
- When a new idea or scope question comes up mid-milestone, suggest a `parking-lot` issue instead of expanding the current work.

## Current milestone

> Update this section as the project moves forward.

**Weeks 1–2: room model (due Sunday, December 13, 2026).** Define the JSON room model, build it from simulated scene data in the editor (switch to real Quest 3 scene data once the device arrives), and place one hard-coded item on a labeled surface.
