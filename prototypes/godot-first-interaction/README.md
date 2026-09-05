# First Rain: opening vertical-slice prototype

Throwaway Godot vertical slice for deciding whether the opening teaches movement, finite supplies, scientific observation, ecological intervention, recovery, cultivation, and the first sighting of the Presence through embodied play. The current branch asks whether sustained local Habitat Support makes animal arrivals, departures, and returns read as reversible ecology rather than a basin-wide progression tree, while the standing-water sulfur pathway remains a distinct requirement for First Rain.

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
- **G** — excavate the Ecological Cell under the astronaut, persistently lowering its drainage height
- **F** — scan a nearby moss patch
- **C** — send a suit-light signal toward a nearby ecological subject
- **J** — open or close the pause-only Basin Survey and detailed field record
- **V** — cycle the scanner lens through off, nearby moisture/toxicity, and elevation/downhill flow
- **Space** — spend one water dose on a nearby moss patch
- **Q** — spend one water dose on the astronaut when exposure is meaningful
- **Z** — eat carried fresh food first, otherwise a finite ration
- **R** — restart the experiment
- **F9** — open or close the observer-only evidence debugger; **[ / ]** selects an earlier or later causal event

## Question under test

Can the player explain at least one animal arrival and one later departure from visible local habitat change without describing species as permanently unlocked stages, while also recognizing that aquatic producers plus consumers—not terrestrial greening alone—supply the volatile sulfur contribution required for First Rain?

Moss behavior, water quantities, environmental variables, timing, and the loose shade panel are disposable test fixtures. The current intervention response deliberately holds long enough to read: the Field Scanner reports rising local moisture and a responding dormant-life trace while explicitly withholding confirmation of living moss. They do not settle the later rule-set, survival-balance, feedback-tool, or toolkit decisions.

## Cellular ecology added for this revision

The visible square cells now carry provisional moisture, temperature, toxicity, nutrients, dormant moss, living moss, dead biomass, fungus, and shade values. A fixed deterministic tick updates all cells through double-buffered local rules:

- Water wakes dormant moss where temperature and toxicity permit.
- Living moss spreads into adjacent suitable cells and slows evaporation.
- Moss stress and ordinary turnover create dead biomass.
- Fungus awakens where dead biomass remains wet, spreads locally, decomposes it into nutrients, and slightly reduces toxicity.

Each Ecological Cell is a shadow-casting block whose height carries terrain shape while color remains available for living state: blue-green indicates moisture, green living moss, brown Detritus, violet fungus, and gold edible fruiting bodies. Canopy and standing water use separate geometry above the ground. The damaged Field Scanner supplements those cues with coarse local bands and a nearby elevation/downhill-flow mode; ordinary play does not show system-wide cell counts.

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

The integrated proof uses grazers, a predator, a eusocial colony, a flying reproductive vector, and a Wetland Engineer through the same resolution path. Grazers can reproduce by transferring parental biomass into a stable-ID juvenile. A Eusocial Colony establishes one fixed nest. Twenty-four individually simulated workers explore with persistent random headings, sense only adjacent food and local scent, and carry small moss or Rooted Mat loads home along remembered routes. Successful return trips reinforce a decaying colony-specific pheromone field; other workers preferentially follow marked paths, while four scouts continue exploring. Exhausted sources stop reinforcing their trails. Returned plant matter enters the nest’s Detritus cycle and is recycled into nutrients. The vector carries pollen only between flowering ground-cover and canopy plants, while fungal fruiting bodies use separately named spore dispersal into wet detritus; the engineer converts gathered biomass into dams that retain water while obstructing drainage; and the predator limits grazer pressure while remaining a possible combat threat.

Animal settlement uses local habitat shape instead of fixed destinations, a shared measure of lushness, or a progression checklist. Every role independently scans bounded neighborhoods for current support: fairly dry Detritus for colonies, separated ground-flowering clusters for reproductive vectors, an edge between concentrated open forage and living canopy cover for grazers, flowing water with nearby aquatic consumers and plant material for Wetland Engineers, and a local range shared by multiple grazers for predators. A uniform lush patch does not qualify every species, and canopy or aquatic life elsewhere in the basin cannot satisfy a distant animal.

