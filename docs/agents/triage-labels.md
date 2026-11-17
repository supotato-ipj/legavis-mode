# Triage Labels

The skills speak in terms of five canonical triage roles. These roles map to identical GitHub label strings on this repo.

| Canonical role    | GitHub label       | Meaning                                  |
| ----------------- | ----------------- | ---------------------------------------- |
| `needs-triage`    | `needs-triage`    | Maintainer needs to evaluate this issue  |
| `needs-info`      | `needs-info`      | Waiting on reporter for more information |
| `ready-for-agent` | `ready-for-agent` | Fully specified, ready for an AFK agent  |
| `ready-for-human` | `ready-for-human` | Requires human implementation            |
| `wontfix`         | `wontfix`         | Will not be actioned                     |

When a skill mentions a role (e.g. "apply the AFK-ready triage label"), use the same-name GitHub label. All five labels exist on the repo; the workflow is described in `docs/agents/issue-tracker.md`.
