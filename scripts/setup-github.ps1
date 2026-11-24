# Creates Vignette's GitHub labels, milestones, and starter issues (Milestone 1, two Milestone 2 issues, and parking-lot questions).
#
# Requirements: GitHub CLI (gh) installed and signed in (`gh auth login`).
# Run from the repo root:   powershell -ExecutionPolicy Bypass -File scripts\setup-github.ps1
#
# Safe to re-run: existing labels are updated, and existing milestones and
# issues (matched by title) are skipped.

$ErrorActionPreference = "Stop"

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI (gh) not found. Install it from https://cli.github.com and run 'gh auth login'."
}
gh auth status | Out-Null
if ($LASTEXITCODE -ne 0) { throw "gh is not signed in. Run 'gh auth login' first." }

$repo = gh repo view --json nameWithOwner --jq .nameWithOwner
if ($LASTEXITCODE -ne 0 -or -not $repo) { throw "Run this from inside the Vignette repo." }
Write-Host "Setting up $repo" -ForegroundColor Cyan

# ---------------------------------------------------------------- Labels
$labels = @(
    @{ name = "agent-task";     color = "5319e7"; desc = "Can be delegated to the coding agent" },
    @{ name = "patricia-owned"; color = "d93f0b"; desc = "Patricia owns this; the agent proposes, doesn't implement" },
    @{ name = "backend";        color = "1d76db"; desc = "Python agent service" },
    @{ name = "unity";          color = "0e8a16"; desc = "Unity client" },
    @{ name = "eval";           color = "fbca04"; desc = "Evaluation suite and test rooms" },
    @{ name = "infra";          color = "006b75"; desc = "AWS, Terraform, CI" },
    @{ name = "parking-lot";    color = "c5def5"; desc = "Future ideas and open questions, not in the current milestone" }
)
foreach ($l in $labels) {
    gh label create $l.name --color $l.color --description $l.desc --force | Out-Null
    Write-Host "  label: $($l.name)"
}

# ------------------------------------------------------------ Milestones
# Due dates are Sundays, 11:59 pm Eastern (04:59 UTC the next day).
$milestones = @(
    @{ title = "1. Room model"; due = "2026-12-14T04:59:00Z"; desc = "Weeks 1-2. JSON room model from simulated scene data; place a hard-coded item on a labeled surface." },
    @{ title = "2. Agent loop"; due = "2026-12-28T04:59:00Z"; desc = "Weeks 3-4. Backend agent and tools, catalog with semantic search, constraint validation, tested against saved rooms." },
    @{ title = "3. End to end"; due = "2027-01-04T04:59:00Z"; desc = "Week 5. Voice request on the headset to placed, anchored items with an explanation; undo and swap." },
    @{ title = "4. Quality";    due = "2027-01-11T04:59:00Z"; desc = "Week 6. Eval suite, logging and traces, fallbacks, first prompt improvements backed by eval results." },
    @{ title = "5. Showcase";   due = "2027-01-18T04:59:00Z"; desc = "Week 7. Deploy with safeguards; demo video, README, eval results, write-up. Buffer week: latest finish Jan 24." }
)
$existingMilestones = gh api "repos/$repo/milestones?state=all&per_page=100" --jq ".[].title"
foreach ($m in $milestones) {
    if ($existingMilestones -contains $m.title) {
        Write-Host "  milestone exists: $($m.title)"
        continue
    }
    gh api "repos/$repo/milestones" -f title="$($m.title)" -f due_on="$($m.due)" -f description="$($m.desc)" | Out-Null
    Write-Host "  milestone: $($m.title)"
}

