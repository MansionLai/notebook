---
name: managing-notebook-repo
description: Use when creating, updating, or organizing notes in the MansionLai/notebook GitHub repo — folder naming, required files per topic, Mermaid diagrams, architecture graphs, and pushing to GitHub.
---

# Managing the MansionLai Notebook Repo

## Repo Location

```
Local:  /Users/mansionlai/Documents/code/notebook-sync/
Remote: https://github.com/MansionLai/notebook
Branch: main
```

---

## Folder Taxonomy

Group by **topic domain** first, then **project** underneath:

```
notebook/
├── <topic>/                  # top-level domain (e.g. kubernetes, homeassistant)
│   ├── <project>/            # specific project under that domain
│   │   ├── architecture.md
│   │   ├── buildup.md
│   │   ├── commands.md
│   │   ├── setup-flowchart.md
│   │   └── *.png / *.svg     # embedded diagrams
│   └── concepts/             # cross-project concepts under this domain
│       └── <topic-name>.md
├── agents/                   # Copilot agent configs (don't move)
└── docs/                     # specs, plans, superpowers (don't move)
```

### Current Top-Level Topics

| Folder | Contains |
|--------|---------|
| `kubernetes/` | `3node-kubevirt/`, `3node-multipass/`, `concepts/kubevirt/` |
| `homeassistant/` | `integration-watchdog/`, `vm-watchdog/` |
| `agents/` | note-taker.md, coder.md |
| `docs/` | superpowers specs & plans |

### Naming Rules

- Topic folder: lowercase, no prefix (e.g. `kubernetes/` not `k8s/`)
- Project folder: descriptive kebab-case (e.g. `3node-kubevirt`, `integration-watchdog`)
- No flat root-level project folders — always nest under topic

---

## Required Files Per Project Folder

| File | Purpose | Required |
|------|---------|----------|
| `architecture.md` | System diagram + component table | ✅ |
| `commands.md` | All CLI commands with inline comments | ✅ |
| `buildup.md` | Step-by-step setup guide (Phase 0..N) | ✅ for infra projects |
| `setup-flowchart.md` | Mermaid setup flow | ✅ |
| `*.png` / `*.svg` | Architecture diagram exports | for visual diagrams |

For **concepts** notes (not infra projects): single `.md` file with overview, Mermaid flow, tables, source code snippets, and references.

---

## Mermaid Diagrams

### Flowchart (setup & process flows)

```markdown
​```mermaid
flowchart TD
    A([Start: descriptive label]) --> B[Action step]
    B --> C{Decision?}
    C -->|Yes| D[Branch A]
    C -->|No| E[Branch B]
    D & E --> F([End state])
​```
```

**Conventions:**
- `([...])` — start/end states (stadium shape)
- `[...]` — action / component
- `{...}` — decision / condition
- `A & B --> C` — merge multiple nodes
- Node labels: concise, use `\n` for line breaks inside label
- Avoid `[/dev/kvm]` style brackets in labels — escaping issues in GitHub renderer

### Architecture Graph (tech-stack overview)

Use Mermaid `graph LR` or `graph TD` with subgraph groupings:

```markdown
​```mermaid
graph TD
    subgraph Control Plane
        A[virt-operator] --> B[virt-api]
        A --> C[virt-controller]
    end
    subgraph Node
        D[virt-handler]
    end
    C --> D
​```
```

**For SVG exports** (dark/light variants): store as `architecture-dark.svg` and `architecture.svg` alongside the `.md` file.

### Sequence Diagram (install/call flows)

```markdown
​```mermaid
sequenceDiagram
    participant U as User
    participant O as virt-operator
    U->>O: kubectl apply kubevirt-cr.yaml
    O->>O: Reconcile Loop
    O-->>U: status.phase = Deployed
​```
```

---

## Pushing to GitHub

Always pull before editing when the local repo may be behind:

```bash
cd /Users/mansionlai/Documents/code/notebook-sync
git pull origin main

# ... make edits ...

git add <files>
git commit -m "<type>: <short description>

<optional body>

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
git push origin main
```

### Commit Type Prefixes

| Type | When |
|------|------|
| `docs:` | New or updated notes |
| `refactor:` | Folder restructure, rename |
| `chore:` | Delete empty files, cleanup |
| `feat:` | New concept file or new project folder |

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Flat root-level folders (`k8s-3node-kubevirt/`) | Nest under topic: `kubernetes/3node-kubevirt/` |
| `curl .../file.go` to get YAML | Go source ≠ apply-ready YAML; use `kubectl get -o yaml` or image dump |
| Mermaid label contains `[/path]` brackets | Use plain text or escape: `[path to dev kvm]` |
| Pushing without pull on shared repo | Always `git pull` first |
| Concepts file inside project folder | Put under `<topic>/concepts/<name>.md` |
