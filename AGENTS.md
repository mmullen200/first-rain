# First Rain agent guidance

## Sources of truth

- Before changing game concepts, player-facing language, or design decisions, read `CONTEXT.md` and use its canonical terms.
- Before starting or handing off issue-backed work—or selecting, creating, resolving, or organizing tickets—read `docs/agents/issue-tracker.md` and follow its Wayfinder workflow.
- Before changing a prototype, read the README beside that prototype for its question, controls, boundaries, and verification commands.

## Gameplay prototypes

- Player-facing design questions require playable Godot evidence. Supporting documents and isolated models may inform the work, but they do not validate gameplay.
- Extend the existing Godot prototype closest to the active question unless the issue explicitly requires an isolated experiment.
- Treat prototype thresholds, timings, quantities, visuals, and one-off fixtures as disposable. Preserve the decision being tested, not accidental implementation detail.
- Keep ordinary play situated and bounded: prefer world cues, local instruments, and ecological consequences over omniscient debug information, recipes, or quest instructions.

## Validation

- Experiential questions remain unvalidated until the user completes the stated playtest gate. Automated checks establish behavior, not player comprehension or fun.
- After changing `prototypes/godot-first-interaction`, run every headless regression command listed in its README.
- For player-facing changes, launch one fresh Godot instance and visually confirm the expected prototype title and controls before handing it to the user. Stop stale Godot sessions launched by the agent first.
- Keep temporary probes and captured debug artifacts out of commits.

## Branches and capture

- Use a dedicated `prototype/*` branch for throwaway playable experiments and preserve the validated branch as primary evidence.
- Keep unrelated user changes intact and keep commits scoped to the active issue.
- Record the question, branch, evidence, playtest result, and resulting decision on the GitHub issue before closing it.
