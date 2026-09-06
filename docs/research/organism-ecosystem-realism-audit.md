# Organism behavior and ecosystem realism audit

Research date: 2026-09-06. Tracking: [#30](https://github.com/mmullen200/first-rain/issues/30). Implementation baseline: [`448c825`](https://github.com/mmullen200/first-rain/commit/448c825), preserved on `prototype/colony-pheromone-foraging`. Research capture branch: `research/ecosystem-realism`.

This is an implementation audit and research proposal. No gameplay or canonical definitions were changed. Earth studies support the mechanisms cited below; the proposed alien traits, relative timings and interactions remain design choices. Automated probes establish specific current behavior, not player comprehension or fun.

## Recommendation

Deepen the existing organisms before adding more species. Give each organism a source of energy and materials, a way to sense its surroundings, a reproductive strategy, and limits that make its effects conditional. A grazer should eat to sustain itself; its movement and digestion then redistribute nutrients. A Flying Reproductive Vector should seek floral food; compatible pollen transfer follows from its visits. A Wetland Engineer should maintain usable aquatic refuge; its construction then reshapes other organisms' habitat.

The largest corrections are shared resource accounting, compatible plant reproduction, animal metabolism and perception, and water-driven engineering. The current model already has valuable foundations: deterministic local cells, stable animal identities, finite animal transfer operations, reversibility of residency, persistent terrain, and independent weather. Keep those. The older ecology lab also contains a more explicit nutrient ledger worth carrying forward conceptually.

Three canonical relationships need a future design revision if closer Earth ecology is the objective: pollination enabling rhizome spread, Ground Flowering enabling dormant Canopy-Former awakening through a common pollen field, and aquatic sulfur being indispensable to rainfall. This report recommends alternatives; it does not silently replace those accepted prototype decisions.

## What was reviewed and verified

- `CONTEXT.md`, root README, the Wayfinder map, both prototype READMEs, and the previous [rainfall research](ecosystem-driven-rainfall.md).
- [`ecology_grid.gd`](../../prototypes/godot-first-interaction/ecology_grid.gd): producers, fungi, reproduction fields, resource transfers, standing water and drainage.
- [`animal_simulation.gd`](../../prototypes/godot-first-interaction/animal_simulation.gd): all five registered animal roles, movement, feeding, reproduction and residency state.
- [`main.gd`](../../prototypes/godot-first-interaction/main.gd): habitat selection, arrivals/departures, ecological discovery text and integration.
- [`weather_simulation.gd`](../../prototypes/godot-first-interaction/weather_simulation.gd): vapor, biological particles and First Rain.
- [`ecology_lab.gd`](../../prototypes/godot-ecology-lab/ecology_lab.gd): historical nutrient-cycle evidence.

A temporary Godot 4.6.2 headless probe exercised individual decision/transfer functions at the baseline. It confirmed:

| Probe | Observed result | What this establishes |
|---|---|---|
| Vector on a flowering cell | `collect_pollen → pollinate`, same cell `(10,8)`, about `0.08` added pollination | The current function permits a reproductive event without connecting patches |
| Engineer after gathering Detritus | Next intention deposits `dam_material` at the gathering cell | Material availability selects this build location; no separate hydraulic site choice intervenes |
| Grazer consume then deposit | Body biomass remains `1.0`; eaten material is offered as Detritus | This transfer route does not assimilate food into growth |
| Equal canopy with different soil-moisture inputs | Identical weather humidity `0.18815320816835` | Weather's canopy vapor input does not respond to supplied soil moisture |

These are targeted probes, not a new full regression run or a natural end-to-end playtest. No gameplay files changed, so the README regression suite and a fresh playable launch were not required. Temporary probes remain outside commits.

## Shared ecological foundations

### Track resources with explicit meanings

The integrated grid mostly uses normalized state fields. Some transfers are conserved, but that does not make the whole ecosystem a material budget. In `ecology_grid.step()`, crust adds nutrients each tick without an explicit external source; canopy growth and flowering have no corresponding mineral debit; fruiting increases without an explicit allocation from fungal stores; and several losses disappear through decay or clipping. `pond_gain` increases standing water without debiting soil water. Weather derives vapor from standing canopy and water stocks rather than measured outgoing water fluxes.

Choose one limiting mineral currency initially, and track its fractions in plants, fungal tissue, animal bodies and guts, propagules, Detritus and dissolved minerals. Record imports and exports from the Regional Ecology. Route excess into an appropriate pool or outflow instead of silently clipping it. If crust fixes atmospheric nitrogen, name that external input and condition it on metabolic activity; it cannot stand for creating arbitrary minerals such as phosphorus.

Do not equate all biomass with minerals. Photosynthetic carbon enters from atmospheric carbon dioxide; respiration returns carbon, while energy dissipates. A simple model can keep carbon implicit through a productivity budget and still conserve its selected mineral currency. Likewise, metabolic energy loss must not delete tracked mineral matter. The old lab's one-currency accounting is a useful starting abstraction, not a complete carbon budget.

Give water actual stores: surface water, shallow soil and a small deeper/subsurface pool. Infiltration, drainage, uptake and evaporation transfer or export water. Let shade and soil structure alter rates and capacities. Feed weather the resulting vapor flux, with explicit regional humidity exchange. A living canopy cannot supply the same transpiration indefinitely after its accessible water is exhausted.

### Separate response times and life stages

Use fast movement and perception, intermediate feeding and recovery, and slower growth and reproduction. Preserve readable compressed time without making an insect's stride, a digestion cycle and a tree's maturation advance at equivalent rates. Distance-scale diagonal travel for the other mobile animals, as already done for workers. Body size alone does not determine a biologically correct speed; locomotion, temperature, terrain and behavior matter, and the game has no calibrated real-world length/time scale yet.

For animals, the minimum useful shared state is age/stage, energy reserve, body nutrient stock, gut contents, current need and recent local observations. Add a small juvenile/adult distinction and resource-supported growth. The present generic reproduction function transfers parental biomass, but juveniles lack a maturation route and eaten food does not replenish grazer body biomass. That prevents a convincing repeated population cycle even though a single birth can be demonstrated.

For populations, retain reversible Habitat Support but introduce gradual loss of condition and actual outward travel. Current non-colony arrivals select destinations directly, and absent animals stop local updating. An explicit coarse regional population/reserve model can handle migration without simulating every off-screen individual. Habitat suitability should influence settlement and survival, not guarantee a fixed roster forever.

## Producers and decomposers

### Microbial Crust

**Current:** a damp-band growth response, some canopy suppression, constant nutrient addition and an imposed water penalty for dense crust. The comment describes dry repellency, but the `crust_repellency` calculation depends on crust abundance rather than current dryness. Physical stabilization is more a stated role than a sediment/erosion process.

**Evidence:** biocrust wetting experiments found rapid resuscitation alongside limited productivity; surviving a pulse and producing substantial new biomass are distinct. [Primary study, 2024](https://www.nature.com/articles/s41467-024-46920-6). Measurements of biocrust nitrogen transformations also show a water-dependent microbial process, not a fixed fertility reward. [Primary study, 2021](https://www.nature.com/articles/s41396-021-01127-1).

**Proposal:** distinguish active fraction from persistent living structure. Adequate wetting enables metabolism, while dry crust remains structurally present. Couple erosion resistance and infiltration to coverage, wetness and a chosen substrate type. Treat nutrient input as a named process or mineral redistribution. Do not assign every crust the same nitrogen-fixing ability.

**Interaction to observe:** crust protects a slope but redirects some intense runoff to a neighboring depression. Damage opens colonization sites while increasing sediment movement. This gives crust both persistence benefits and habitat-specific costs.

### Moss analogue

**Current:** water wakes a seeded dormant stock; living moss spreads, retains moisture and becomes Detritus under drought/heat/toxicity. Dry living tissue mainly decays rather than entering a reversible inactive state. Nutrients affect growth but do not strictly limit every source of new moss.

**Evidence:** experimental desiccation of *Polytrichum formosum* distinguished rapid physiological reactivation from slower full recovery, with recovery depending on drying history. This supports a desiccation-tolerant analogue, not identical tolerance in all mosses. [Proctor et al.](https://pmc.ncbi.nlm.nih.gov/articles/PMC3243588/).

**Proposal:** active → dry/inactive → recovering, with accumulated damage causing actual death. Track finite water held in the mat; retention changes drying rate rather than creating water. Limit expansion by propagules or connected growth and resource uptake. Let prolonged shade or burial impose costs.

**Interaction to observe:** a brown patch can recover after adequate rewetting, while a dead patch requires recolonization. Moss creates a moist fungal refuge, but grazers removing it also remove part of that moisture buffer.

### Rooted Mat

**Current:** awakening requires both moss and crust; neighbor spread is multiplied by the shared `pollination` field. It consumes shallow water and some nutrients and suffers a canopy penalty, but lacks separate roots, leaves, reserves, seeds and plant identity.

**Evidence:** intact versus severed rhizome experiments show that connected clonal plants can share resources across heterogeneous patches. This is physical connection within a clone, distinct from pollen transfer. [*Iris japonica* experiment](https://pmc.ncbi.nlm.nih.gov/articles/PMC5069692/). Experiments across grasslands show that nutrient enrichment can intensify light competition and that herbivory can counter it; neither fertilizer nor grazing has a universally positive effect. [Borer et al., 2014](https://www.nature.com/articles/nature13144).

**Proposal:** separate local clonal extension from sexual reproduction. Rhizome extension spends reserves and uses connected viable substrate; pollination instead influences seed production. Use a clone/patch identity and short-range resource transfer if the connection matters to play. Root reserves support regrowth after one bite, but repeated defoliation can exhaust them. Flowering requires maturity, resources and light.

Replace mandatory live predecessor checks with substrate properties wherever possible. Moss/crust can prepare moisture and stable ground that remains useful after their living cover changes. Suitable sediment from another source could provide an alternative establishment route.

**Interaction to observe:** a mat extends beside a wet parent without vector visits, while establishing a separated patch requires a viable seed or transplanted clump. Grazing temporarily reduces flowers and vector visits, yet a small opening may help a shaded neighbor.

### Canopy-Former

**Current:** common pollination enables dormant canopy awakening; standing canopy adds shade, litter and weather vapor. The simulation has no distinct deep-water store, no canopy mineral debit during growth, and limited stress mechanisms. Thus the scanner's deep-rooted description exceeds the modeled physiology.

**Evidence:** manipulated seedling communities show water competition can vary with neighbor identity. [O’Brien et al., 2017](https://www.nature.com/articles/s41559-017-0326-0). Facilitation experiments show a neighbor's benefit changes with stress and density. [Zhang & Tielbörger, 2020](https://www.nature.com/articles/s41467-020-16286-6). These support conditional competition/facilitation, not an automatic diversity bonus.

**Proposal:** seed/propagule → seedling → established canopy → reproduction → senescence. Existing viable dormant seeds germinate under suitable conditions; they do not need a new pollen delivery. Mature canopy needs compatible canopy pollen if that is its chosen reproductive strategy. Ground flowers can support the vector population that later services canopy flowers, but cannot fertilize a different plant species.

Use a shallow/deep uptake distinction, actual water-limited transpiration, and light competition beneath the crown. Allocate reserves to growth, litter and reproduction. Add drought damage, prolonged root inundation and fallen structural Detritus. Keep deep-root access conditional on actual reachable water.

**Interaction to observe:** canopy shelters a fungal food patch during heat but suppresses nearby Ground Flowering; a dense stand competes for water. A fallen plant opens light and slowly feeds decomposers, allowing a different local trajectory.

### Fungus and associated decomposers

**Current:** wet Detritus can awaken fungus without a required inoculum, fungal activity releases nutrients and lowers generic toxicity, and fruiting grows as a moisture/fungus/nutrient function. Fungal and fruiting losses are not consistently returned to Detritus. Harvest always removes some mycelial biomass and minerals in addition to fruiting.

**Evidence:** a ten-year, 21-site litter experiment found nitrogen release depended on initial litter nitrogen and remaining mass, with differences between leaf and root litter. [Parton et al., 2007](https://pubmed.ncbi.nlm.nih.gov/17234944/). This supports substrate-dependent mineralization rather than treating every dead object as equivalent instant fertilizer.

**Proposal:** maintain decomposer tissue separately from temporary fruiting bodies. Consume finite substrate, temporarily retain part of its nutrients, and release the rest according to substrate quality. Begin with soft Detritus/dung and slow structural litter. Spores or surviving local mycelium establish new fungal patches; fruiting spends reserves and supplies finite spores. Harvesting a fruiting body need not always injure the underlying network—make damage depend on the intervention.

Specify what toxicity represents before adding detoxification chemistry. If the fiction chooses an organic compound that can be degraded, model a transformation. If it chooses a metal-like pollutant, binding it changes bioavailability but does not destroy the element. A symbiotic root fungus is a possible later distinct role; avoid giving one generic fungus every decomposition, detoxification and mutualism benefit.

**Interaction to observe:** a carcass supports a localized fungal pulse, whereas woody litter releases nutrients more slowly. Continued harvesting without substrate renewal reduces fruiting. Wetland flooding can change decomposition instead of granting a universal fungal boost.

## Animals

### Grazer

**Current:** chooses the strongest moss/rhizome in a neighborhood centered on its habitat, eats, briefly digests, moves away and deposits the ingested material. It does not detect predators in its choice function, select food by quality, assimilate food into growth or lose condition through maintenance. Fear declines but does not produce grazer escape behavior. Cover is an arrival requirement rather than a fully used refuge.

**Evidence:** ungulate feeding experiments demonstrate that seed dispersal depends on gut retention and survival/germination of particular seeds, not simply the amount eaten. [Picard et al., 2015](https://pmc.ncbi.nlm.nih.gov/articles/PMC4523358/). Dung mesocosms also show effects depend on nutrient quality and quantity. [Sitters et al., 2019](https://www.nature.com/articles/s41598-019-42249-z).

**Proposal:** search → approach → take several bounded bites → digest/rest → seek again, interrupted by perceived risk. Choose locally sensed or remembered patches by expected food gain, travel cost, recent depletion and nearby refuge. A finite gut partitions food into assimilated reserves and excretion; maintenance uses reserves, and sustained surplus supports juvenile growth and reproduction. Deposit after a delay, allowing spatial redistribution without requiring a different cell every time.

Let mature seeds enter the gut only when actually eaten, with a species-specific survival fraction and later germination test. Add loose group cohesion only if this alien grazer is deliberately defined as social; not every herbivore needs flocking.

**Interaction to observe:** grazers alternate feeding and sheltered resting sites, shifting nutrient deposition. Predators alter where they graze, letting one plant patch recover while another takes more pressure. Repeated bites reduce the plants' own capacity to recover.

### Predator

**Current:** `_nearest_living_species()` searches all present grazers, without a perception range. The predator follows a target even when not hungry enough to attack; adjacent predation reliably transfers body biomass. Consumed animal biomass stays carried instead of completing digestion and excretion. Grazers do not respond to the predator.

**Evidence:** an experiment separating predation risk from killing found herbivore behavior alone could alter plant biomass. This was a spider–grasshopper system, so its magnitudes should not be copied into a mammal-like alien predator. [Schmitz, Beckerman & O’Brien, 1997](https://doi.org/10.1890/0012-9658%281997%29078%5B1388%3ABMTCEO%5D2.0.CO%3B2).

**Proposal:** define a hunting strategy first: short pursuit from cover is a manageable choice. Give it bounded detection, pursuit energy, loss of contact, failed attacks, feeding and long resting periods. Let prey detect cues, flee toward usable cover and resume cautiously. Successful kills leave a finite carcass after the predator's meal; decomposers can finish it. Scavenging can initially be a behavior of this predator rather than an additional species.

**Interaction to observe:** a hunt fails and still changes grazing distribution. A kill concentrates nutrients and attracts decomposition. Low prey support makes the predator lose condition or leave; it is not a guaranteed population-balancing service.

### Flying Reproductive Vector

**Current:** seeks the strongest flower signal near its settlement, creates a pollen load without depleting a donor store, and deposits generic pollination on any flowering cell—including its collection cell. Neither plant identity nor donor identity is stored. Its spore pathway is separately named, which is useful, but also lacks finite source allocation. It has no floral food consumption or energetic reason to visit.

**Evidence:** individually tracked bumblebees developed routes through exploration and repeated exploitation. [Primary experiment, 2019](https://pmc.ncbi.nlm.nih.gov/articles/PMC6685008/). Pollen-transfer experiments show that pollen carried and pollen delivered are different measures. [Adler & Irwin, 2006](https://pmc.ncbi.nlm.nih.gov/articles/PMC2000767/).

**Proposal:** give flowers finite replenishing rewards; the animal seeks those rewards, learns useful patches and occasionally explores. Track pollen by plant type and source individual/clone, with finite viability, partial deposition and losses. A receptive compatible flower may set seed after a visit; maturation still costs the parent resources. Self-fertilization can be permitted for a chosen species, but same-cell events cannot count as evidence of connecting isolated populations.

Make flowering overlap, visit handling time, depleted rewards, wind/temperature and shelter affect activity. If this animal also transports fungal spores, use incidental contact or feeding motivation and finite spore loads; it should not deliberately seek ideal fungal planting sites as an ecosystem caretaker.

**Interaction to observe:** repeat routes develop between rewarding compatible plants; visits shift when one patch stops flowering. A vector may visit an incompatible plant without producing seed. A new seedling appears later in suitable habitat, visibly separating pollination from establishment.

### Wetland Engineer

**Current:** gathers nearby Detritus/Rooted Mat material and uses `last_gather_cell` as the build target. Arrival requires aquatic consumers as well as drainage and plant material, although its behavior neither eats nor otherwise uses those consumers. Material alters hydraulic terrain and decays, but there is no purposeful refuge target, adequate-water stopping rule or repair decision.

**Evidence:** field measurements and reactive-transport modeling show dams change upstream water levels, subsurface exchange and oxygen/nitrogen processing. Their hydrological and chemical effects depend on the actual setting. [Dewey et al., 2022](https://www.nature.com/articles/s41467-022-34022-0).

**Proposal:** inspect local channel/refuge conditions → choose a defensible constriction → gather finite suitable material elsewhere → haul → build → monitor/repair. Store a build site independently from a food/material site. Stop adding material when refuge is adequate; permit non-building residency where water is already deep enough. Replace the aquatic-consumer requirement with an actual need, unless a specific dietary dependence is intentionally chosen.

Represent pond depth and overflow using water-surface elevation, barrier permeability and available inflow. A dam should redistribute existing water, leak, overtop and eventually breach or decay. Dam material lost to erosion becomes transported organic material or an explicit export. Construction has feeding/time costs; an engineer needs its own diet and population cycle.

**Interaction to observe:** the upstream aquatic patch expands while roots drown and downstream flow temporarily diminishes. A new overflow route can form. The player can understand both the engineer's motive and why supporting it may harm a different habitat.

### Eusocial Colony: retain the movement improvement, finish its biology later

The current worker foraging is useful evidence and should remain preserved. It does not yet make every aspect of the colony ant-like: worker count is fixed, brood is an aggregate gain, and plant material is converted through a simplified nest recycling rule. Realism needs a deliberately chosen feeding strategy; collecting leaves alone does not specify what sustains an ant-like colony.

Propose nest stores, adult maintenance and brood allocation, with worker replacement dependent on food. Keep decomposition distinguishable from animal assimilation. Define either direct food consumption or an explicit cultivated-food relationship before adding dietary behavior. This is an unresolved alien-species choice, not a claim that all ants cultivate fungi. Defer this extension until the requested non-colony behaviors have received comparable attention.

## Aquatic life, atmosphere and succession

### Aquatic producers, consumers and microbial sulfur processing

**Current:** producer and consumer biomass can awaken without tracked propagule stocks. Dissolved oxygen relaxes toward a biomass-derived target, without light-driven production or explicit respiration. Consumers grow separately from the quantity grazed. Surface-water loss does not directly impose the strong mortality/dormancy response needed for an obligately aquatic population. Sulfur has a baseline processing rate even with no consumers, despite discovery text implying producers cannot release it alone.

**Evidence:** high-frequency oxygen measurements across streams support separate photosynthesis, respiration and temperature responses. [Primary study, 2018](https://www.nature.com/articles/s41561-018-0125-5). Single-cell bacterial experiments show competing DMSP processing routes, and an algal enzyme has been experimentally shown to release DMS from DMSP. The Earth pathway is not exclusively a zooplankton conversion. [Gao et al., 2020](https://www.nature.com/articles/s41467-020-15693-z), [Alcolombri et al., 2015](https://pubmed.ncbi.nlm.nih.gov/26113722/).

**Proposal:** producers grow from light and finite dissolved resources; consumers assimilate a fraction of actual grazing. Respiration and decomposition consume oxygen; photosynthesis and air–water exchange replenish it. Drying causes death or a specified resting stage, and reconnection permits flow-borne recolonization. Dormant cyst/spore banks should be finite state rather than unexplained spontaneous population creation.

Represent sulfur precursor with competing microbial assimilation and volatile-release pathways, then water–air exchange. Grazing or cell damage can alter substrate supply. Keep these microbes aggregated within cells; they do not need separate visible animals.

**Interaction to observe:** nutrient runoff increases a bloom, but a dense bloom plus decomposition can produce a low-oxygen interval and consumer losses. Shade, flushing and grazing change the trajectory. Avoid assuming that more consumers always means more sulfur, better water quality or healthier habitat.

### First Rain

`weather_simulation.step()` multiplies rain readiness by `aquatic_rain_link`. With no local volatile sulfur, rain is prevented even if other atmospheric conditions are favorable. This is an explicit alien prototype dependency, not Earth rainfall physics. The prior rainfall report already distinguished these confidence levels; the code implements a stronger gate.

Research shows that atmospheric removal can substantially limit the conversion of DMS emissions into cloud-relevant particles. [Novak et al., 2021](https://pmc.ncbi.nlm.nih.gov/articles/PMC8594482/). Emission, aerosol formation, cloud formation and precipitation must remain distinguishable.

**Recommended future decision:** retain the Aquatic Sulfur Pathway as a meaningful contributor but allow regional moisture and background particles to support precipitation without a mandatory local species. Use actual local vapor flux, coarse regional transport, conversion delays and particle removal. Preserve the natural Atmospheric Window and the Presence's noncausal role. This deliberately changes a canonical prototype dependency and needs a separate playable question, not a quiet balance adjustment.

### A persistent Ecological Mosaic

Succession should follow changes in substrate, resources, competition and propagule availability. A helpful predecessor need not remain alive forever, and a disturbance need not erase all prepared habitat. Experimental facilitation evidence above supports testing conditional neighbor benefits rather than unconditional progression.

Preserve dead roots, structural litter, seed banks, damaged nests and channel alterations long enough to affect recovery. Shared stress responses should include heat, dry periods, burial and inundation. Disease, parasites and additional species can wait; they are useful only when they introduce a distinct feedback the player can observe.

## Recommended sequence of playable experiments

| Order | Change and dependency | Proposed player comprehension gate |
|---|---|---|
| 1 | Shared nutrient/water accounting, explicit growth costs and resource-limited metabolism; preserve the opening's recoverability | Explain why moving material helps one patch at a cost elsewhere, and why retained water still eventually runs out |
| 2 | Vector rewards and local memory; compatible pollen, flowering and seed establishment; independent clonal mat spread | Identify a route between plants, distinguish a visit from successful reproduction, and predict where a new patch can establish |
| 3 | Grazer diet/gut/reserves and predator perception/refuge behavior; complete carcass return | Explain changed grazing pressure and relocated nutrients after a predator appears, including a case without a kill |
| 4 | Moss/crust inactivity, plant competition, canopy water uptake and substrate-aware decomposition | Distinguish dormant from dead habitat and explain why the same canopy helps one organism but suppresses another |
| 5 | Engineer site selection and maintenance atop water accounting; aquatic oxygen, consumer assimilation and drying | Predict an upstream benefit and downstream or terrestrial cost, then recognize the observed consequence |
| 6 | Repeated resource-supported births, maturation and regional exchange across roles | Distinguish immigration from local reproduction and explain why a population persists, contracts or leaves |
| 7 | Reconsider atmospheric dependency using fluxes, regional inputs and conditional chemistry | Explain ecological contributions without concluding that a local species unlocks weather |

Start with stage 1's small shared budget seam and the vector/plant reproduction experiment as the first visible improvement. Each stage should extend the existing integrated Godot prototype, preserve its evidence branch, run every README regression after changes, and receive a fresh visually checked build. Do not implement the whole report as one large tuning pass.

Automated verification should cover meaningful counterfactuals: zero resource supply stops net growth; compatible and incompatible pollen have different outcomes; local clonal growth survives vector absence; disconnected roots cannot share water; unfed juveniles cannot mature; prey outside perception are not chased; dams cannot increase total water; drying removes active aquatic habitat; and snapshot replay stays deterministic. Full ecological accounting needs recorded boundary fluxes, not assertions that every normalized field sums to a constant.

The strongest eventual combined episode would be: restored ground supports a mat; flowers sustain a vector; compatible seed establishes canopy; shade and litter support fungi; grazing shifts with predator risk; an engineer retains a real water pulse while flooding part of the terrestrial habitat; and the aquatic community changes oxygen and atmospheric emissions. Each link must also be able to fail, take an alternative route, or reverse for an intelligible local reason.

## Scope and confidence limits

Mechanisms such as finite uptake, compatible reproduction, delayed digestion and water redistribution have strong ecological grounding. Exact diets, social structure, pollen compatibility, rooting depth, dormancy tolerance and sulfur chemistry must be chosen for First Rain's fictional species. Published experiments illustrate possibilities and constraints, not universal values for every ecosystem.

The research question is answered here. All proposed behavior remains unimplemented and experiential validation remains pending. Existing prototype issues and accepted vocabulary remain unchanged until their corresponding decisions are revisited. This report supersedes no prior human playtest result.
