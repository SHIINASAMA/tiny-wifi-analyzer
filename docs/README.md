# Project Documentation Index

This directory contains project documentation for human maintainers and agents.

## Active planning

| File | Purpose |
|------|---------|
| [TODO.md](TODO.md) | Planned features, engineering work, and product directions |
| [ISSUES.md](ISSUES.md) | Current known defects, regressions, and deferred items |
| [2026-09-02-aggregate-spectrum-heatmap.md](superpowers/plans/2026-09-02-aggregate-spectrum-heatmap.md) | Implementation plan for the aggregate Spectrum Heatmap |
| [2026-09-03-gpu-heatmap-computation.md](superpowers/plans/2026-09-03-gpu-heatmap-computation.md) | Implementation plan for Metal-backed Heatmap field computation |
| [2026-09-09-network-diagnostics-hardening.md](superpowers/plans/2026-09-09-network-diagnostics-hardening.md) | Complete self-check hardening plan, prioritizing correct gateway selection and interface-bound probing |

`TODO.md` records work that has not been done yet. Completed items are removed
rather than archived. `ISSUES.md` records active problems and explicitly
deferred items — resolved issues are removed unless they carry long-term
context.

## Design specifications

| File | Purpose |
|------|---------|
| [2026-09-02-aggregate-spectrum-heatmap-design.md](superpowers/specs/2026-09-02-aggregate-spectrum-heatmap-design.md) | Aggregate current-scan Heatmap using shared Spectrum envelopes |
| [2026-09-09-network-diagnostics-hardening-design.md](superpowers/specs/2026-09-09-network-diagnostics-hardening-design.md) | Proposed network self-check fixes for route selection, partial reports, proxy assessment, and bounded reruns |

## Agent-oriented technical references

Agent-optimized technical knowledge (architecture, testing, accessibility,
BLE, charts, MCP, regulatory, windowing) lives under
[`.agents/references/`](../.agents/references/README.md). These references are
organized for on-demand loading by task type and are not duplicated here.

## Contribution and policy documents

| File | Purpose |
|------|---------|
| [`.github/CONTRIBUTING.md`](../.github/CONTRIBUTING.md) | Contribution guide for human contributors |
| [`SECURITY.md`](../SECURITY.md) | Security policy and vulnerability reporting |
| [`LICENSE`](../LICENSE) | Apache License 2.0 |

## Future direction

A possible future cleanup is to migrate general-purpose technical
documentation into `docs/architecture/` and let `.agents/references/README.md`
focus purely on routing. That migration is deferred to avoid large-scale
renaming and link churn in this pass.
