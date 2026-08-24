# Hybrid ecological simulation in Godot 4.x

_Research date: 2026-08-24. Sources are limited to official Godot documentation. “Documented” statements report engine behavior; “Recommendation” statements are design inferences for First Rain and are not Godot guarantees._

## Decision summary

**Recommendation:** build the prototype as a deterministic, data-oriented simulation core driven by an integer ecological tick, with Godot nodes acting as adapters for input, physics, rendering, audio, and debugging. Store ecological cells in flat packed arrays, update them with double buffers, and represent animals in authoritative data records even when a smaller number of scene nodes visualize them. Quantize astronaut interventions into commands applied at ecological tick boundaries.

Start single-threaded in typed GDScript. At prototype scale, use a 128×128 grid (16,384 cells), roughly 5–10 ecological ticks per second, and tens to low hundreds of mobile agents. Those numbers are initial test targets, not documented Godot limits. Profile before adding dirty-region scheduling, worker threads, C#, or GDExtension.

Treat replay determinism as a property of the ecological core within a pinned game/engine version, not as a guarantee supplied by Godot physics. Godot explicitly says its physics engine is not deterministic, while a seeded `RandomNumberGenerator` produces a reproducible sequence but its underlying algorithm is an implementation detail ([release policy](https://docs.godotengine.org/en/stable/about/release_policy.html#what-are-the-criteria-for-compatibility-across-engine-versions), [RandomNumberGenerator](https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html)).

## 1. Clock and authority

### What Godot documents

- Godot separates variable-rate rendering/idle processing from fixed-rate physics processing. `_physics_process()` runs at fixed intervals as much as possible, at 60 ticks per second by default ([idle and physics processing](https://docs.godotengine.org/en/stable/tutorials/scripting/idle_and_physics_processing.html)).
- `Engine.physics_ticks_per_second` controls both physics simulation and `_physics_process()`. CPU usage scales approximately with this rate, and only `max_physics_steps_per_frame` physics steps can be simulated per rendered frame; if the engine cannot keep up, the project can appear to slow down ([Engine](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-property-physics-ticks-per-second)).
- Godot recommends fixed, predetermined physics/game-logic ticks for consistency and predictability, and offers interpolation to smooth rendering between physics ticks ([physics interpolation introduction](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation_introduction.html)). This is consistency guidance, not a cross-platform determinism guarantee.
- Godot's physics engine is explicitly non-deterministic ([release policy](https://docs.godotengine.org/en/stable/about/release_policy.html#what-are-the-criteria-for-compatibility-across-engine-versions)).

### Recommended First Rain clock

Keep two clocks:

1. **Godot physics clock (normally 60 Hz):** astronaut movement, collision queries, camera, and visual transforms.
2. **Ecological clock (initially 5–10 Hz):** all authoritative cell changes, organism decisions, weather forcing, awakening metrics, and Presence-related systemic effects.

`SimulationRunner` may be called from `_physics_process()`, but it should advance the ecological core by an **integer number of complete ecological steps**, never by feeding a variable render delta into ecological rules. Pause means zero requested steps. Fast-forward means requesting more complete ecological steps, with a per-frame work cap so the UI remains responsive. Manual single-step should use exactly the same entry point as live play and replay.

This custom clock is preferable to using `Engine.time_scale` as the ecosystem's authority. Godot documents `time_scale` as affecting engine time and warns that large speedups may require higher physics tick rates for reliability ([Engine](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-property-time-scale)). A separate ecological step budget keeps survival simulation speed, physics responsiveness, and replay semantics independently controllable.

Astronaut actions that affect ecology should become immutable commands such as `Water(cell, amount, actor_id, sequence)`. Queue them during input/physics processing, then apply them at the next ecological boundary in a stable order. This makes “the same replay” mean the same initial snapshot plus the same tick-stamped command sequence, independent of rendering frame rate.

## 2. Hybrid state model

### Ecological cells

Use a row-major flat index, `index = y * width + x`, rather than one node or object per cell. Prefer a **structure of arrays**:

- `PackedFloat32Array` or quantized `PackedInt32Array` for moisture, nutrients, temperature, toxicity, and simple-life biomass;
- `PackedByteArray`/`PackedInt32Array` for categorical state, flags, species occupancy, and counters;
- a second same-shaped set of arrays for next-state output.

Godot documents that packed arrays use less memory and are generally faster to iterate and modify than equivalent typed arrays; for data below tens of thousands of elements, it also advises weighing maintainability because ordinary typed arrays may be more convenient ([GDScript container types](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html#packed-arrays)). Packed arrays are passed by reference, so an independent copy requires `duplicate()` ([PackedFloat32Array](https://docs.godotengine.org/en/stable/classes/class_packedfloat32array.html)).

**Recommendation:** use packed arrays immediately for the dense grid because their layout naturally matches cell sweeps and snapshots, but keep rule definitions and configuration readable as typed Resources or typed records. Do not prematurely pack every small collection.

### Mobile agents

Animals and other mobile organisms should be agents that sense nearby cell arrays and emit intended actions. Their authoritative state should include a stable integer ID, species, position (cell plus optional sub-cell coordinates), energy, age, behavioral state, and agent-local RNG state or stream identity.

Use nodes only where they buy something: astronaut physics, visible/interactable creatures, cameras, audio emitters, and a small number of distinctive larger organisms. A node-per-cell or node-per-blade architecture adds unnecessary scene-tree, notification, and rendering work. Godot's CPU optimization guide notes that very large node counts incur housekeeping overhead and gives a broad platform-dependent range from thousands to tens of thousands, emphasizing profiling on targets ([CPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html#scene-tree)).

### One ecological step

Use explicit phases, with no phase observing half-committed results:

1. Apply tick-stamped player, weather, and Presence commands in stable order.
2. Read only the current cell buffers and compute next cell buffers.
3. Have each agent read the same current snapshot and emit an intent (move, graze, reproduce, flee, die).
4. Resolve competing intents deterministically, for example by target cell, action priority, then stable agent ID.
5. Commit agent outcomes and swap current/next cell buffers.
6. Derive biodiversity, resilience, survival yields, awakening, and debug metrics from the committed state.
7. Increment the integer simulation tick.

This phase order is a First Rain recommendation. It prevents traversal order from silently becoming an ecological rule, makes conflicts inspectable, and creates safe seams for later parallelism. Rules that intentionally depend on order should encode that order as game design rather than inherit it from collection iteration.

For prototype correctness, sweep the full grid each tick. Add active-cell lists, dirty rectangles, or chunks only after benchmarks show a need; these optimizations complicate diffusion and can change behavior at active/inactive boundaries.

## 3. Determinism and random behavior

Godot documents that a fixed seed produces a reproducible pseudorandom sequence and that `RandomNumberGenerator.state` can be saved and restored. It also says the current generator is PCG32 but the algorithm is an implementation detail that must not be depended upon ([random-number tutorial](https://docs.godotengine.org/en/stable/tutorials/math/random_number_generation.html#random-seed-and-internal-state), [RandomNumberGenerator](https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html)).

Therefore:

- Give the simulation explicit RNG instances; never use implicit/global random calls inside rules.
- Separate streams by responsibility (weather, cell transitions, spawning, and optionally agent) so adding a decorative random draw does not shift every later ecological outcome.
- Save both seed and current state for every stream.
- Define stable traversal and conflict order; do not let worker completion order or scene-tree order determine results.
- Prefer integers or explicitly quantized values for thresholds, counters, probabilities, and biomass transfers when exact replay matters. Godot uses 32-bit floating-point values for vectors by default unless compiled for double precision ([`float` class](https://docs.godotengine.org/en/stable/classes/class_float.html)); the recommendation to quantize is a defensive inference, not a Godot promise that all integer-based simulations are automatically portable.
- Pin the engine and content/rule version for authoritative replays. Because the RNG algorithm is an implementation detail and Godot physics is non-deterministic, do not promise bit-identical replays across arbitrary Godot releases or platforms without a project-owned fixed-point math/RNG layer and cross-platform verification.

Keep Godot physics out of the causal ecological state. A predator's displayed body may collide and interpolate in Godot, but its ecological movement outcome should be computed by the simulation and then visualized. Astronaut collision can remain conventional physics; only the tick-stamped intervention command crosses into the ecological core.

## 4. Save, replay, and migration contract

Godot's official save-game guide supports JSON for simple, human-readable state and `FileAccess.get_var()`/`store_var()` for binary serialization. It documents JSON's larger size, limited types, and custom encoding burden, while binary serialization supports most common Variant types with smaller files ([saving games](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html#json-vs-binary-serialization)). `FileAccess` is intended for permanent data such as saves and configuration in `user://` ([FileAccess](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html)).

### Snapshot

Use an explicitly versioned snapshot dictionary or record, serialized with `FileAccess.store_var()` for normal saves. Include:

- save schema version, game build/rules version, Godot version, and content/config hash;
- world dimensions and current ecological tick;
- all current cell arrays (not disposable render caches);
- sorted agent records and next stable agent ID;
- every RNG seed and current state;
- queued commands and scheduled ecological events;
- weather, astronaut survival resources, awakening, and Presence relationship/systemic state.

Do not serialize live scene nodes as the authoritative format. Reconstruct visual nodes from the snapshot. Keep a JSON debug-export option for small scenarios, accepting the documented type and size limitations. Avoid enabling object deserialization for untrusted files: `FileAccess.get_var(allow_objects=true)` can deserialize objects, and Godot warns that deserialized objects can contain executable code ([FileAccess](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html#class-fileaccess-method-get-var)).

Use schema migrations rather than relying on property names and engine serialization to remain unchanged. A snapshot should fail clearly on an unsupported future schema, not partly load.

### Replay

A compact replay contains:

- an initial snapshot or scenario ID plus content hash;
- ordered `(tick, sequence, command_type, payload)` commands;
- periodic state checksums and, optionally, periodic recovery snapshots.

On playback, run the same core step function without physics or rendering authority. Check hashes at known ticks and stop at the first divergence. Long sessions can seek from the nearest periodic snapshot rather than resimulating from tick zero.

## 5. Debugging ecological emergence

Make the simulation observable before tuning it. Godot's debugger includes a script profiler, visual profiler, monitors, errors, stack traces, and breakpoints; the visual profiler covers rendering CPU/GPU work, while the standard profiler is needed for scripting and other non-rendering work ([debugger panel](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/debugger_panel.html)). Godot also supports application-defined performance monitors through `Performance.add_custom_monitor()` ([Performance](https://docs.godotengine.org/en/stable/classes/class_performance.html#class-performance-method-add-custom-monitor)).

Recommended custom monitors:

- ecological step time (last, mean, 95th percentile, worst);
- steps requested/completed/backlogged per render frame;
- active and changed cells by field/species;
- agent counts, births, deaths, moves, grazing, and unresolved intent conflicts;
- biomass, water, nutrients, trophic transfer, and mass-balance error;
- save size/time and replay checksum mismatches.

Add a debug inspector that can pause, single-step, inspect a cell and its neighbors, show “before → rule → after,” visualize agent intent/conflict resolution, toggle field overlays, and rewind to a recent in-memory snapshot. These are project recommendations, but they fit Godot's documented breakpoint/step debugger and monitor facilities.

Use debug-build `assert()` for invariants such as finite/nonnegative fields, valid agent references, legal occupancy, and conservation bounds. Godot ignores assertions in release builds, so assertions must not contain side effects ([GDScript `assert`](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html#assert-keyword)).

Create headless scenario tests that run a fixed seed and command log twice, compare checksums periodically, and report the first differing field/agent. Godot's command-line interface supports `--headless`, `--path`, `--script`, and controlled quitting, making nonvisual simulation runs suitable for automation ([command-line tutorial](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)). Add focused rule tests and small “ecological assay” scenarios alongside long golden replays; the long replay detects divergence, while the small case explains it.

## 6. Rendering without coupling visuals to authority

Render cells in chunks and update visuals from committed snapshots, never while a simulation phase is writing. Prototype overlays can use an image/texture or chunked mesh generated from packed state. Repeated moss tufts, fungus, or trees can use `MultiMeshInstance3D`: Godot documents MultiMesh as capable of drawing very large numbers of instances in one draw primitive, but individual instances are not independently frustum-culled, so dividing the world into several MultiMeshes is a documented workaround ([MultiMesh optimization](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html)).

This supports the 2.5D goal: keep the ecological grid computational and render an oblique 3D surface above it. The player sees continuous motion and growth, but rendering never writes ecological truth. Only changed chunks need visual refresh after correctness is established.

## 7. Threading: an escalation path, not a starting requirement

Godot's scene tree is not thread-safe. Its thread-safety guide advises against interacting with the active scene tree from worker threads and recommends deferred calls or server APIs for safe communication ([thread-safe APIs](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html)). `WorkerThreadPool` can distribute group tasks across worker threads, but Godot warns that it can hurt performance when work is not computationally expensive; every task must eventually be awaited ([WorkerThreadPool](https://docs.godotengine.org/en/stable/classes/class_workerthreadpool.html)).

**Recommendation:** remain single-threaded until the profiler shows ecological stepping violates its budget on target hardware. If threading becomes necessary:

- Workers may read an immutable current snapshot.
- Partition the grid into disjoint output ranges so each worker writes only its own next-buffer cells.
- Have agent workers emit thread-local intents; merge, sort, and resolve them deterministically on one thread.
- Never mutate scene nodes, Resources in use, rendering objects, or shared collections from worker tasks.
- Await every worker task before swapping buffers or publishing a snapshot.
- Benchmark the parallel version; task scheduling, synchronization, and copying can outweigh gains.

Node process thread groups also exist, but sub-threaded nodes are forbidden from accessing most nodes outside their group in debug mode ([Node process thread groups](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-property-process-thread-group)). A pure-data worker phase is easier to reason about and replay than distributing gameplay nodes across process groups.

If typed GDScript remains the measured bottleneck after algorithmic and data-layout improvements, evaluate C# or GDExtension for only the hot sweeps. Godot documents that static typing enables optimized GDScript opcodes ([static typing](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html#summary)), and its optimization guidance emphasizes measuring actual bottlenecks before optimizing ([CPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html#measuring-performance)).

## 8. Prototype-scale performance gates

These are recommended acceptance gates, not Godot guarantees:

| Stage | Test load | Gate before escalating |
|---|---:|---|
| Initial | 128×128 cells, 5–10 ecology Hz, 50–200 agents | One ecological step remains comfortably below its allotted interval on the minimum target machine; no persistent step backlog during normal play. |
| Stress | 256×256 cells, same rules, several hundred agents | Profiling identifies whether cells, agents, visual uploads, or saves dominate; optimize only the measured category. |
| Fast-forward | Multiple ecology steps per render frame | UI/input stays responsive, work is capped, and final checksums match normal-speed execution. |
| Replay | Representative 30–45 minute command log | Repeated runs under the same pinned build match at every checkpoint. |

Use the Godot script profiler for simulation code and the visual profiler for rendering; the latter explicitly excludes scripting and physics time ([debugger panel](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/debugger_panel.html#visual-profiler)). Test exported debug/release builds on the intended minimum hardware because editor measurements and desktop hardware can conceal bottlenecks.

## Recommended prototype decision

Adopt this baseline:

- Godot 4.x, typed GDScript, single-threaded simulation core.
- 128×128 row-major ecological grid in packed, double-buffered field arrays.
- 5–10 Hz integer ecological tick driven from, but logically independent of, Godot's 60 Hz physics loop.
- Stable-ID mobile agents that emit intents against an immutable tick snapshot.
- Tick-stamped player commands; stable phase and conflict ordering.
- Explicit RNG streams with saved seed/state.
- Versioned binary snapshots plus command-log replays and periodic checksums.
- Debug overlays, cell causality inspection, invariants, custom monitors, and headless deterministic scenarios from the first playable build.
- Chunked/MultiMesh presentation, with threading or native code introduced only after measured failure of the prototype budget.

This design preserves the important creative flexibility: ecological rules can change rapidly without entangling themselves with Godot scene topology, while replayable experiments make emergent behavior explainable enough to tune into a game rather than merely observe as a simulation.
