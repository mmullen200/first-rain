# Issue tracker: GitHub

Issues and specs for this repository live in GitHub Issues. Use the `gh` CLI for operations and infer the repository from the local `origin` remote.

## Wayfinding operations

- The map is one issue labelled `wayfinder:map`.
- Decision tickets are issues labelled `wayfinder:research`, `wayfinder:prototype`, `wayfinder:grilling`, or `wayfinder:task`.
- Link tickets as GitHub sub-issues when supported. Otherwise, keep a task list on the map and begin each ticket with `Part of #<map>`.
- Use GitHub's native issue dependencies when supported. Otherwise, begin blocked tickets with `Blocked by: #<number>`.
- The frontier is the map's open, unblocked, unassigned tickets in map order.
- Claim a frontier ticket by assigning it to the driving developer before doing any work.
- Resolve a ticket with a resolution comment, close it, and append a linked one-line gist to the map's `Decisions so far` section.

Pull requests are not a triage surface.