Qualifying habitat must persist across repeated observations before settlement, with slower persistence requirements for animals whose arrival should carry more weight. A colony needs about forty-four seconds of uninterrupted candidate habitat in the current accelerated fixture. After roughly eleven seconds, isolated scouts begin entering from the nearest basin edge; sustained traffic later disturbs the candidate ground; only then does the fixed anthill appear. If conditions fail during prospecting, the scout trail fades and no nest remains. This is observable ecological anticipation, not a countdown or basin-wide unlock.

Each resident remains associated with its local range; mobile foraging is bounded around it. If support stays below the same habitat threshold through a grace period, the animal leaves for the Regional Ecology without dying. Recovery can support its later return. The fixed Eusocial Colony hive follows the same rule while present: the nest stays in one place while workers forage. Sustained habitat loss recalls all workers, stops new gathering and waits for their loads to return before withdrawal. Renewed support cancels recall.

This remains a provisional colonization slice using a small fixed roster. Colony scouts now visibly enter from the basin rim before settlement; other animals still appear directly at a selected destination. Resident attraction or conflict and fully resource-supported population size remain separate playable questions.

Habitat search is distributed across deterministic ecology ticks using one frozen ecological snapshot. This preserves whole-basin comparison without placing a full multi-species neighborhood sweep in one rendered frame.

## Integrated succession and First Rain

The grid now carries microbial crust, rooted rhizome mats, canopy-formers, standing water, aquatic producers and consumers, dissolved oxygen, sulfur precursor, volatile sulfur, pollination, and dam material. These roles form a provisional Succession rather than an upgrade ladder. Microbial crust occupies a narrow damp band and becomes water-repellent when dense and dry; moss retains water and sheds Detritus; fungus requires that Detritus, recycles nutrients, and detoxifies; rooted mats require moss, crust, and nutrients, then compete for water; ground flowering offers a reproductive opportunity; vector pollination enables rooted spread and canopy awakening; and canopy creates shade, litter, cover, and vapor.

The standing-water path runs alongside that terrestrial sequence. Aquatic producers create sulfur precursor; aquatic consumers graze the bloom, alter dissolved oxygen, and process the precursor into volatile sulfur. Weather may use fungal particles and terrestrial vapor, but surface-reaching First Rain now also requires the aquatic sulfur link. A restored dry landscape cannot complete that pathway.

First Rain is a natural threshold, not a Presence ability. Surface water and canopy contribute vapor; fungal particles and aquatic sulfur contribute cloud-active material; and a seeded regional pressure/lift window determines whether clouds can precipitate. Three sustained surface-reaching rain ticks mark First Rain. The Presence may visibly attend or warn, but is absent from the weather model's inputs.

## Embodied-toolkit question

The loose shade panel can be carried as the astronaut's one bulky object and placed on any reachable ecological cell. A translucent footprint shows immediate coverage without predicting biological success. Retrieving it removes that shade immediately; forced recovery drops it at the collapse location instead of teleporting it to the wreck.

A robust living moss or rhizome cell can also surrender a finite clump to the same bulky carry frame. Extraction immediately thins the donor; placement transfers that exact living biomass rather than creating a planting token. Hot, dry, or toxic ground stresses the transplant through the ordinary ecological rules, so the initial placement is not proof of establishment. This asks whether source sacrifice and uncertain destination choice create a legible spatial Field Experiment.

The revealed depression is a provisional terrain-bound Reservoir: after it is established, **E** refills one empty canister at a time. If water reaches zero before that Reservoir exists, holding **E** at the wreck dismantles the Wreck Life-Support Reclaimer for one final dose. The wreck stays safe, but voluntary recovery thereafter advances the same longer ecological interval as forced recovery. These fixtures test the accepted toolkit and material-economy boundaries; they do not settle later toolkit progression or the final Reservoir-forming ecology.

## Crash-basin spatial question

