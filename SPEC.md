# Vignette: An AI Interior Decorator for Mixed Reality

**Author:** Patricia Luc · **Status:** Draft · **Last updated:** November 24, 2026

## Overview

Vignette is an AI interior decorator for mixed reality. The user scans their real room, then asks in plain language for a change, such as "make this feel cozier" or "try a mid-century look." An LLM agent proposes a design and places virtual furniture and decor anchored to real surfaces, explains its choices, and lets the user swap or remove items by voice.

The project is meant to show two things: AI built into a real product pipeline (perception, tool-calling agent, retrieval, constraint validation, evaluation, observability), and an agentic coding workflow used to build it.

Beyond the portfolio, Vignette is meant to become a working tool for Patricia's interior decorating business, used with clients during in-person sessions on her headset. The first version stays focused on the portfolio milestones, but it is designed so that client use, product scanning, and eventually a public app can be added without rewrites (see Future phases).

## Goals

- Turn a scanned room into structured data an LLM can reason about.
- Let an agent propose and place items through validated tools, never by writing scene state directly.
- Find items with semantic search over a furniture and decor catalog.
- Reject or repair placements that collide, block walkways, or float off surfaces.
- Measure quality with a repeatable evaluation suite and log every agent step.
- Ship a polished 30–60 second demo video and a public repo with a strong README.

## Non-goals (first version)

These are out of scope for the 7-week plan. Some return in Future phases.

- Photorealistic rendering or a commercial-grade furniture catalog.
- Multi-user or shared sessions, and user accounts.
- Purchasing, linking to, or scanning real products.
- Supporting every headset; one platform done well beats several done roughly.

## Target platform

Meta Quest 3 with Unity and Meta's XR SDK, using its scene understanding for the room mesh, planes, and labeled surfaces (floor, walls, tables, couches). This builds directly on existing Unity and Quest experience. Apple Vision Pro with ARKit and RealityKit is a possible later port.

**Decision (November 24, 2026): Quest 3 is the primary platform**, chosen over Vision Pro because:

- Development works in Unity on Windows. visionOS would need a Mac and Xcode.
- It costs a fraction of a Vision Pro.
- Unity, C#, and Quest scene skills carry over to most target XR roles, and Quest has by far the largest MR install base.

Development is simulator-first: the backend and evaluation suite run against saved room models, and the Unity client is built in the editor and XR simulator. A Quest 3 (new, refurbished, or borrowed) is needed by about week 4 for on-device scene data and the demo. The room model keeps the backend independent of the device, so a later port only touches the Unity client.

## User flow

1. Put on the headset; the app loads the room's scene data.
2. Ask by voice: "Make this corner a reading nook."
3. The agent plans a design and places items; each appears anchored in the room.
4. The app shows a short explanation of the choices.
5. The user refines: "Swap the lamp for something warmer," "Remove the rug," "Undo."
6. The user can save and reload a design for the same room.

## Architecture

The system has a Unity client on the headset and a small backend service that runs the agent.

```
┌─────────────────────────── Quest 3 (Unity client) ───────────────────────────┐
│  Scene data ──► Room model (JSON) ──┐                 ┌──► Render & anchor   │
│  Voice input ──► Request text ──────┤                 │    placed items      │
└─────────────────────────────────────┼─────────────────┼──────────────────────┘
                                      ▼                 │
┌──────────────────────────── Agent service (Python) ──┴───────────────────────┐
│  LLM agent loop ──► Tools ──► Constraint validation ──► Validated actions     │
│                      │                                     + explanation      │
│                      └──► Catalog semantic search (vector index)              │
│  Logging & traces for every step                                              │
└───────────────────────────────────────────────────────────────────────────────┘
```

### 1. Perception (Unity client)

- Read the room's scene data and convert it to a compact JSON room model: room bounds, labeled surfaces with position, size, and orientation, existing furniture as bounding boxes, and walkway zones.
- Keep the room model small and stable so the agent reasons over structure, not raw meshes.

### 2. Agent service (backend, Python)

- Receives the room model, the user request, and the current design state.
- Runs an LLM agent loop with a fixed set of tools (below). The model decides what to do; the service validates and applies each action.
- **Model (decided November 24, 2026): Claude Sonnet 5.5** as the main agent, behind a thin provider interface so other models can be swapped in through config for evaluation.
- Returns a list of validated actions plus a short explanation for the client to render.

### 3. Tools exposed to the agent

