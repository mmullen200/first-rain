# First Rain

First Rain is a 2.5D ecological survival game about a stranded astronaut restoring a dormant alien ecology and learning to communicate with the living planet that hosts it.

The astronaut cannot survive indefinitely on supplies recovered from the wreck. To endure, they must explore the Crash Basin, observe its damaged ecological relationships, and help establish self-sustaining cycles of water, nutrients, plants, fungi, and animals. The long arc is not about terraforming the planet into something familiar. It is about understanding an unfamiliar living system well enough to participate in its recovery.

## What the player does

First Rain is built around field experiments rather than quests or recipes. The player notices a condition, inspects it with a damaged Field Scanner, forms a hypothesis, intervenes physically, and watches the ecosystem respond over time.

Those interventions are deliberately situated and limited. Water poured into one patch is water no longer available elsewhere. Moving shade, transplanting living material, redirecting drainage, relocating nutrients, sowing spores or seed, clearing overgrowth, and caring for animals all change local opportunities without guaranteeing success. A useful action in a sheltered hollow may fail on hot, dry, or toxic ground. Ecological management includes subtraction and disruption as well as cultivation.

Survival gives those experiments consequence. The wreck provides temporary shelter, finite bootstrap supplies, and damaged support systems that slowly lose reliability. Hunger and exposure create an expedition rhythm: prepare, enter the basin, observe and act, then return before the field becomes lethal. Recovery remains possible after mistakes, but time passes, technology deteriorates, and the ecology continues changing.

The clock is deliberately slow and legible. Wreck services and imported equipment fail in stages rather than disappearing in one surprise catastrophe. Each failing dependency gives the player time to recognize what it provides and establish an ecological replacement: renewable food instead of rations, retained and accessible water instead of canisters, living shelter instead of powered protection, and eventually local knowledge and cooperation instead of total dependence on damaged instruments. Maintenance or salvage may buy time and force trade-offs, but off-world technology cannot sustain the astronaut forever.

## A living, changing basin

The Crash Basin is one connected landscape rather than a set of isolated levels. Water, nutrients, organisms, and disturbances move through its Drainage Spine. Different Ecological Zones form a mosaic of pioneer, established, disturbed, and recovering habitat, and local succession can advance, stall, or reverse.

Organisms matter because of the roles they perform. Moss retains water; fungi return detritus to the nutrient cycle; rooted and canopy plants stabilize and reshape habitat; grazers move biomass; predators regulate grazing pressure; reproductive vectors connect distant patches; colonies redistribute material; and Wetland Engineers alter drainage by building dams. Animals remain autonomous even when the astronaut develops habituation, trust, or husbandry practices around them.

Weather is part of the same system. First Rain—the event for which the project is named—is the first sustained, surface-reaching rainfall to measurably change the basin. It can occur only when a recovering ecosystem's water cycling and biological contributions to the atmosphere coincide with a favorable natural weather window. It is neither a scripted reward nor an ability granted by the planet.

## The Presence

The Presence is a localized, non-corporeal manifestation of the living planet and an alien co-investigator, not a quest giver or weather trigger. It communicates through attention, movement, and a small nonverbal signal vocabulary. As mutual comprehension and trust develop, the astronaut and Presence can notice, question, and build upon one another's ecological interventions without either becoming the other's commander.

The planet's broader awakening follows ecological recovery: a more diverse and resilient ecosystem gives the living world greater capacity to perceive, respond, and act.

## Design principles

- **Understanding before instruction.** World cues, local measurements, comparison, and consequences should let players discover relationships without an omniscient interface or prescribed solution.
- **Finite matter, systemic renewal.** Early wreck supplies run out. Durable progress comes from restoring cycles that retain and redistribute existing water and nutrients rather than generating resources from nothing.
- **Technology as a bridge.** The wreck and the Astronaut's imported equipment create a grace period, not a permanent base. Their staged, observable decline makes ecological independence increasingly necessary without imposing a hidden death timer.
- **Ecology, not an upgrade ladder.** Succession is overlapping and reversible. A healthy region contains different habitats and stages at once.
- **Embodied intervention.** The astronaut carries, places, digs, gathers, feeds, and clears in the world. Tools create spatial decisions instead of abstract management commands.
- **Autonomous life.** Organisms pursue their own needs and reshape the habitat through reusable rules. Care can make relationships more predictable, but it does not turn animals into units.
- **Recoverable consequences.** Mistakes should matter, propagate, and teach without routinely ending the run before the player can understand them.

## Current development

First Rain is in an early prototyping phase in Godot. The current playable work is a deliberately throwaway vertical slice used to test the opening survival rhythm, ecological observation and intervention, a connected Crash Basin, succession, autonomous animal roles, procedural weather, the Presence's communication, and the conditions leading to First Rain.

Automated regressions establish that prototype systems behave consistently; they do not prove that the experience is understandable or enjoyable. Player-facing design questions remain open until their explicit playtest gates are met. Prototype quantities, timings, thresholds, visuals, and one-off fixtures are evidence for decisions rather than final production content.

The canonical project vocabulary lives in [`CONTEXT.md`](CONTEXT.md). Planning questions, prototype results, and decisions are tracked in the [GitHub issue map](https://github.com/mmullen200/first-rain/issues/1). Experimental playable work lives on dedicated `prototype/*` branches so validated concepts can be captured on `main` without treating provisional implementation as permanent architecture.