# ---------------------------------------------------------------- Issues
$m1 = "1. Room model"
$issues = @(
    @{ title = "Create the repo layout from CLAUDE.md"; milestone = $m1; labels = @("agent-task");
       body = @"
Create the folder structure listed in CLAUDE.md (unity/, backend/ and its subfolders, eval/, infra/, docs/, scripts/).

- [ ] .gitignore covering Unity, Python, .env, and Terraform state (*.tfstate, .terraform/, secret *.tfvars)
- [ ] .env.example documenting the expected environment variables
- [ ] No secrets or generated files committed
"@ },
    @{ title = "Set up the Python project and CI"; milestone = $m1; labels = @("agent-task", "backend");
       body = @"
- [ ] Python packaging for backend/ (pyproject.toml), with type checking and linting
- [ ] pytest set up with one passing test
- [ ] GitHub Actions workflow that runs lint and tests on every push and pull request
"@ },
    @{ title = "Define the JSON room model schema"; milestone = $m1; labels = @("patricia-owned", "backend");
       body = @"
The contract between the Unity client, the backend, and the saved eval rooms (see SPEC.md > Architecture > Perception).

- [ ] Room bounds and coordinate frame conventions (units, up axis, handedness)
- [ ] Labeled surfaces: ID, type, position, size, orientation
- [ ] Existing furniture as bounding boxes
- [ ] Walkway zones
- [ ] Schema version field
- [ ] Pydantic models plus an exported JSON Schema

Do this first: other Milestone 1 issues depend on it.
"@ },
    @{ title = "Write 2-3 sample room models by hand"; milestone = $m1; labels = @("patricia-owned", "eval");
       body = @"
Hand-authored rooms in eval/rooms/ that match the schema, for example a living room, a bedroom, and a small studio.

- [ ] Each includes at least one door and walkway, a table, and a wall
- [ ] No real client rooms
"@ },
    @{ title = "Load and validate room models, with unit tests"; milestone = $m1; labels = @("agent-task", "backend");
       body = @"
- [ ] Load a room model from JSON and validate it against the schema
- [ ] Clear error messages for invalid rooms
- [ ] Round-trip test (load, save, load) for every room in eval/rooms/
- [ ] Tests for a few deliberately invalid rooms
"@ },
    @{ title = "Set up the Unity project with Meta XR SDK and XR Simulation"; milestone = $m1; labels = @("patricia-owned", "unity");
       body = @"
- [ ] Unity project in unity/ with the Meta XR SDK
- [ ] XR Simulation (or Meta XR Simulator) running a simulated room in the editor
- [ ] Unity .gitignore working (Library/, Temp/, Builds/ excluded)
"@ },
    @{ title = "Export a room model from simulated scene data in Unity"; milestone = $m1; labels = @("patricia-owned", "unity");
       body = @"
- [ ] Read the simulated room's scene data (planes, labeled surfaces, furniture volumes)
- [ ] Convert to the JSON room model, keeping perception and serialization separate from rendering
- [ ] Exported file passes the backend validator
"@ },
    @{ title = "Place one hard-coded item on a labeled surface in the editor"; milestone = $m1; labels = @("patricia-owned", "unity");
       body = @"
- [ ] Place a test item on a surface found by its label (for example, the first table)
- [ ] Item sits on the surface, correctly oriented, at real scale
"@ },
    @{ title = "Fill in CLAUDE.md Commands and add docs/agent-corrections.md"; milestone = $m1; labels = @("agent-task");
       body = @"
- [ ] Commands section in CLAUDE.md lists real install, run, test, and eval commands
- [ ] docs/agent-corrections.md created with a short template (date, what went wrong, how it was caught, fix)
"@ },
    @{ title = "Top-down 2D view of rooms and placed items"; milestone = "2. Agent loop"; labels = @("agent-task", "eval");
       body = @"
See SPEC.md > Portfolio checkpoints > Top-down 2D view.

- [ ] Draw a room model from above: walls, labeled surfaces, existing furniture, walkway zones
- [ ] Overlay the agent's placed items, with item IDs
- [ ] Show rejected placements and their violations in a distinct style
- [ ] Reads only saved room models and design states (no headset or Unity needed)
- [ ] Can export a step-by-step sequence for an animated GIF
"@ },
    @{ title = "Dec 27 portfolio checkpoint: README GIF and status update"; milestone = "2. Agent loop"; labels = @("patricia-owned");
       body = @"
- [ ] GIF of the agent decorating a saved room, from the top-down view
- [ ] First eval numbers in the README
- [ ] README status section updated; nothing claimed that doesn't work yet
"@ },
    @{ title = "Decide API budget and which models to compare"; milestone = $null; labels = @("parking-lot");
       body = "Open question from SPEC.md. Starting point from planning: hard limit of `$50/month (`$100 in heavy-eval weeks), alerts at 50% and 80%, a per-eval-run cost cap, and a separate key for the hosted backend." },
    @{ title = "Decide where the starter catalog's 3D models come from"; milestone = $null; labels = @("parking-lot");
       body = "Open question from SPEC.md. Licenses must allow commercial use, since Vignette will be used with decorating clients." },
    @{ title = "Estimate monthly AWS cost"; milestone = $null; labels = @("parking-lot", "infra");
       body = "Open question from SPEC.md. Easiest to estimate once the backend is running (ECS Express Mode on Fargate, S3, Secrets Manager, load balancer)." }
)

$existingIssues = gh issue list --state all --limit 500 --json title --jq ".[].title"
foreach ($i in $issues) {
    if ($existingIssues -contains $i.title) {
        Write-Host "  issue exists: $($i.title)"
        continue
    }
    $ghArgs = @("issue", "create", "--title", $i.title, "--body", $i.body)
    foreach ($label in $i.labels) { $ghArgs += @("--label", $label) }
    if ($i.milestone) { $ghArgs += @("--milestone", $i.milestone) }
    gh @ghArgs | Out-Null
    Write-Host "  issue: $($i.title)"
}

Write-Host "`nDone. Next: create a Projects board (Backlog, This week, In progress, Done) at https://github.com/$repo/projects" -ForegroundColor Green
