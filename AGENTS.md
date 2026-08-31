# Repository guidance

## GitHub decision record

After a verified gameplay, simulation, domain, or design change, audit the repository's GitHub issues before handing off the work.

- Add a detailed implementation update to the primary tracking issue and concise cross-references to every materially affected decision or prototype issue, including closed issues.
- Record the observable behavior, verification performed, whether the result is merely implemented or actually playtest-validated, and the next planned step when known.
- Leave unrelated issues untouched. Preserve issue bodies as their original question or decision record; use comments for implementation updates.
- Change issue state only when its acceptance criteria are satisfied or the user explicitly requests the state change.
- If GitHub is unavailable, report exactly which ticket updates remain pending.

The ticket audit is complete when every materially affected issue is either updated or explicitly accounted for as unchanged.