| Tool | Purpose |
|---|---|
| `search_catalog(query, filters)` | Semantic search over the catalog; returns item IDs with size, style, and placement rules. |
| `place_item(item_id, surface_id, position, rotation)` | Requests a placement; returns success or a specific violation. |
| `swap_item(placed_id, item_id)` | Replaces an item, keeping position when valid. |
| `remove_item(placed_id)` | Removes a placed item. |
| `get_design_state()` | Returns current placements. |

### 4. Catalog and retrieval

- A small catalog (about 50–100 items) of 3D models with permissive licenses, each with metadata: category, style tags, dimensions, allowed surfaces, and a short description.
- Descriptions are embedded and stored in a local vector index for semantic search, so "something cozy for reading" returns armchairs, floor lamps, and throws.
- Every item has a stable ID (for example `armchair_linen_01`), never a list position, because saved designs and eval results refer to items by ID.
- Code that reads the catalog tolerates missing optional fields, so fields can be added later (price, store link, source) without breaking existing entries or saved eval runs.
- **Embedding model (decided November 24, 2026): Qwen3-Embedding**, open weights (Apache 2.0), run locally. It is free, works offline, and gives reproducible results for the evaluation suite. Gemini Embedding 2 is an option later for image-based style search over item thumbnails.

### 5. Spatial constraint validation

- Collision checks against existing furniture and other placed items.
- Walkway clearance around doors and main paths.
- Surface rules: floor items on the floor, wall items on walls, tabletop items on tables.
- When a placement fails, return the specific violation so the agent can retry. This is the core of the project and where MR expertise shows.

### 6. Observability

- Log every agent step: prompt version, model, tool calls with arguments, validation results, latency, and token cost.
- A simple trace viewer or structured logs to explain any bad result.

### 7. Fallbacks

- Timeouts and retries for model calls, a capped number of agent steps per request, and a clear message to the user when the agent can't satisfy a request.

### 8. Deployment

**Decision (November 24, 2026): run locally during development, and host the backend for the demo and for client sessions.** Sessions happen in clients' homes on their Wi-Fi or a phone hotspot, so the headset needs a backend it can reach from anywhere.

**Hosting provider (decided November 24, 2026): AWS.** Azure is already demonstrated through two years at Microsoft, so AWS adds a skill many target roles ask for. Azure Container Apps is the runner-up.

- **Compute:** Amazon ECS Express Mode on Fargate. (AWS App Runner closed to new customers on April 30, 2026.)
- **Storage:** Amazon S3 for saved room models and designs, behind a small storage interface so the code never calls S3 directly. Moving to Azure Blob Storage would mean swapping one adapter.
- **Secrets and access:** AWS Secrets Manager for API keys, and IAM roles with least privilege.
- **Infrastructure as code (decided November 24, 2026): Terraform**, so the whole setup is reproducible and reviewable in the repo. Chosen over AWS CDK because it works across clouds (matching the Azure fallback), is the more common skill on job postings, and has a dedicated ECS Express Mode resource (`aws_ecs_express_gateway_service`). Terraform state lives in an S3 bucket with locking.

- The backend is packaged in a container from the start, with all settings (model, keys, limits) in environment variables, so the same build runs locally and hosted.
- The Unity client reads the backend URL from a setting, so switching between local and hosted needs no code change.
- A public endpoint spends real API credits, so the hosted service has:
  - a required access key on every request
  - rate limits per key and caps on request size and agent steps
  - a hard monthly spending limit on the Anthropic account
  - HTTPS only
- Monitoring: health check, request and error logs, and cost per request from the existing observability logs.
- The instance needs a few GB of memory for Qwen3-Embedding. Scale to a minimum of one instance during client sessions and demos to avoid slow cold starts.

### 9. Client data and privacy

A room scan is a map of someone's home, so client data is handled carefully from the start:

- All saved data (room models, designs, session logs) is stored per client ID, even while Patricia is the only user.
- Clients give consent before their room is scanned and saved.
- Data is encrypted at rest and in transit, and a client's data can be fully deleted on request.
- Logs and traces contain no names, addresses, or other identifying details.
- Real client rooms never go into the public repo or the evaluation set without explicit permission and anonymization.
- Authentication sits behind one interface: an access key today, real user accounts later.

## Evaluation

A repeatable suite that runs without the headset.

