# Godot ecology rules lab

This throwaway lab answers one question for issue #3:

> Can moss, fungus, and one grazer form a legible nutrient cycle that persists, moves material through space, and responds to disturbance without scripted progression?

It intentionally replaces the first-interaction prototype's authored milestones with a small material-flow model:

- mineral nutrients become moss when water permits growth;
- moss and fungus turnover become detritus;
- fungus decomposes detritus into fungal biomass and reusable minerals;
- a hungry grazer moves moss into its gut, roams while digesting, then deposits the same nutrients elsewhere as manure;
- water and independent dry pulses change conditions but do not create or delete tracked nutrients.

The right panel exposes every aggregate stock, transfers accumulated across the last 50 ticks, cumulative manure deposits, the most recent deposit, and unexplained nutrient drift. Separate graphs show living biomass and the share of nutrients held in minerals versus detritus. Gold rings remain on deposit cells long enough to inspect before fading; they are visual evidence, not an additional nutrient stock. A green zero-drift readout is the model's conservation check.

The three scenarios have different persistence targets:

- **Dormant oasis:** one finite watering can wake a temporary ecology, but it eventually dries unless water returns.
- **Established seep:** a durable subsurface water supply tests whether the biological nutrient cycle can persist and recover without consuming wreck supplies.
- **Equal-water retention test:** bare soil and established moss receive the same finite watering. The moss should remain observably wetter after one in-world day while both patches remain temporary.

One simulation tick represents one in-world minute. All scenario buttons start paused at `1×` so their initial state can be inspected before time advances. The retention test begins in the water view and excludes the grazer so grazing cannot confound the comparison.

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
- `3`–`6`: directly select combined, water, mineral, or detritus view (`O` also cycles them)
- `R`: reset to the temporary dormant oasis
- `E`: load the established subsurface-seep cycle for stress testing
- `C`: load the equal-water bare-soil/moss retention comparison

## Deliberate omissions

Fruit, hunger survival, the Presence, authored discoveries, and polished 2.5D visuals are excluded. They would obscure whether the ecological kernel itself works. If this rule set proves understandable and interesting, later slices can treat edible fruit as an output of the system rather than as a scripted unlock.
