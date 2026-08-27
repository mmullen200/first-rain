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
- **F** — scan a nearby moss patch
- **C** — send a suit-light signal toward a nearby ecological subject
- **J** — open or close the detailed field record and pause simulation time
- **V** — toggle the scanner's nearby moisture/toxicity analysis lens
- **Space** — spend one water dose on a nearby moss patch
- **Q** — spend one water dose on the astronaut when exposure is meaningful
- **Z** — eat carried fresh food first, otherwise a finite ration
- **R** — restart the experiment

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
- A simple agent-based grazer awakens when moss, fungus, and fruiting biomass cross thresholds. Its luminous teal body, amber head, and world label distinguish it from its dormant stone-like shell. When hungry it slowly follows the strongest viable moss signal, takes one bite, then roams smoothly while digesting. It deposits manure in a different ecological cell, moving dead biomass and nutrients away from the feeding site before hunger sends it seeking again.
- Grazer awakening starts a warning for a moving heat-and-dust front. The front dries cells, raises heat and toxicity, and converts damaged moss to dead biomass; established living cover reduces the damage.
- During the warning, the Presence moves from the ridge to a bare depression and exposes a subsurface-moisture signal. This is a directional nudge, not an instruction: the player can scan, ignore, or spend water there.

All thresholds, meters, timings, yields, and weather damage values are accelerated prototype fixtures rather than balance decisions.

The ecological grid remains dormant until the astronaut commits the first water dose. Time spent inspecting the crash or leaving the prototype open therefore cannot silently dry the starting conditions before the first Field Experiment.

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

## Regression check

The captured idle-opening failure can be replayed headlessly:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/idle_then_water_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/grazer_motion_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/grazer_metabolism_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/ecological_feedback_test.gd
```

The checks verify that an idle opening cannot pre-age the dormant ecology, that the grazer moves visibly without frame-sized jumps, that it exposes a complete seek–digest–roam–manure cycle, and that the scanner preserves bounded baseline, comparison, rescan, pulse, and local-lens feedback.