- **Test set:** saved room models (about 5–10 rooms) paired with about 30 requests of varying difficulty.
- **Metrics:** valid placement rate, constraint violations per request, request success rate (judged against a simple rubric), agent steps per request, latency, and cost per request.
- Run the suite on every prompt or model change and keep results in the repo so improvements are visible over time.
- **Model comparison:** run the same suite across budget, mid-tier, and possibly top-tier models (from Anthropic and other providers) alongside Claude Sonnet 5.5, and report success rate against cost and latency per request.

## Agentic coding workflow

- Keep this spec and a project instruction file for the coding agent in the repo.
- Delegate well-scoped work to the agent: the backend service scaffolding, tool schemas, unit tests, the evaluation harness, and logging.
- Own the judgment-heavy work directly: spatial math, scene data handling, constraint logic, and on-device verification.
- Note in commits and the README where the agent's output needed correction and how it was caught.
- Add AI-assisted code review in CI alongside the tests.

## Milestones

Planned for about 7 hours a week alongside the job search, starting Monday, November 30, 2026. Each milestone is due on a Sunday. Weeks 4 and 5 fall over the holidays, so the plan keeps one buffer week: January 17 is the target finish and January 24 the latest.

Progress is tracked in the repo's GitHub Issues, with one GitHub milestone per row below.

| Weeks | Due | Milestone | Outcome |
|---|---|---|---|
| 1–2 | Dec 13 | Room model | Define the JSON room model, build it from simulated scene data in the editor, and place a hard-coded item on a labeled surface. Switch to real Quest 3 scene data once the device arrives (needed by about December 21). |
| 3–4 | Dec 27 | Agent loop | Backend service with the agent and tools, catalog with semantic search, and constraint validation, tested against saved room models. A top-down 2D view of rooms and placed items, with a README GIF of the agent decorating a saved room. |
| 5 | Jan 3 | End to end | Voice request on the headset to placed, anchored items with an explanation; undo and swap. |
| 6 | Jan 10 | Quality | Evaluation suite, logging and traces, fallbacks, and a first round of prompt improvements backed by eval results. |
| 7 | Jan 17 (buffer to Jan 24) | Showcase | Deploy the backend with its safeguards, then the demo video, README with architecture diagram, eval results, and a "How I built this" section, plus a short write-up. |

### Portfolio checkpoints

Vignette is linked from job applications while it is being built, so the repo should look credible at every stage, not only at the end.

| When | What a visitor sees |
|---|---|
| Now | README marked "in progress", the spec, and the milestones board. |
| Dec 13 | Room model schema, sample rooms, Unity export, CI running. |
| Dec 27 | **Main checkpoint:** the agent decorates saved rooms with validated placements, first eval numbers, and a GIF of the top-down view in the README. |
| Mid to late January | Full headset demo video, hosted backend, model comparison, and write-up. |

Update the README's status section at each checkpoint.

### Top-down 2D view

A simple renderer that draws a room model from above (walls, surfaces, existing furniture, walkway zones) and the agent's placed items, including rejected placements and their violations. It gives Vignette a visual demo before the headset work is done, and it stays useful afterward for debugging eval runs. It reads only saved room models and design states, so it needs no headset or Unity.

## Deliverables

- Public GitHub repo with code, spec, agent instructions, and eval results.
- 30–60 second demo video.
- A GIF of the top-down view for the README (by the December 27 checkpoint).
- README with an architecture diagram and the agentic workflow story.
- A short blog post or write-up.
- A résumé bullet and a portfolio page entry.

## Future phases

Not part of the 7-week plan. Listed so that early design choices leave room for them.

**Phase 2: client tool.** Use Vignette in paid client sessions on Patricia's headset. Save and reload each client's rooms and designs, and give clients something to keep afterward, such as screenshots or a shareable web view of the design.

**Phase 3: scanning real products.** Scan products that can be bought and add them to the catalog:

1. **Capture:** photograph the product and build a 3D model (for example Apple Object Capture or Polycam).
2. **Clean up:** convert to GLB, simplify the mesh for Quest, and scale it to the real measured dimensions.
3. **Describe:** a vision-capable model drafts category, style tags, description, and allowed surfaces; Patricia adds price and store link, then reviews and approves.
4. **Index:** embed the description and add it to the search index.

This adds catalog fields (source, price, store link, a reviewed flag), added when the feature is built.

**Phase 4: public app.** Open Vignette to anyone: user accounts, a phone AR version (most people don't own a headset), app store distribution, and support. Check retailer terms before distributing scanned branded products.

## Open questions

- The budget for API costs during development and evaluation, and which models to include in the comparison.
- Where the catalog's 3D models come from, and their licenses.
- The expected monthly AWS cost.
