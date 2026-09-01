# First Rain: opening vertical-slice prototype

Throwaway Godot vertical slice for deciding whether the opening teaches movement, finite supplies, scientific observation, ecological intervention, recovery, cultivation, and the first sighting of the Presence through embodied play. The current branch additionally asks whether survival creates an expedition rhythm without crowding out ecological observation or making recoverable mistakes end the run.

## Run

Open `project.godot` in Godot 4.6 and press **F6/F5**, or run:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path prototypes/godot-first-interaction
```

## Controls

- **WASD / arrow keys** — move
- **E** — open the emergency cache, then pick up or place the loose shade panel
- **E** — harvest when standing beside a mature fungal fruiting cell
- **T** — lift a robust living moss/rhizome clump, then place it on another ecological cell
- **F** — scan a nearby moss patch
- **C** — send a suit-light signal toward a nearby ecological subject
- **J** — open or close the pause-only Basin Survey and detailed field record
- **V** — toggle the scanner's nearby moisture/toxicity analysis lens
- **Space** — spend one water dose on a nearby moss patch
- **Q** — spend one water dose on the astronaut when exposure is meaningful
- **Z** — eat carried fresh food first, otherwise a finite ration
- **R** — restart the experiment
- **F9** — open or close the observer-only evidence debugger; **[ / ]** selects an earlier or later causal event

## Question under test

Can one tiny 2.5D space carry the player from the crashed ship and finite wreck supplies through comparison with the damaged Field Scanner, a scarce ecological intervention, immediate and delayed feedback, a legible failure and recovery, a persistent scanner discovery record, and the first successful cultivation—without issuing a quest or revealing a recipe?

Moss behavior, water quantities, environmental variables, timing, and the loose shade panel are disposable test fixtures. They do not settle the later rule-set, survival-balance, feedback-tool, or toolkit decisions.

## Cellular ecology added for this revision

The visible square cells now carry provisional moisture, temperature, toxicity, nutrients, dormant moss, living moss, dead biomass, fungus, and shade values. A fixed deterministic tick updates all cells through double-buffered local rules:

- Water wakes dormant moss where temperature and toxicity permit.
- Living moss spreads into adjacent suitable cells and slows evaporation.
- Moss stress and ordinary turnover create dead biomass.
- Fungus awakens where dead biomass remains wet, spreads locally, decomposes it into nutrients, and slightly reduces toxicity.

Cell color is the first readable world cue: blue-green indicates moisture, green living moss, brown dead biomass, violet fungus, and gold edible fruiting bodies. The damaged Field Scanner supplements those cues with coarse local bands and explicit confidence; ordinary play does not show system-wide cell counts.

## Expanded ecological arc

- Wet, nutrient-rich fungus produces harvestable fruiting bodies. Harvest removes some fungus and nutrients, so repeated harvesting can damage the food source.
- Hunger creates a provisional survival reason to replace finite rations with renewable food.
- A simple agent-based grazer awakens when moss, fungus, and fruiting biomass cross thresholds. Its luminous teal body, amber head, and world label distinguish it from its dormant stone-like shell. When hungry it slowly follows the strongest viable moss signal, takes one bite, then holds a roaming direction across several cells while digesting before making an occasional bounded turn. It deposits manure in a different ecological cell, moving dead biomass and nutrients away from the feeding site before hunger sends it seeking again.
- Seeded regional weather continuously evolves heat, pressure, humidity, wind, cloud water, and dust. A heat-and-dust front can emerge from those conditions; grazer awakening does not trigger it. The front dries cells, raises heat and toxicity, and converts damaged moss to dead biomass; established living cover reduces the damage.
- During the warning, the Presence moves from the ridge to a bare depression and exposes a subsurface-moisture signal. This is a directional nudge, not an instruction: the player can scan, ignore, or spend water there.

All thresholds, meters, timings, yields, and weather damage values are accelerated prototype fixtures rather than balance decisions.

The ecological grid remains dormant until the astronaut commits the first water dose. Time spent inspecting the crash or leaving the prototype open therefore cannot silently dry the starting conditions before the first Field Experiment.

An established habitat can receive another scarce water Intervention after its measured local moisture falls below the provisional recovery threshold. A still-moist habitat rejects the same input without consuming water. Rewatering preserves the established state and supports systemic regrowth; it does not directly restore fungal fruiting tissue or replay first awakening.

## Ecological-feedback question

The omniscient global cell count is hidden during ordinary play. The damaged Field Scanner instead provides coarse-but-honest local bands, visible confidence, a stored baseline for before/after rescanning, comparison with the previously scanned site, a short world-space scan pulse, and an optional nearby analysis lens. The discovery record continues to retain species and causal relationships. This tests whether players can explain why one watering succeeds and another fails without receiving exact rules or fabricated uncertainty.

## Presence-communication question

The astronaut can press **C** beside a patch, grazer, or revealed refuge to direct a short suit-light signal toward that subject. The Presence communicates only after appearing in the ecological progression. It reuses a small grammar across contexts:

- one cyan pulse and direct movement proposes shared focus;
- a matched two-pulse response acknowledges the astronaut;
- alternating violet pulses between two recently signaled subjects ask whether they are related;
- three tight descending amber pulses plus recoil warn of danger;
- a wide two-part pulse around the refuge and astronaut marks reciprocal participation;
- one closed grey pulse and continued distance refuse a signal with no shared subject.

The status text describes observable behavior for this low-fidelity prototype, but never translates it into an objective. The playtest question is whether players begin anticipating the reused forms through embodied context, and whether they still feel free to inspect, disagree, or walk away.

## Survival-rhythm question

The wreck is a safe deliberation space: hunger and exposure stop advancing there. Press **E** at the opened wreck to recover exposure deliberately while two seconds of ecological time pass. If exposure reaches its limit in the field, the suit returns the astronaut to the wreck while ten seconds of ecological time pass; the scanner reports changes only to previously observed subjects. Press **J** to pause survival and ecology while reviewing the detailed record.

Exposure remains an exact suit reading. Hunger is qualitative and accelerates exposure by 25% while hungry and 60% while starving, shortening excursions without trapping the astronaut or degrading controls. Drinking spends one shared water dose to recover half an excursion. The final carried dose requires a short hold, and an already-watered refuge rejects repeated spending.

The balance values are deliberately provisional. The playtest asks whether players voluntarily structure their work into excursions, understand the cost of forced recovery, and still feel able to inspect and recover from an ecological mistake.

For the enlarged Crash Basin, exposed accumulation is one quarter of the earlier small-map rate. Hunger reaches one meal threshold over roughly eight displayed field hours, approximating three meals per field day instead of demanding food every short expedition.

## Evidence and replay contract

Issue #10 is represented by an in-memory recorder behind one Godot interface. It is deliberately independent of status text, scanner prose, meshes, and labels. Press **F9** to pause the simulation and inspect the evidence stream; **[ / ]** walks events and displays each selected event's causal chain.

The contract separates three records:

- **Commands** are accepted, state-affecting player intent addressed to stable subjects, timestamped with the integer ecology tick and field time. Movement and observer-only UI actions are excluded; action position is captured as context.
- **Events** use a namespaced taxonomy (`intervention.*`, `ecology.*`, `organism.*`, `environment.*`, and `survival.*`). Every event has a stable sequence ID, subject ID, tick, factual payload, and zero or more cause IDs. A playtest explanation can therefore be compared with an actual causal episode without parsing presentation text.
- **Checkpoints** are versioned full simulation snapshots captured at run start, player interventions, recovery boundaries, and major episode boundaries. Replay begins from a checkpoint, reapplies subsequent commands in sequence, and compares later checkpoints to detect divergence. Checkpoints are not taken for every visual or scanner update.

This prototype keeps the records in memory and exposes a textual observer adapter. Production persistence, file formats, compression, telemetry consent, and a full rewind player remain outside this decision.

## Authoritative animal-simulation seam

`animal_simulation.gd` is a pure-data prototype module for issue #21. Its small interface owns stable-ID registration, queued astronaut interventions, deterministic ticks, factual domain events, versioned full snapshots, and restoration. Species choose intentions behind that seam; the ecological grid accepts common material-transfer operations; presentation nodes are not authoritative.

The integrated proof uses grazers, a predator, an eusocial colony, a flying reproductive vector, and a Wetland Engineer through the same resolution path. Grazers can reproduce by transferring parental biomass into a stable-ID juvenile. An eusocial colony establishes one fixed hive: a slowly advancing worker stream removes small moss or rhizome loads, returns them to the hive as processable plant matter, and recycles that Detritus into nutrients instead of moving the colony itself. The vector carries pollen only between flowering ground-cover and canopy plants, while fungal fruiting bodies use separately named spore dispersal into wet detritus; the engineer converts gathered biomass into dams that retain water while obstructing drainage; and the predator limits grazer pressure while remaining a possible combat threat.

Animal arrival now uses local habitat shape instead of basin-wide milestone counts, fixed destinations, or one shared measure of lushness. The prototype scans bounded neighborhoods for species-specific contrasts: fairly dry Detritus for colonies, separated flowering clusters for reproductive vectors, standing water and plant material along the Drainage Spine for Wetland Engineers, an edge between concentrated open forage and nearby cover for grazers, and living grazer proximity for predators. A uniform lush patch does not qualify every species. An animal is registered at the best qualifying Ecological Cell, so different habitat mosaics produce different arrival locations. Arrival discoveries describe tracks, movement, or settlement without announcing the species' ecological function; the evidence stream retains the provisional habitat score and measurements for observer analysis.

This is the first slice of the colonization question. Animals still choose independently, appear directly at the destination, become permanent residents, and use one-per-species gates. Resident resource claims, attraction or conflict between species, departure after habitat collapse, provisional scouts, visible entry from the basin rim, and resource-supported population size remain separate playable questions.

Habitat search is distributed across deterministic ecology ticks using one frozen ecological snapshot. This preserves whole-basin comparison without placing a full multi-species neighborhood sweep in one rendered frame.

## Integrated succession and First Rain

The grid now carries microbial crust, rooted rhizome mats, canopy-formers, standing water, aquatic producers and consumers, dissolved oxygen, sulfur precursor, volatile sulfur, pollination, and dam material. These roles form a provisional succession rather than an upgrade ladder: pioneers prepare soil, rooted plants stabilize and compete for water, canopy creates shade/litter/vapor, wet cells support a regulated aquatic food web, animals move matter and reproduction between patches, and engineered dams alter drainage.

First Rain is a natural threshold, not a Presence ability. Surface water and canopy contribute vapor; fungal and aquatic sulfur pathways contribute cloud-active material; and a seeded regional pressure/lift window determines whether clouds can precipitate. Three sustained surface-reaching rain ticks mark First Rain. The Presence may visibly attend or warn, but is absent from the weather model's inputs.

## Embodied-toolkit question

The loose shade panel can be carried as the astronaut's one bulky object and placed on any reachable ecological cell. A translucent footprint shows immediate coverage without predicting biological success. Retrieving it removes that shade immediately; forced recovery drops it at the collapse location instead of teleporting it to the wreck.

A robust living moss or rhizome cell can also surrender a finite clump to the same bulky carry frame. Extraction immediately thins the donor; placement transfers that exact living biomass rather than creating a planting token. Hot, dry, or toxic ground stresses the transplant through the ordinary ecological rules, so the initial placement is not proof of establishment. This asks whether source sacrifice and uncertain destination choice create a legible spatial Field Experiment.

The revealed depression is a provisional terrain-bound Reservoir: after it is established, **E** refills one empty canister at a time. If water reaches zero before that Reservoir exists, holding **E** at the wreck dismantles the Wreck Life-Support Reclaimer for one final dose. The wreck stays safe, but voluntary recovery thereafter advances the same longer ecological interval as forced recovery. These fixtures test the accepted toolkit and material-economy boundaries; they do not settle later toolkit progression or the final Reservoir-forming ecology.

## Crash-basin spatial question

The greybox is now one connected, enlarged Crash Basin with five gradient-based Ecological Zones: the northwest Wreck Shelter, nearby sheltered hollow, central dry Drainage Spine, exposed toxic shelf, and downstream recovery pocket. Walking from the wreck to the far pocket takes roughly 26 seconds. Major landmarks are visible at a distance while the fixed orthographic camera keeps local conditions undisclosed until the astronaut travels there.

The Drainage Spine is initially dry. A real water input can produce a temporary deterministic Drainage Pulse: only moisture above local retention moves downhill, carrying a small amount of mobile nutrients. Shade and living cover retain more locally. Press **J** after recovering the scanner to inspect a coarse Basin Survey of visited zones and last-observed equipment; it pauses time, explicitly marks stale evidence, and supplies no route or objective.

All landform blocks, labels, colors, route spacing, and transport rates are throwaway fixtures. The playtest asks whether landmark navigation, paired-site comparison, route choice, cross-zone equipment movement, and ecological transfer make the basin feel like one causal place.

## Regression check

The captured idle-opening failure can be replayed headlessly:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/idle_then_water_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/grazer_motion_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/grazer_metabolism_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/ecological_feedback_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/evidence_recorder_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/toolkit_economy_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/crash_basin_spatial_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/survival_pacing_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/rewater_after_disturbance_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/animal_simulation_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/integrated_succession_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/ecological_roles_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/habitat_colonization_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/colony_hive_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/habitat_arrival_performance_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/procedural_weather_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/playable_progression_test.gd
```

The checks verify the opening, movement, grazer behavior, scanner evidence, replay record, toolkit economy, basin traversal, survival pacing, disturbance recovery, shared animal authority, habitat-driven arrival, fixed-hive worker transport, and the bounded arrival-search frame cost established by earlier revisions. Integrated checks additionally verify rooted/canopy/aquatic succession, sulfur processing, reproduction without spontaneous biomass, distinct colony/vector/engineer effects, seeded weather that produces ecological disturbances plus ecosystem-enabled First Rain without a fixed schedule or Presence trigger, and an end-to-end route from ordinary finite watering through Reservoir refills to every ecological milestone.
