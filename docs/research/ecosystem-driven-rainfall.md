# Ecosystem-driven rainfall and ecological roles for First Rain

_Research date: 2026-08-28. Sources are primary experimental, observational, or modeling studies. “Evidence” describes results on Earth; “Design implication” is an inference for First Rain, not a claim that an alien ecosystem must work identically._

> **Prototype status, 2026-09-04:** Commit `32057c1` introduced one deliberately stronger playable rule from this research: standing-water producers create a sulfur precursor, aquatic consumers process it into volatile sulfur, and First Rain readiness requires that aquatic contribution alongside terrestrial vapor, biological particles, and a natural Atmospheric Window. The current `prototype/reversible-animal-residency` experiment retains that pathway while replacing basin-wide animal progression with local Habitat Support. This is prototype evidence, not a revision of the confidence judgments below or a claim that aquatic sulfur alone causes rain. Player comprehension remains unvalidated in [issue #28](https://github.com/mmullen200/first-rain/issues/28).

## Decision summary

**First Rain should emerge from a convergence of restored ecological functions and a favorable natural atmospheric window. The Presence neither summons nor concentrates rain.**

The scientifically defensible inspiration is not “plankton makes rain.” It is a coupled pathway:

1. existing planetary water is retained in soil, organisms, wetlands, or a subsurface Reservoir rather than immediately running off or escaping;
2. rooted and canopy-forming producers return part of that water to the air through transpiration;
3. aquatic microbes and terrestrial vegetation emit compounds that can become aerosol particles or help existing particles grow;
4. fungi, bacteria, pollen-like propagules, fragments, and mineral dust provide additional cloud-condensation or ice-nucleating particles;
5. atmospheric cooling, lifting, humidity, wind, and cloud microphysics align strongly enough for droplets or ice crystals to grow into precipitation; and
6. a structurally diverse Ecological Mosaic retains the resulting rain well enough for rainfall to reinforce, rather than erase, restoration.

The research strongly supports each pathway existing in some terrestrial settings. It does **not** establish a universal, monotonic chain from more life to more rain. Cloud-nucleating particles can increase cloud droplet number yet suppress warm rain; emissions depend on species and chemistry; moisture can be transported downwind; and the first restored basin is far smaller than the terrestrial regions in which land–atmosphere feedbacks are measured. First Rain therefore needs an atmosphere already near a precipitation threshold, a real pre-existing water source, and regional or off-screen ecological recovery beyond the immediately playable basin.

## Confidence convention

- **High:** directly demonstrated physical or biological process across multiple methods or settings; direction is reliable even if magnitude varies.
- **Moderate:** credible primary evidence, but magnitude, atmospheric importance, or transfer to another setting is conditional.
- **Low / speculative for design:** a useful synthesis or alien extrapolation that has not been demonstrated as a complete causal chain on Earth.

## What terrestrial evidence supports

### 1. Aquatic microbes can contribute volatile sulfur and marine cloud particles

**Evidence — High for DMS production; Moderate for contribution to cloud particles; Low for a direct rain claim.**

Some—not all—phytoplankton make dimethylsulfoniopropionate (DMSP). Alcolombri et al. identified and experimentally characterized an algal DMSP-cleaving enzyme in the bloom-forming alga _Emiliania huxleyi_, directly linking a producer’s metabolism to dimethyl sulfide (DMS) release ([Science, DOI 10.1126/science.aab1586](https://doi.org/10.1126/science.aab1586)). DMSP also moves through a microbial food web: radiotracer incubations found uptake by phytoplankton and heterotrophic bacteria, which means microbial community composition can divert sulfur toward assimilation rather than atmospheric DMS ([Science, DOI 10.1126/science.1131043](https://doi.org/10.1126/science.1131043)).

Once emitted and oxidized, DMS can contribute non-sea-salt sulfate and methanesulfonic acid to atmospheric particles. Nine years of Cape Grim measurements found a significant but nonlinear seasonal relationship between cloud-condensation nuclei (CCN) and methanesulfonate, a DMS oxidation marker ([Nature, DOI 10.1038/353834a0](https://doi.org/10.1038/353834a0)). Southern Ocean ship measurements found both sulfate-rich secondary aerosol and sea-salt-containing primary aerosol activating as cloud droplets; their relative contributions varied by air mass and wind ([Scientific Reports, DOI 10.1038/s41598-018-32047-4](https://doi.org/10.1038/s41598-018-32047-4)). Satellite observations and aerosol modeling likewise associated seasonal cloud-droplet variation with sulfate at lower Southern Ocean latitudes and organic sea spray at higher latitudes ([Science Advances, DOI 10.1126/sciadv.1500157](https://doi.org/10.1126/sciadv.1500157)).

Biology can also alter material ejected by bubble bursting, but this is not a simple “more bloom, more CCN” rule. Controlled bloom experiments found that phytoplankton blooms changed sea-spray composition while only weakly changing its cloud-forming ability ([Geophysical Research Letters, DOI 10.1002/2016GL069922](https://doi.org/10.1002/2016GL069922)).

**Design implication:** an alien aquatic microbial mat or plankton-like community is a plausible sulfur-vapor contributor, but it needs standing water, microbial processing, air–water exchange or bubbling, atmospheric oxidants, and time. It should be one branch of the rainfall system, not the final switch. The Field Scanner could distinguish “sulfur precursor in water,” “volatile release,” and “airborne sulfate-like particles” so the player sees a chain rather than a magical bloom.

### 2. Terrestrial producers can supply both water vapor and particle-forming organic vapors

**Evidence — High for transpiration; High for formation of secondary organic material; Moderate for regional cloud effects; Low for basin-scale rain causation.**

Plants move substantial water from soil to atmosphere. A global isotope-based partitioning study estimated transpiration at 64 ± 13% of terrestrial evapotranspiration, with large uncertainty but a clear majority contribution ([Science, DOI 10.1126/science.aaa5931](https://doi.org/10.1126/science.aaa5931)). A global moisture-tracking analysis estimated that 40% of terrestrial precipitation had most recently evaporated from land and that 57% of terrestrial evaporation returned as precipitation over land; it also showed strong dependence on circulation and topography ([Water Resources Research, DOI 10.1029/2010WR009127](https://doi.org/10.1029/2010WR009127)).

Observational studies find vegetation-linked rainfall relationships at much larger scales than the Crash Basin. Satellite rainfall and atmospheric back-trajectories showed that, across much of the tropics, air that had passed over extensive vegetation produced at least twice as much rain as air that had passed over sparse vegetation, while the authors explicitly treated evapotranspiration as the proposed mechanism rather than direct experimental proof ([Nature, DOI 10.1038/nature11390](https://doi.org/10.1038/nature11390)). Isotope and satellite observations over the southern Amazon found increased transpiration before wet-season onset and concluded that rainforest transpiration helps moisten the lower atmosphere before rain begins ([PNAS, DOI 10.1073/pnas.1621516114](https://doi.org/10.1073/pnas.1621516114)).

Vegetation also emits biogenic volatile organic compounds (BVOCs). Chamber measurements showed that oxidation of plant-emitted vapors can rapidly form highly oxygenated, very low-volatility molecules that contribute to secondary organic aerosol ([Nature, DOI 10.1038/nature13032](https://doi.org/10.1038/nature13032)). CERN CLOUD experiments demonstrated particle nucleation involving sulfuric acid and oxidized biogenic organics at atmospheric concentrations ([Science, DOI 10.1126/science.1243527](https://doi.org/10.1126/science.1243527)); later CLOUD experiments demonstrated ion-induced nucleation from oxidized α-pinene products even without sulfuric acid under carefully controlled conditions ([Nature, DOI 10.1038/nature17953](https://doi.org/10.1038/nature17953)). These chamber results establish possible chemistry, not that a grove automatically causes rain.

In the wet-season Amazon, direct atmospheric measurements found that most fine particles serving as CCN were secondary organic material formed from oxidized biogenic gases, while larger particles relevant to ice formation were primarily biological material ([Science, DOI 10.1126/science.1191056](https://doi.org/10.1126/science.1191056)).

**Design implication:** rooted mats and canopy-formers should not merely be “larger moss.” Their distinct roles are to access different soil-water pools, transpire, provide roughness and shade, produce litter, and emit different atmospheric precursors. A canopy is the most legible late-Succession sign that the basin is coupling ground water to the atmosphere. Rain still needs an external cooling/lifting window and may fall locally or downwind.

### 3. Biological particles can nucleate cloud ice, but atmospheric importance is conditional

**Evidence — High that some biological material nucleates ice; Moderate-to-low for how much it changes real precipitation.**

Sampling across North America, Europe, Antarctica, and the Yukon found heat-sensitive biological ice nucleators in rain and snow that catalyzed freezing at temperatures warmer than −10 °C ([PNAS, DOI 10.1073/pnas.0809816105](https://doi.org/10.1073/pnas.0809816105)). Amazon field measurements found that biological particles dominated ice-nucleating material under some clean conditions, while Saharan mineral dust dominated during dusty periods ([Nature Geoscience, DOI 10.1038/ngeo517](https://doi.org/10.1038/ngeo517)).

Laboratory tests of twelve fungal species found that every tested spore population contained at least some spores able to nucleate ice above homogeneous-freezing temperatures, but active fractions and temperatures differed substantially among species ([Atmospheric Chemistry and Physics, DOI 10.5194/acp-14-8611-2014](https://doi.org/10.5194/acp-14-8611-2014)). Experiments on fungal, bacterial, and pollen-derived material also found water-soluble ice-nucleating macromolecules, meaning intact living organisms are not always required ([Atmospheric Chemistry and Physics, DOI 10.5194/acp-15-4077-2015](https://doi.org/10.5194/acp-15-4077-2015)).

**Design implication:** fungal sporulation, bacterial films, pollen-like reproductive bursts, plant fragments, and mineral dust can form a diverse **airborne-particle role**, especially during wind or temperature changes. These sources should vary by season and species. The game must not state that spores “make rain”; they alter one conditional step in cold or mixed-phase cloud formation.

### 4. Animals can alter atmospheric chemistry and ground hydrology, but their effects are role-specific

**Evidence — Moderate for particular Earth systems; Low for generalizing one animal pathway to all ecosystems.**

Animal waste can participate in atmospheric particle formation under particular chemistry. Field observations near Antarctic penguin colonies measured elevated ammonia in colony-sourced air and linked it to strong new-particle formation when sulfur compounds were available ([Communications Earth & Environment, DOI 10.1038/s43247-025-02312-2](https://doi.org/10.1038/s43247-025-02312-2)). Separate cruise observations and modeling found freeze–thaw-enhanced ammonia from penguin-derived soils increased simulated secondary particle and cloud-droplet concentrations ([npj Climate and Atmospheric Science, DOI 10.1038/s41612-024-00873-1](https://doi.org/10.1038/s41612-024-00873-1)). These are specific polar systems, not evidence that ordinary grazing automatically causes rain.

Animal engineers can also change where pulse water goes. Dye-tracing and seasonal measurements of fungus-growing termite mounds found that compact walls limited infiltration and evaporation while internal tunnels drained excess water and termites actively redistributed water within the mound ([Agriculture, Ecosystems & Environment, DOI 10.1016/j.agee.2019.03.001](https://doi.org/10.1016/j.agee.2019.03.001)). Measurements across African savanna soils found that bare and vegetated termite mounds had opposite infiltration behavior, illustrating that animal structures can either retain or redirect water depending on vegetation and soil texture ([Journal of Arid Environments, DOI 10.1016/j.jaridenv.2023.104997](https://doi.org/10.1016/j.jaridenv.2023.104997)).

**Design implication:** the existing grazer can move nutrients through feeding and manure, and an additional burrower or mound-builder can create macropores, dams, or runoff diversions. Manure may support decomposers and, in a later atmospheric layer, provide a nitrogenous vapor that interacts with sulfur chemistry. These are coupled contributions, not a universal “animal count” requirement.

### 5. Groundcover, roots, litter, fungi, and animal structures determine whether rainfall persists locally

**Evidence — High that biota modify soil structure and water routing; Moderate for the direction and magnitude in any specific habitat.**

Living cover is not uniformly sponge-like. Rainfall simulations on karst slopes found moss cover changed infiltration and runoff relative to bare patches, with results depending on rainfall intensity and soil context ([Water, DOI 10.3390/w14213429](https://doi.org/10.3390/w14213429)). Experiments in semi-arid sandy land found that litter over moss/lichen biocrust broke surface water repellency and increased initial infiltration and soil-water content ([Agricultural Water Management, DOI 10.1016/j.agwat.2021.107009](https://doi.org/10.1016/j.agwat.2021.107009)). The important role is therefore a mosaic of surface roughness, litter, pores, and rooted patches—not a universal moss retention bonus.

Fungal effects are similarly conditional but mechanically useful. A glasshouse experiment found that increasing saprophytic or mycorrhizal hyphal length increased water-stable aggregation in sandy soil ([Applied Soil Ecology, DOI 10.1016/0929-1393(95)00074-7](https://doi.org/10.1016/0929-1393(95)00074-7)). Isotope-tracing experiments directly demonstrated water transport from arbuscular mycorrhizal fungi to host plants, while another experiment found fungal transport small relative to total plant demand under its tested conditions ([New Phytologist, DOI 10.1111/nph.18281](https://doi.org/10.1111/nph.18281); [Mycorrhiza, DOI 10.1007/s00572-020-00949-9](https://doi.org/10.1007/s00572-020-00949-9)).

**Design implication:** successful First Rain preparation is as much about receiving water as seeding clouds. Pioneer cover slows erosion; litter and Detritus alter infiltration; roots create deeper access and soil structure; fungi bind aggregates and connect plants; burrowers redirect pulses; and distributed vegetation prevents one channel from washing the basin clean. The same organism may help in one Ecological Zone and worsen runoff or competition in another.

## What the game must not overstate

1. **Life does not create water.** It stores, moves, evaporates, transpires, and recycles water already present. The terrain-bound Reservoir, subsurface ice, periodic vapor advection, or another real source must precede First Rain.
2. **CCN are not rain buttons.** More CCN can create more, smaller droplets and suppress collision–coalescence in marine warm clouds. Satellite analysis found marine rain strongly suppressed as cloud-droplet concentration rose under comparable cloud conditions ([Geophysical Research Letters, DOI 10.1029/2019GL086207](https://doi.org/10.1029/2019GL086207)). In deep convection, ultrafine aerosols have instead intensified convection and precipitation under particular clean, humid Amazon conditions ([Science, DOI 10.1126/science.aan8461](https://doi.org/10.1126/science.aan8461)). The sign depends on cloud type, particle size, humidity, stability, and dynamics.
3. **DMS is not a proven planetary thermostat.** The steps from DMSP to DMS, from DMS oxidation to sulfate, and from some aerosol to cloud droplets are supported. A self-regulating plankton–cloud–temperature loop, or a deterministic DMS-to-rain chain, is not established by those steps.
4. **Not every producer emits the useful compound.** DMSP and BVOC production varies among taxa and with stress, light, temperature, nutrients, grazers, and microbial processing. Species identity matters more than a global “plant biomass” total.
5. **Cloud formation is not precipitation.** Droplets or ice must grow, collide, coalesce, and survive evaporation while atmospheric motion supplies and cools moist air.
6. **A single small basin would not realistically reorganize regional weather by itself.** The playable Crash Basin should be the clearest local part of a recovering region, with distant awakening visible on the horizon or detected imperfectly by the Field Scanner.
7. **Biological ice nucleators are not always dominant.** Mineral dust, sea salt, and other nonbiological particles can dominate, and biological particles may be too sparse or at the wrong altitude.
8. **Soil-life effects are not uniformly beneficial.** Biocrusts can repel water; dense plants can exhaust local water; hyphal water transfer can be small; burrows can drain rather than retain; and transpiration can reduce local soil water even while increasing atmospheric moisture.

## Recommended natural route to First Rain

This is a **design synthesis with Low confidence as a complete Earth analogue**, assembled from individually supported processes. It is plausible if the alien atmosphere is already seasonally close to saturation and if restoration extends beyond the visible play space.

### Stage 0 — A water-bearing but uncoupled basin

Water exists in a deep Reservoir, mineral-bound ice, rare Drainage Pulses, and atmospheric transport. Bare toxic ground loses pulses to runoff and evaporation. Dust provides abundant particles but little persistent humidity, and the Ecological Mosaic lacks the structure needed to receive heavy rain.

### Stage 1 — Pioneer retention and soil formation

Moss-like groundcover and microbial crust awaken in sheltered wet cells. They trap dust and organic material but may also create local water repellency. Fungus decomposes dead biomass; its hyphae stabilize some aggregates. The player must combine cover with litter, pores, and terrain rather than painting every cell with moss.

### Stage 2 — Rooted water cycling

A rhizome-mat producer colonizes drainage edges and binds loose sediment. A slower canopy-former reaches deeper water, shades recovery pockets, drops litter, and transpires during warm periods. Water now spends longer in the land–plant–air loop, but dense growth can still overdraw a local patch.

### Stage 3 — Mobile nutrient and habitat networks

The grazer distributes nutrients and propagules while threatening concentrated food patches. A burrowing or mound-building detritivore creates infiltration and drainage structures. Pollinator/spore-vector behavior connects separated patches. Fungus and soil microbes convert Detritus into plant-available nutrients and volatile precursors. No animal is a commanded unit; each responds to habitat.

### Stage 4 — Aquatic and airborne chemistry

Retained water creates a persistent pond, wetland, or exposed Reservoir margin. A plankton-like producer and associated microbes generate a sulfur precursor; biological processing releases a DMS analogue. Wind, bubbles, or a small cascade transfers material into the air. Terrestrial canopy-formers add BVOC analogues, while fungi and reproductive organisms release seasonally varying biological particles. Grazer or colony waste supplies nitrogenous chemistry only where decomposer activity and weather make volatilization possible.

### Stage 5 — A natural atmospheric window

A periodic cooling phase, pressure transition, upslope wind, or seasonal convergence lifts moist basin air. Accumulated water vapor, sulfur-derived aerosol, oxidized terrestrial organics, biological particles, sea-salt/mineral dust, and ordinary atmospheric physics together cross a cloud-forming threshold. Whether cloud becomes rain depends on particle-size balance, vertical motion, temperature, and sufficient cloud water—not an ecosystem-completion flag.

The Presence can warn of the atmospheric shift and observe unfamiliar signals, but it has no causal rainfall ability. The player may accelerate, delay, or weaken the ecological contribution through stewardship; they cannot press a button to start weather.

### Stage 6 — First Rain tests the whole system

Rainfall enters the Drainage Spine. Rooted and litter-rich patches retain it; exposed slopes erode; fungal and aquatic networks spread; dormant organisms awaken; and mobile animals redistribute the pulse. First Rain is therefore both consequence and Disturbance. The meaningful result is not that rain occurred but that enough connected ecological functions survived and used it to deepen the cycle.

## Essential roles for a substantially richer Godot prototype

These are functional Ecological Roles, not a claim that each requires a unique Earth-like species or a high-detail visual model.

| Role | Candidate organism | Required observable function | Why it belongs in the next prototype |
|---|---|---|---|
| Pioneer cover | Existing moss analogue plus microbial crust | Traps material, changes shallow moisture and erosion, creates both benefits and possible repellency | Preserves the current bootstrap while making ground preparation conditional |
| Decomposer / soil binder | Existing fungus plus soil microbes | Converts Detritus to mobile nutrients, forms hyphal connections, fruits/sporulates under suitable moisture | Links death, food, soil, and airborne biology instead of serving only as a fruit dispenser |
| Rooted mat producer | Rhizome grass/sedge analogue | Stabilizes drainage edges, feeds grazers, competes for water, produces litter and modest transpiration | Creates the first scalable plant layer and a meaningful grazer landscape |
| Canopy-former | Alien shrub/tree-like structure | Accesses deeper moisture, creates shade and litter, transpires strongly, emits a distinct vapor | Provides the long ecological horizon and a legible land–atmosphere bridge |
| Aquatic primary producer | Plankton-like cells or microbial surface mat | Blooms only in persistent water, produces a sulfur precursor, supports a microbial food web | Makes the player’s DMS inspiration systemic without claiming plankton alone causes rain |
| Sulfur-processing microbe | Coupled bacterial state within aquatic patches | Chooses between assimilating sulfur and releasing volatile sulfur according to nutrients/stress | Prevents “more algae = more DMS” from becoming a false linear rule |
| Mobile nutrient mover | Existing grazer | Grazes, moves in persistent routes, deposits manure, carries propagules, can overgraze concentration | Reuses the strongest current animal system and makes spatial diversity necessary |
| Soil engineer / detritivore | Burrower or mound-builder | Opens or blocks flow paths, incorporates litter, creates wet and dry microsites | Makes animals materially shape hydrology rather than merely consume biomass |
| Reproductive vector | Pollinator/spore carrier | Connects separated flowering or sporulating patches; responds to short ecological windows | Makes diversity and patch connectivity visible through movement |
| Atmospheric state | Not an organism | Tracks local vapor, precursor gases, particle classes, cloud water, wind, temperature, and uncertainty | Makes rain an emergent environmental process instead of an authored cutscene |

For prototype scope, the sulfur-processing microbe can be a hidden-but-scannable state within aquatic patches rather than another visible creature. The atmospheric model can use a few bounded variables and deterministic update phases. What matters is that several independently legible ecological causes must coincide and that removing one role changes the trajectory in a comprehensible way.

## Longer-game ecological richness

After the minimum role set is playable, add organisms only when they create a new feedback rather than another resource icon:

- **Microzooplankton and filter feeders:** regulate aquatic blooms and redirect sulfur processing.
- **Nitrogen fixers and mineral symbionts:** open nutrient-poor ground without generating matter from nothing.
- **Predators and scavengers:** prevent grazer booms and relocate carcass nutrients.
- **Seed predators and dispersers:** create a reproduction–consumption tension around canopy expansion.
- **Specialist pollinators:** make flowering weather windows and habitat corridors important.
- **Deep-root hydraulic engineers:** redistribute subsurface water and compete with shallow mats.
- **Wetland builders:** dam or spread Drainage Pulses, creating persistent aquatic habitat at a flooding cost.
- **Epiphytes and canopy dwellers:** intercept fog and create vertical habitat once canopy-formers exist.
- **Pathogens and parasites:** test monocultures and create Disturbances that reward mosaics.
- **Colonial animals:** concentrate nutrients and atmospheric precursor chemistry while producing local toxicity and overuse.
- **Dormant propagule banks:** preserve recovery routes after heat, cold, flood, and dust events.

## Prototype design implications and testable question

The next playable prototype should ask:

> Can the player form a causal understanding that several ecological roles are jointly changing the basin’s water retention, atmospheric moisture, and airborne particles—and recognize First Rain as a natural threshold event rather than a reward triggered by the Presence?

Recommended evidence model:

- Preserve local, imperfect instruments. The Field Scanner can report soil-water residence, transpiration, sulfur precursor, volatile flux, airborne particle classes, and cloud-base trend with explicit uncertainty; it should not display “rain progress.”
- Make at least two atmospheric windows pass. The first should fail or produce only cloud/fog when the ecology is incomplete; a later one can produce rain if multiple functions are operating. This separates natural cadence from player-triggered weather.
- Let different preparations produce different partial outcomes: high vapor with too few effective nuclei; many particles with too little vapor; cloud without coalescence; rain that erodes an unprepared basin; or retained rain that accelerates Succession.
- Keep the Presence epistemically limited. It can Nudge attention to sky, wind, plant behavior, or unfamiliar chemistry and can warn of danger, but it neither knows a hidden completion threshold nor performs the atmospheric process.
- Represent regional recovery beyond the Crash Basin through distant canopy silhouettes, migrating organisms, changing haze, airborne measurements, or horizon weather. The playable basin contributes to and reveals a larger system.
- Treat the first successful rainfall as the start of a new ecological episode. Aquatic habitat, erosion, migration, germination, and new Disturbances should begin immediately.

### Proposed playtest gate

Without being shown a recipe or objective meter, a player should be able to:

1. identify at least three distinct ecological contributions to the atmosphere or water cycle;
2. explain why an aquatic bloom alone did not guarantee rain;
3. distinguish the Presence’s warning or observation from causal control;
4. diagnose one failed atmospheric window using situated evidence;
5. prepare more than one Ecological Zone to receive a Drainage Pulse or rain event; and
6. predict one benefit and one cost of the resulting First Rain.

Passing that gate would validate causal legibility and player understanding. It would not validate the precise scientific magnitude of a basin-scale weather feedback, which remains a deliberate alien-world compression.

## Primary source index

- Alcolombri et al. (2015), algal DMSP lyase: [https://doi.org/10.1126/science.aab1586](https://doi.org/10.1126/science.aab1586)
- Vila-Costa et al. (2006), DMSP uptake in marine microbial food webs: [https://doi.org/10.1126/science.1131043](https://doi.org/10.1126/science.1131043)
- Ayers & Gras (1991), seasonal CCN–methanesulfonate relationship: [https://doi.org/10.1038/353834a0](https://doi.org/10.1038/353834a0)
- Fossum et al. (2018), Southern Ocean primary and secondary CCN: [https://doi.org/10.1038/s41598-018-32047-4](https://doi.org/10.1038/s41598-018-32047-4)
- McCoy et al. (2015), natural aerosol and Southern Ocean cloud droplets: [https://doi.org/10.1126/sciadv.1500157](https://doi.org/10.1126/sciadv.1500157)
- Collins et al. (2016), weak bloom effect on sea-spray CCN activity: [https://doi.org/10.1002/2016GL069922](https://doi.org/10.1002/2016GL069922)
- Good et al. (2015), partitioning terrestrial evapotranspiration: [https://doi.org/10.1126/science.aaa5931](https://doi.org/10.1126/science.aaa5931)
- van der Ent et al. (2010), continental moisture recycling: [https://doi.org/10.1029/2010WR009127](https://doi.org/10.1029/2010WR009127)
- Spracklen et al. (2012), forest exposure and downwind tropical rain: [https://doi.org/10.1038/nature11390](https://doi.org/10.1038/nature11390)
- Wright et al. (2017), rainforest transpiration and wet-season onset: [https://doi.org/10.1073/pnas.1621516114](https://doi.org/10.1073/pnas.1621516114)
- Ehn et al. (2014), low-volatility products of plant emissions: [https://doi.org/10.1038/nature13032](https://doi.org/10.1038/nature13032)
- Riccobono et al. (2014), biogenic organics in atmospheric particle nucleation: [https://doi.org/10.1126/science.1243527](https://doi.org/10.1126/science.1243527)
- Kirkby et al. (2016), pure biogenic particle nucleation: [https://doi.org/10.1038/nature17953](https://doi.org/10.1038/nature17953)
- Pöschl et al. (2010), Amazon biogenic cloud nuclei: [https://doi.org/10.1126/science.1191056](https://doi.org/10.1126/science.1191056)
- Christner et al. (2008), biological ice nucleators in precipitation: [https://doi.org/10.1073/pnas.0809816105](https://doi.org/10.1073/pnas.0809816105)
- Prenni et al. (2009), biological and dust ice nuclei in Amazonia: [https://doi.org/10.1038/ngeo517](https://doi.org/10.1038/ngeo517)
- Haga et al. (2014), ice nucleation by fungal spores: [https://doi.org/10.5194/acp-14-8611-2014](https://doi.org/10.5194/acp-14-8611-2014)
- Pummer et al. (2015), biological ice-nucleating macromolecules: [https://doi.org/10.5194/acp-15-4077-2015](https://doi.org/10.5194/acp-15-4077-2015)
- Boyer et al. (2025), penguin-derived ammonia and particle formation: [https://doi.org/10.1038/s43247-025-02312-2](https://doi.org/10.1038/s43247-025-02312-2)
- Tian et al. (2024), freeze–thaw enhancement of penguin ammonia emissions: [https://doi.org/10.1038/s41612-024-00873-1](https://doi.org/10.1038/s41612-024-00873-1)
- Chen et al. (2019), termite-mound water regulation: [https://doi.org/10.1016/j.agee.2019.03.001](https://doi.org/10.1016/j.agee.2019.03.001)
- _Termite mound impacts on hydrology_ (2023), context-dependent mound infiltration: [https://doi.org/10.1016/j.jaridenv.2023.104997](https://doi.org/10.1016/j.jaridenv.2023.104997)
- Tu et al. (2022), moss effects on slope infiltration and runoff: [https://doi.org/10.3390/w14213429](https://doi.org/10.3390/w14213429)
- Cui et al. (2021), litter, biocrust water repellency, and infiltration: [https://doi.org/10.1016/j.agwat.2021.107009](https://doi.org/10.1016/j.agwat.2021.107009)
- Miller & Jastrow (1996), fungal hyphae and water-stable soil aggregation: [https://doi.org/10.1016/0929-1393(95)00074-7](https://doi.org/10.1016/0929-1393(95)00074-7)
- Kakouridis et al. (2022), direct mycorrhizal water transport: [https://doi.org/10.1111/nph.18281](https://doi.org/10.1111/nph.18281)
- Püschel et al. (2020), conditional magnitude of mycorrhizal water transport: [https://doi.org/10.1007/s00572-020-00949-9](https://doi.org/10.1007/s00572-020-00949-9)
- Fan et al. (2020), aerosol suppression of marine warm rain: [https://doi.org/10.1029/2019GL086207](https://doi.org/10.1029/2019GL086207)
- Fan et al. (2018), aerosol enhancement of Amazon deep convection: [https://doi.org/10.1126/science.aan8461](https://doi.org/10.1126/science.aan8461)
