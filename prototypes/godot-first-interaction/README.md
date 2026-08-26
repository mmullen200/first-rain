# First Rain: opening vertical-slice prototype

Throwaway Godot vertical slice for deciding whether the opening teaches movement, finite supplies, scientific observation, ecological intervention, recovery, cultivation, and the first sighting of the Presence through embodied play.

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

Cell color is the readable prototype overlay: blue-green indicates moisture, green living moss, brown dead biomass, violet fungus, and gold edible fruiting bodies. The Field Scanner exposes the precise local values while the top-left summary shows the system-wide cell counts.

## Expanded ecological arc

- Wet, nutrient-rich fungus produces harvestable fruiting bodies. Harvest removes some fungus and nutrients, so repeated harvesting can damage the food source.
- Hunger creates a provisional survival reason to replace finite rations with renewable food.
- A simple agent-based grazer awakens when moss, fungus, and fruiting biomass cross thresholds. Its luminous teal body, amber head, and world label distinguish it from its dormant stone-like shell. It follows the strongest viable moss signal one neighboring cell at a time, consumes moss, and returns some nutrients and dead biomass to the cells.
- Grazer awakening starts a warning for a moving heat-and-dust front. The front dries cells, raises heat and toxicity, and converts damaged moss to dead biomass; established living cover reduces the damage.
- During the warning, the Presence moves from the ridge to a bare depression and exposes a subsurface-moisture signal. This is a directional nudge, not an instruction: the player can scan, ignore, or spend water there.

All thresholds, meters, timings, yields, and weather damage values are accelerated prototype fixtures rather than balance decisions.

The ecological grid remains dormant until the astronaut commits the first water dose. Time spent inspecting the crash or leaving the prototype open therefore cannot silently dry the starting conditions before the first Field Experiment.

## Regression check

The captured idle-opening failure can be replayed headlessly:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/idle_then_water_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/godot-first-interaction --script res://tests/grazer_motion_test.gd
```

The checks verify that an idle opening cannot pre-age the dormant ecology and that an awakened grazer visibly travels toward viable moss.