The greybox is now one connected, enlarged Crash Basin with five gradient-based Ecological Zones: the northwest Wreck Shelter, nearby sheltered hollow, central dry Drainage Spine, exposed toxic shelf, and downstream recovery pocket. Walking from the wreck to the far pocket takes roughly 26 seconds. Major landmarks are visible at a distance while the fixed orthographic camera keeps local conditions undisclosed until the astronaut travels there.

The Drainage Spine is initially dry. A real water input can produce a temporary deterministic Drainage Pulse: only moisture above local retention moves downhill, carrying a small amount of mobile nutrients. Shade and living cover retain more locally. Press **J** after recovering the scanner to inspect a coarse Basin Survey of visited zones and last-observed equipment; it pauses time, explicitly marks stale evidence, and supplies no route or objective.

All landform blocks, labels, colors, route spacing, and transport rates are throwaway fixtures. The playtest asks whether landmark navigation, paired-site comparison, route choice, cross-zone equipment movement, and ecological transfer make the basin feel like one causal place.

## Colony foraging question (#29)

Branch: `prototype/colony-pheromone-foraging`. Can the player recognize scattered exploration becoming a recruited food route, then dispersing after that source is depleted?

The normal opening includes the new worker simulation. To start beside an already established nest and two separated living patches in the same Crash Basin:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path prototypes/godot-first-interaction -- --colony-foraging
```

This optional starting fixture seeds finite plants and dry Detritus once and gives the Astronaut the opened cache and Field Scanner. Ordinary ecology, weather, survival, habitat departure and toolkit controls continue running. **R** restarts the same fixture. Use **WASD** to observe from nearby, **T** to move a robust clump, **Space** to water, and **J** to pause. Carriers show green plant fragments; every visible worker corresponds to authoritative worker state. There is no ordinary-play scent overlay or assigned food target. Pre-settlement scouts remain the existing anticipation visual; this experiment concerns established-colony workers.

Worker count, six-cell range, three-tick movement cadence, load size and scent decay are disposable. The field decays on each fixed tick without diffusion; return paths erase loops, and a minority of scouts ignore scent. Workers sense a shared beginning-of-tick scent field, then collect finite food in stable order. Worker identities, route memory, cargo and scent are included in animal snapshot version 2. Prior version-1 animal snapshots are rejected. F9 events record worker-specific gathering, recruitment and delivery.

**Playtest gate:** without an observer overlay, the player identifies discovery, increased traffic to a food patch, and dispersal after food loss from the workers and carried fragments. Plant growth and weather can also change food availability in the living fixture; headless controlled-food checks isolate pheromone behavior. Automated verification is implemented evidence; human comprehension and fun remain unvalidated.

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
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/colony_pheromone_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/habitat_arrival_performance_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/procedural_weather_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/playable_progression_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/topographic_hydrology_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/topographic_presentation_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/topography_regression_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/succession_order_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/reversible_animal_residency_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/animal_arrival_pacing_test.gd
```

The checks verify the opening, movement, grazer behavior, scanner evidence, replay record, toolkit economy, basin traversal, survival pacing, disturbance recovery, shared animal authority, fixed-hive worker transport, and the bounded habitat-search frame cost. Habitat checks demonstrate that roles settle independently from sustained local support, distant basin-wide counts cannot qualify them, brief fluctuations do not cause settlement or departure, sustained collapse causes departure without death, and habitat recovery permits return. The pacing check verifies that watering produces an immediate held local reading, colony scouts precede any anthill by tens of seconds, later traffic visibly disturbs the site, and habitat loss cancels prospecting without leaving a nest. Integrated checks additionally verify Detritus-dependent fungus, separate pioneer requirements for rooted mats, pollination-gated canopy, the producer/consumer sulfur pathway, reproduction without spontaneous biomass, distinct colony/vector/engineer effects, seeded weather that produces ecological disturbances plus ecosystem-enabled First Rain without a fixed schedule or Presence trigger, and an end-to-end route from finite watering and transplantation through every terrestrial and aquatic role.
