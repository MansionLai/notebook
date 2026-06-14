# Phase 0 Option B Documentation Enhancement Design

## Summary

This design updates the `Option B：Mac mini + Azure MCP + IaC` section in `kubernetes/3node-kubevirt/phase-0.md` so the documentation better explains the MCP architecture and provides a navigable entry point to the future IaC workspace.

The change is documentation-only. It does not create the actual Bicep implementation yet.

## Goals

1. Add a simple Mermaid diagram that explains the MCP architecture in Option B.
2. Keep the existing table-based explanation and supplement it visually.
3. Turn the "載入 IaC 模板與參數檔" step into a clickable navigation point.
4. Reserve the future `kubernetes/3node-kubevirt/iac/README.md` path so the link is valid immediately.

## Non-goals

1. Implementing Bicep files.
2. Expanding Phase 0 scope beyond the existing Option B explanation.
3. Rewriting the rest of `phase-0.md`.
4. Moving the detailed design spec out of `docs/superpowers/specs/`.

## Files to Change

```text
kubernetes/3node-kubevirt/phase-0.md
kubernetes/3node-kubevirt/iac/README.md
```

## Content Design

### `phase-0.md`

Only the `Option B：Mac mini + Azure MCP + IaC` section will change.

Planned updates:

1. Keep the existing `MCP 架構是什麼` table.
2. Add a simple Mermaid `flowchart TD` directly below the table.
3. Keep the diagram educational and high-level rather than Azure-internals-heavy.
4. Update `Option B 執行流程` step 3 to link to the future IaC landing page using a relative link to `./iac/`.

### Mermaid diagram intent

The diagram should show:

- User working from the Mac mini
- Mac mini containing:
  - Copilot CLI
  - Azure MCP Server
  - IaC / Bicep files
- Azure MCP Server connecting to Azure API / ARM
- Azure provisioning the target resources:
  - Resource Group
  - VNet / Subnets
  - NSG
  - 3 VMs
  - Worker NIC2

This keeps the visual focused on "who orchestrates what" instead of trying to replace the infrastructure architecture diagrams already documented elsewhere.

### `iac/README.md`

Create a placeholder landing page under the reserved future IaC path.

Planned contents:

1. Short description that this folder will hold the Option B Bicep templates, parameters, and deployment instructions.
2. Explicit status note that the design/spec is complete but implementation has not started.
3. Link to the existing design spec:
   - `docs/superpowers/specs/2026-05-05-kubevirt-phase0-optionb-bicep-design.md`
4. Short list of expected future files:
   - `main.bicep`
   - `main.bicepparam`
   - `modules/`
   - deployment instructions

## Navigation Design

The Phase 0 page remains the conceptual guide. The future `iac/README.md` becomes the execution-oriented landing page for Option B infrastructure code. This keeps documentation layered:

- `phase-0.md` explains the phase and the two operating modes.
- `iac/README.md` becomes the implementation landing page for IaC assets.
- `docs/superpowers/specs/...` keeps the internal design record.

## Success Criteria

This design is successful when:

1. The Option B section contains both the table and a readable Mermaid architecture diagram.
2. The execution flow links to a valid `iac/README.md` page.
3. The placeholder IaC page clearly communicates that Bicep is not implemented yet.
4. Readers can move from Phase 0 documentation to the future IaC area without confusion.
