# Godot ecology rules lab

This throwaway lab answers one question for issue #3:

> Can moss, fungus, and one grazer form a legible nutrient cycle that persists, moves material through space, and responds to disturbance without scripted progression?

It intentionally replaces the first-interaction prototype's authored milestones with a small material-flow model:

- mineral nutrients become moss when water permits growth;
- moss and fungus turnover become detritus;
- fungus decomposes detritus into fungal biomass and reusable minerals;
- a hungry grazer moves moss into its gut, roams while digesting, then deposits the same nutrients elsewhere as manure;
- water and independent dry pulses change conditions but do not create or delete tracked nutrients.

The right panel exposes every aggregate stock, the transfers during the latest tick, cumulative manure deposits, the most recent deposit, and unexplained nutrient drift. Gold rings remain on deposit cells long enough to inspect before fading; they are visual evidence, not an additional nutrient stock. A green zero-drift readout is the model's conservation check.

## Run

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path prototypes/godot-ecology-lab
```

## Controls

- Click the basin to apply the selected intervention.
- `1`: water
- `2`: local dry pulse
- `Space`: pause/run
- `-` / `+`: simulation speed
- `O`: cycle combined, water, mineral, and detritus overlays
- `R`: reset to the dormant start
- `E`: load an established cycle for stress testing

## Deliberate omissions

Fruit, hunger survival, the Presence, authored discoveries, and polished 2.5D visuals are excluded. They would obscure whether the ecological kernel itself works. If this rule set proves understandable and interesting, later slices can treat edible fruit as an output of the system rather than as a scripted unlock.
