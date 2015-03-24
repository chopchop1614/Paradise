#define HYDRO_SPEED_MULTIPLIER 1

/obj/machinery/portable_atmospherics/hydroponics
	name = "hydroponics tray"
	icon = 'icons/obj/hydroponics.dmi'
	icon_state = "hydrotray3"
	density = 1
	anchored = 1
	flags = OPENCONTAINER

	var/draw_warnings = 1 //Set to 0 to stop it from drawing the alert lights.

	// Plant maintenance vars.
	var/waterlevel = 100       // Water level (max 100)
	var/maxwater = 100
	var/nutrilevel = 10        // Nutrient level (max 10)
	var/maxnutri = 10
	var/pestlevel = 0          // Pests (max 10)
	var/weedlevel = 0          // Weeds (max 10)s

	// Tray state vars.
	var/dead = 0               // Is it dead?
	var/harvest = 0            // Is it ready to harvest?
	var/age = 0                // Current plant age

	// Harvest/mutation mods.
	var/yield_mod = 0          // Modifier to yield
	var/mutation_mod = 0       // Modifier to mutation chance
	var/toxins = 0             // Toxicity in the tray?

	// Mechanical concerns.
	var/health = 0             // Plant health.
	var/lastproduce = 0        // Last time tray was harvested
	var/lastcycle = 0          // Cycle timing/tracking var.
	var/cycledelay = 150       // Delay per cycle.
	var/closed_system          // If set, the tray will attempt to take atmos from a pipe.
	var/force_update           // Set this to bypass the cycle time check.

	// Seed details/line data.
	var/datum/seed/seed = null // The currently planted seed

	// Construction
	var/unwrenchable = 1

	// Reagent information for process(), consider moving this to a controller along
	// with cycle information under 'mechanical concerns' at some point.
	var/global/list/toxic_reagents = list(
		"anti_toxin" =     -2,
		"toxin" =           2,
		"fluorine" =        2.5,
		"chlorine" =        1.5,
		"sacid" =           1.5,
		"pacid" =           3,
		"plantbgone" =      3,
		"cryoxadone" =     -3,
		"radium" =          2
		)
	var/global/list/nutrient_reagents = list(
		"milk" =            0.1,
		"beer" =            0.25,
		"phosphorus" =      0.1,
		"sugar" =           0.1,
		"sodawater" =       0.1,
		"ammonia" =         1,
		"diethylamine" =    2,
		"nutriment" =       1,
		"adminordrazine" =  1,
		"eznutrient" =      1,
		"robustharvest" =   1,
		"left4zed" =        1
		)
	var/global/list/weedkiller_reagents = list(
		"fluorine" =       -4,
		"chlorine" =       -3,
		"phosphorus" =     -2,
		"sugar" =           2,
		"sacid" =          -2,
		"pacid" =          -4,
		"plantbgone" =     -8,
		"adminordrazine" = -5
		)
	var/global/list/pestkiller_reagents = list(
		"sugar" =           2,
		"diethylamine" =   -2,
		"adminordrazine" = -5
		)
	var/global/list/water_reagents = list(
		"water" =           1,
		"adminordrazine" =  1,
		"milk" =            0.9,
		"beer" =            0.7,
		"flourine" =       -0.5,
		"chlorine" =       -0.5,
		"phosphorus" =     -0.5,
		"water" =           1,
		"sodawater" =       1,
		)

	// Beneficial reagents also have values for modifying yield_mod and mut_mod (in that order).
	var/global/list/beneficial_reagents = list(
		"beer" =           list( -0.05, 0,   0   ),
		"fluorine" =       list( -2,    0,   0   ),
		"chlorine" =       list( -1,    0,   0   ),
		"phosphorus" =     list( -0.75, 0,   0   ),
		"sodawater" =      list(  0.1,  0,   0   ),
		"sacid" =          list( -1,    0,   0   ),
		"pacid" =          list( -2,    0,   0   ),
		"plantbgone" =     list( -2,    0,   0.2 ),
		"cryoxadone" =     list(  3,    0,   0   ),
		"ammonia" =        list(  0.5,  0,   0   ),
		"diethylamine" =   list(  1,    0,   0   ),
		"nutriment" =      list(  0.25,  0.15,   0   ),
		"radium" =         list( -1.5,  0,   0.2 ),
		"adminordrazine" = list(  1,    1,   1   ),
		"robustharvest" =  list(  0,    0.2, 0   ),
		"left4zed" =       list(  0,    0,   0.2 )
		)

	//--FalseIncarnate
	// Mutagen list specifies reagent_min_value and reagent_step
	// Reagent_min_value (value 1) is the minimum number of units needed to begin mutations
	// Reagent_step (value 2) is the number of units between each mutation threshold
	var/global/list/mutagenic_reagents = list(
		"radium" =  list(10,10),
		"mutagen" = list(1,5)
		)
	//--FalseIncarnate

/obj/machinery/portable_atmospherics/hydroponics/New()
	..()

	component_parts = list()
	component_parts += new /obj/item/weapon/circuitboard/hydroponics(src)
	component_parts += new /obj/item/weapon/stock_parts/matter_bin(src)
	component_parts += new /obj/item/weapon/stock_parts/matter_bin(src)
	component_parts += new /obj/item/weapon/stock_parts/console_screen(src)
	RefreshParts()

	create_reagents(200)
	connect()
	update_icon()
	if(closed_system)
		flags &= ~OPENCONTAINER

/obj/machinery/portable_atmospherics/hydroponics/upgraded/New()
	..()
	component_parts = list()
	component_parts += new /obj/item/weapon/circuitboard/hydroponics(src)
	component_parts += new /obj/item/weapon/stock_parts/matter_bin/super(src)
	component_parts += new /obj/item/weapon/stock_parts/matter_bin/super(src)
	component_parts += new /obj/item/weapon/stock_parts/console_screen(src)
	RefreshParts()

/obj/machinery/portable_atmospherics/hydroponics/RefreshParts()
	var/tmp_capacity = 0
	for (var/obj/item/weapon/stock_parts/matter_bin/M in component_parts)
		tmp_capacity += M.rating
	maxwater = tmp_capacity * 50 // Up to 300
	maxnutri = tmp_capacity * 5 // Up to 30
	//waterlevel = maxwater
	//nutrilevel = 3

/obj/machinery/portable_atmospherics/hydroponics/bullet_act(var/obj/item/projectile/Proj)

	//Don't act on seeds like dionaea that shouldn't change.
	if(seed && seed.immutable > 0)
		return

	//--FalseIncarnate
	//Override for somatoray projectiles, updated to work with new mutation rework
	if(istype(Proj ,/obj/item/projectile/energy/floramut))
		mutate("F1")
		return
	else if(istype(Proj ,/obj/item/projectile/energy/florayield))
		mutate("F2")
		return
	//--FalseIncarnate

	..()

/obj/machinery/portable_atmospherics/hydroponics/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if(air_group || (height==0)) return 1

	if(istype(mover) && mover.checkpass(PASSTABLE))
		return 1
	else
		return 0

/obj/machinery/portable_atmospherics/hydroponics/process()

	//Do this even if we're not ready for a plant cycle.
	process_reagents()

	// Update values every cycle rather than every process() tick.
	if(force_update)
		force_update = 0
	else if(world.time < (lastcycle + cycledelay))
		return
	lastcycle = world.time

	// Weeds like water and nutrients, there's a chance the weed population will increase.
	// Bonus chance if the tray is unoccupied.
	if(waterlevel > 10 && nutrilevel > 2 && prob(isnull(seed) ? 6 : 3))
		weedlevel += 1 * HYDRO_SPEED_MULTIPLIER

	// There's a chance for a weed explosion to happen if the weeds take over.
	// Plants that are themselves weeds (weed_tolernace > 10) are unaffected.
	if (weedlevel >= 10 && prob(10))
		if(!seed || weedlevel >= seed.weed_tolerance)
			weed_invasion()

	// If there is no seed data (and hence nothing planted),
	// or the plant is dead, process nothing further.
	if(!seed || dead)
		return

	// Advance plant age.
	if(prob(25)) age += 1 * HYDRO_SPEED_MULTIPLIER

	//Highly mutable plants have a chance of mutating every tick.
	if(seed.immutable == -1)
		var/mut_prob = rand(1,100)
		if(mut_prob <= 5) mutate(mut_prob == 1 ? 2 : 1)

	// Maintain tray nutrient and water levels.
	if(seed.nutrient_consumption > 0 && nutrilevel > 0 && prob(25))
		nutrilevel -= max(0,seed.nutrient_consumption * HYDRO_SPEED_MULTIPLIER)
	if(seed.water_consumption > 0 && waterlevel > 0  && prob(25))
		waterlevel -= max(0,seed.water_consumption * HYDRO_SPEED_MULTIPLIER)

	// Make sure the plant is not starving or thirsty. Adequate
	// water and nutrients will cause a plant to become healthier.
	var/healthmod = rand(1,3) * HYDRO_SPEED_MULTIPLIER
	if(seed.requires_nutrients && prob(35))
		health += (nutrilevel < 2 ? -healthmod : healthmod)
	if(seed.requires_water && prob(35))
		health += (waterlevel < 10 ? -healthmod : healthmod)

	// Check that pressure, heat and light are all within bounds.
	// First, handle an open system or an unconnected closed system.

	var/turf/T = loc
	var/datum/gas_mixture/environment

	// If we're closed, take from our internal sources.
	if(closed_system && (connected_port || holding))
		environment = air_contents

	// If atmos input is not there, grab from turf.
	if(!environment)
		if(istype(T))
			environment = T.return_air()

	if(!environment) return

/*
	// Handle gas consumption.
	if(seed.consume_gasses && seed.consume_gasses.len)
		var/missing_gas = 0
		for(var/gas in seed.consume_gasses)
			if(environment && environment.gas && environment.gas[gas] && \
			 environment.gas[gas] >= seed.consume_gasses[gas])
				environment.adjust_gas(gas,-seed.consume_gasses[gas],1)
			else
				missing_gas++

		if(missing_gas > 0)
			health -= missing_gas * HYDRO_SPEED_MULTIPLIER

	// Process it.
	var/pressure = environment.return_pressure()
	if(pressure < seed.lowkpa_tolerance || pressure > seed.highkpa_tolerance)
		health -= healthmod

	if(abs(environment.temperature - seed.ideal_heat) > seed.heat_tolerance)
		health -= healthmod

	// Handle gas production.
	if(seed.exude_gasses && seed.exude_gasses.len)
		for(var/gas in seed.exude_gasses)
			environment.adjust_gas(gas, max(1,round((seed.exude_gasses[gas]*seed.potency)/seed.exude_gasses.len)))

*/

	// Handle light requirements.
	var/area/A = T.loc
	if(A)
		var/light_available
		if(A.lighting_use_dynamic)
			light_available = max(0,min(10,T.lighting_lumcount)-5)
		else
			light_available =  5
		if(abs(light_available - seed.ideal_light) > seed.light_tolerance)
			health -= healthmod

	// Toxin levels beyond the plant's tolerance cause damage, but
	// toxins are sucked up each tick and slowly reduce over time.
	if(toxins > 0)
		var/toxin_uptake = max(1,round(toxins/10))
		if(toxins > seed.toxins_tolerance)
			health -= toxin_uptake
		toxins -= toxin_uptake

	// Check for pests and weeds.
	// Some carnivorous plants happily eat pests.
	if(pestlevel > 0)
		if(seed.carnivorous)
			health += HYDRO_SPEED_MULTIPLIER
			pestlevel -= HYDRO_SPEED_MULTIPLIER
		else if (pestlevel >= seed.pest_tolerance)
			health -= HYDRO_SPEED_MULTIPLIER

	// Some plants thrive and live off of weeds.
	if(weedlevel > 0)
		if(seed.parasite)
			health += HYDRO_SPEED_MULTIPLIER
			weedlevel -= HYDRO_SPEED_MULTIPLIER
		else if (weedlevel >= seed.weed_tolerance)
			health -= HYDRO_SPEED_MULTIPLIER

	// Handle life and death.
	// If the plant is too old, it loses health fast.
	if(age > seed.lifespan)
		health -= rand(3,5) * HYDRO_SPEED_MULTIPLIER

	// When the plant dies, weeds thrive and pests die off.
	if(health <= 0)
		dead = 1
		harvest = 0
		weedlevel += 1 * HYDRO_SPEED_MULTIPLIER
		pestlevel = 0

	// If enough time (in cycles, not ticks) has passed since the plant was harvested, we're ready to harvest again.
	else if(seed.products && seed.products.len && age > seed.production && \
	 (age - lastproduce) > seed.production && (!harvest && !dead))
		harvest = 1
		lastproduce = age

	if(prob(3))  // On each tick, there's a chance the pest population will increase
		pestlevel += 1 * HYDRO_SPEED_MULTIPLIER

	check_level_sanity()
	update_icon()
	return

//Process reagents being input into the tray.
/obj/machinery/portable_atmospherics/hydroponics/proc/process_reagents()

	if(!reagents) return

	if(reagents.total_volume <= 0)
		return

	for(var/datum/reagent/R in reagents.reagent_list)


		var/reagent_total = reagents.get_reagent_amount(R.id)

		if(seed && !dead)
			//Handle some general level adjustments.
			if(toxic_reagents[R.id])
				toxins += toxic_reagents[R.id]         * reagent_total
			if(weedkiller_reagents[R.id])
				weedlevel += weedkiller_reagents[R.id] * reagent_total
			if(pestkiller_reagents[R.id])
				pestlevel += pestkiller_reagents[R.id] * reagent_total

			// Beneficial reagents have a few impacts along with health buffs.
			if(beneficial_reagents[R.id])
				health += beneficial_reagents[R.id][1]       * reagent_total
				yield_mod = min(100, yield_mod + (beneficial_reagents[R.id][2]    * reagent_total))
				mutation_mod += beneficial_reagents[R.id][3] * reagent_total

			// Mutagen is distinct from the previous types and mostly has a chance of proccing a mutation.

			//--FalseIncarnate
			// Mutation rework, will now use "thresholds" for proccing types of mutations and their respective chances.
			// This should make it easier to avoid species shifts when trying to only affect stats like potency.
			// Additionally, the chance of mutations will vary depending on the amount of mutagenic reagents added.
			if(mutagenic_reagents[R.id])
				var/reagent_min_value = mutagenic_reagents[R.id][1]					//10 for radium, 1 for unstable mutagen
				var/reagent_step =     mutagenic_reagents[R.id][2]					//10 for radium, 5 for unstable mutagen

				if(reagent_total >= reagent_min_value + (3 * reagent_step))			//31+ for radium, 16+ for unstable mutagen
					mutate(4)
				else if(reagent_total >= reagent_min_value + (2 * reagent_step))	//21-30 for radium, 11-15 for unstable mutagen
					mutate(3)
				else if(reagent_total >= reagent_min_value + reagent_step)			//11-20 for radium, 6-10 for unstable mutagen
					mutate(2)
				else if(reagent_total >= reagent_min_value)							//1-10 for radium, 1-5 for unstable mutagen
					mutate(1)

			//--FalseIncarnate

		// Handle nutrient refilling
		if(nutrient_reagents[R.id])
			nutrilevel += nutrient_reagents[R.id]  * reagent_total

		// Handle water and water refilling.
		var/water_added = 0
		if(water_reagents[R.id])
			var/water_input = water_reagents[R.id] * reagent_total
			water_added += water_input
			waterlevel += water_input

		if(water_added > 0)
			toxins -= round(water_added/4)

	reagents.clear_reagents()
	check_level_sanity()
	update_icon()

//Harvests the product of a plant.
/obj/machinery/portable_atmospherics/hydroponics/proc/harvest(var/mob/user)

	//Harvest the product of the plant,
	if(!seed || !harvest || !user)
		return

	if(closed_system)
		user << "You can't harvest from the plant while the lid is shut."
		return

	seed.harvest(user,yield_mod)
	//Increases harvest count for round-end score
	//Currently per-plant (not per-item) harvested
	// --FalseIncarnate
	score_stuffharvested++

	// Reset values.
	harvest = 0
	lastproduce = age

	if(!seed.harvest_repeat)
		yield_mod = 0
		seed = null
		dead = 0
		age = 0

	check_level_sanity()
	update_icon()
	return

//Clears out a dead plant.
/obj/machinery/portable_atmospherics/hydroponics/proc/remove_dead(var/mob/user)
	if(!user || !dead) return

	if(closed_system)
		user << "You can't remove the dead plant while the lid is shut."
		return

	seed = null
	dead = 0
	user << "You remove the dead plant from the [src]."
	check_level_sanity()
	update_icon()
	return

//Refreshes the icon and sets the luminosity
/obj/machinery/portable_atmospherics/hydroponics/update_icon()

	overlays.Cut()

	// Updates the plant overlay.
	if(!isnull(seed))

		if(draw_warnings && health <= (seed.endurance / 2))
			overlays += "over_lowhealth3"

		if(dead)
			overlays += "[seed.plant_icon]-dead"
		else if(harvest)
			overlays += "[seed.plant_icon]-harvest"
		else if(age < seed.maturation)

			var/t_growthstate
			if(age >= seed.maturation)
				t_growthstate = seed.growth_stages
			else
				t_growthstate = round(seed.maturation / seed.growth_stages)

			overlays += "[seed.plant_icon]-grow[t_growthstate]"
			lastproduce = age
		else
			overlays += "[seed.plant_icon]-grow[seed.growth_stages]"

	//Draw the cover.
	if(closed_system)
		overlays += "hydrocover"

	//Updated the various alert icons.
	if(draw_warnings)
		if(waterlevel <= 10)
			overlays += "over_lowwater3"
		if(nutrilevel <= 2)
			overlays += "over_lownutri3"
		if(weedlevel >= 5 || pestlevel >= 5 || toxins >= 40)
			overlays += "over_alert3"
		if(harvest)
			overlays += "over_harvest3"

	// Update bioluminescence.
	if(seed)
		if(seed.biolum)
			SetLuminosity(round(seed.potency/10))
			if(seed.biolum_colour)
				l_color = seed.biolum_colour
			else
				l_color = null
			return

	SetLuminosity(0)
	return

 // If a weed growth is sufficient, this proc is called.
/obj/machinery/portable_atmospherics/hydroponics/proc/weed_invasion()

	//Remove the seed if something is already planted.
	if(seed) seed = null
	seed = seed_types[pick(list("reishi","nettles","amanita","mushrooms","plumphelmet","towercap","harebells","weeds"))]
	if(!seed) return //Weed does not exist, someone fucked up.

	dead = 0
	age = 0
	health = seed.endurance
	lastcycle = world.time
	harvest = 0
	weedlevel = 0
	pestlevel = 0
	update_icon()
	visible_message("\blue [src] has been overtaken by [seed.display_name].")

	return

/obj/machinery/portable_atmospherics/hydroponics/proc/check_level_sanity()
	//Make sure various values are sane.
	if(seed)
		health =     max(0,min(seed.endurance,health))
	else
		health = 0
		dead = 0

	nutrilevel = max(0,min(nutrilevel,maxnutri))
	waterlevel = max(0,min(waterlevel,maxwater))
	pestlevel =  max(0,min(pestlevel,10))
	weedlevel =  max(0,min(weedlevel,10))
	toxins =     max(0,min(toxins,10))

/obj/machinery/portable_atmospherics/hydroponics/proc/mutate(var/severity)

	// No seed, no mutations.
	if(!seed)
		return

	/*
	--FalseIncarnate
	New mutation system, now uses "Mutation Tiers" to adjust the chances of mutations
		Tier 1 has a low chance of causing a stat mutation
		Tier 2 has a higher chance of causing a stat mutation
		Tier 3 has a low chance of causing a species shift (if possible), and will ALWAYS cause a stat mutation if it does not shift species
		Tier 4 has a higher chance of causing a species shift (if possible), and will ALWAYS cause a stat mutation if it does not shift species
			Tier 4 also has a low chance to cause a SECOND stat mutation when it does not shift species
	All mutation chances are increased by the mutation_mod value. Mutation_mod is not transferred into seeds/harvests, and is reset when the plant dies

	*/

	switch(severity)
		//Reagent Tiers
		if(1)		//Tier 1
			if(prob(20+mutation_mod))							//Low chance of stat mutation
				if(!isnull(seed_types[seed.name]))
					seed = seed.diverge()
				seed.mutate(1,get_turf(src))
				return
		if(2)		//Tier 2
			if(prob(60+mutation_mod))							//Higher chance of stat mutation
				if(!isnull(seed_types[seed.name]))
					seed = seed.diverge()
				seed.mutate(1,get_turf(src))
				return
		if(3)		//Tier 3
			if(prob(20+mutation_mod))							//Low chance of species shift mutation
				if(seed.mutants. && seed.mutants.len)			//Check if current seed/plant has mutant species
					mutate_species()
				else											//No mutant species, mutate stats instead
					if(!isnull(seed_types[seed.name]))
						seed = seed.diverge()
					seed.mutate(1,get_turf(src))
				return
			else												//Failed to shift, mutate stats instead
				if(!isnull(seed_types[seed.name]))
					seed = seed.diverge()
				seed.mutate(1,get_turf(src))
				return
		if(4)		//Tier 4
			if(prob(60+mutation_mod))							//Higher chance of species shift mutation
				if(seed.mutants. && seed.mutants.len)			//Check if current seed/plant has mutant species
					mutate_species()
				else											//No mutant species, mutate stats instead
					if(!isnull(seed_types[seed.name]))
						seed = seed.diverge()
					seed.mutate(1,get_turf(src))
					if(prob(20+mutation_mod))					//Low chance for second stat mutation
						if(!isnull(seed_types[seed.name]))
							seed = seed.diverge()
						seed.mutate(1,get_turf(src))
				return
			else												//Failed to shift, mutate stats instead
				if(!isnull(seed_types[seed.name]))
					seed = seed.diverge()
				seed.mutate(1,get_turf(src))
				if(prob(20+mutation_mod))						//Low chance for second stat mutation
					if(!isnull(seed_types[seed.name]))
						seed = seed.diverge()
					seed.mutate(1,get_turf(src))
				return
		//Floral Somatoray Tiers
		if("F1")	//Random Stat Tier
			if(prob(80+mutation_mod))							//EVEN Higher chance of stat mutation
				if(!isnull(seed_types[seed.name]))
					seed = seed.diverge()
				seed.mutate(1,get_turf(src))
				return
		if("F2")	//Yield Tier
			if(prob(40+mutation_mod))							//Medium chance of Yield stat mutation
				if(!isnull(seed_types[seed.name]))
					seed = seed.diverge()
				if(seed.immutable <= 0 && seed.yield != -1)		//Check if the plant can be mutated and has a yield to mutate
					seed.yield = seed.yield + rand(-2, 2)		//Randomly adjust yield
					if(seed.yield < 0)							//If yield would drop below 0 after adjustment, set to 0 to allow further attempts
						seed.yield = 0
				return

	/* code references
	// We need to make sure we're not modifying one of the global seed datums.
	// If it's not in the global list, then no products of the line have been
	// harvested yet and it's safe to assume it's restricted to this tray.
	if(!isnull(seed_types[seed.name]))
		seed = seed.diverge()
	seed.mutate(severity,get_turf(src))
	*/

	//--FalseIncarnate

/obj/machinery/portable_atmospherics/hydroponics/proc/mutate_species()

	var/previous_plant = seed.display_name
	var/newseed = seed.get_mutant_variant()
	if(newseed in seed_types)
		seed = seed_types[newseed]
	else
		return

	dead = 0
	//mutate(1)
	age = 0
	health = seed.endurance
	lastcycle = world.time
	harvest = 0
	weedlevel = 0

	update_icon()
	visible_message("\red The \blue [previous_plant] \red has suddenly mutated into \blue [seed.display_name]!")

	return

/obj/machinery/portable_atmospherics/hydroponics/attackby(var/obj/item/O as obj, var/mob/user as mob, params)
	if(exchange_parts(user, O))
		return

	if(istype(O, /obj/item/weapon/crowbar))
		if(anchored==2)
			user << "Unscrew the hoses first!"
			return
		default_deconstruction_crowbar(O, 1)

	//--FalseIncarnate
	//Check if held item is an open container
	if (O.is_open_container())
		//Check if container is of the "glass" subtype (includes buckets, beakers, vials)
		if(istype(O, /obj/item/weapon/reagent_containers/glass))
			var/obj/item/weapon/reagent_containers/glass/C = O
			//Check if container is empty
			if(!C.reagents.total_volume)
				user << "\red [C] is empty."
				return
			//Container not empty, transfer contents to tray
			var/trans = C.reagents.trans_to(src, C.amount_per_transfer_from_this)
			user << "\blue You transfer [trans] units of the solution to [src]."

			check_level_sanity()
			process_reagents()
			update_icon()

		//Check if container is one of the botany sprays (defined in hydro_tools.dm)
		else if(istype(O, /obj/item/weapon/plantspray))
			//Check if spray is pest-spray
			if(istype(O, /obj/item/weapon/plantspray/pests))
				var/obj/item/weapon/plantspray/P = O
				user.drop_item(O)
				toxins += P.toxicity
				pestlevel -= P.pest_kill_str
				weedlevel -= P.weed_kill_str
				user << "You spray [src] with [O]."
				playsound(loc, 'sound/effects/spray3.ogg', 50, 1, -6)
				del(O)

				check_level_sanity()
				update_icon()

			//Check if spray is weed-spray (un-obtainable, fixed for possible repurposing?)
			else if(istype(O, /obj/item/weapon/plantspray/weeds))
				var/obj/item/weapon/plantspray/W = O
				user.drop_item(O)
				toxins += W.toxicity
				pestlevel -= W.pest_kill_str
				weedlevel -= W.weed_kill_str
				user << "You spray [src] with [O]."
				playsound(loc, 'sound/effects/spray3.ogg', 50, 1, -6)
				del(O)

				check_level_sanity()
				update_icon()

		//Check if container is any spray container
		else if (istype(O, /obj/item/weapon/reagent_containers/spray))
			var/obj/item/weapon/reagent_containers/spray/S = O
			//Check if there is a plant in the tray
			if(seed)
				if(!S.reagents.total_volume)
					user << "\red [S] is empty."
					return
				//Container not empty, transfer contents to tray
				S.reagents.trans_to(src, S.amount_per_transfer_from_this)
				visible_message("\red <B>\The [src] has been sprayed with \the [O][(user ? " by [user]." : ".")]")
				playsound(loc, 'sound/effects/spray3.ogg', 50, 1, -6)
				check_level_sanity()
				update_icon()
			else
				user << "There's nothing in [src] to spray!"

	else if(istype(O, /obj/item/weapon/screwdriver) && unwrenchable) //THIS NEED TO BE DONE DIFFERENTLY, SOMEONE REFACTOR THE TRAY CODE ALREADY
		if(anchored)
			if(anchored == 2)
				playsound(src.loc, 'sound/items/Screwdriver.ogg', 50, 1)
				anchored = 1
				user << "You unscrew the [src]'s hoses."
				panel_open = 0

			else if(anchored == 1)
				playsound(src.loc, 'sound/items/Screwdriver.ogg', 50, 1)
				anchored = 2
				user << "You screw in the [src]'s hoses."
				panel_open = 1

			for(var/obj/machinery/portable_atmospherics/hydroponics/h in range(1,src))
				spawn()
					h.update_icon()

	//Held item is not an open container, check to see if it can be used (this code was already here) --FalseIncarnate
	if(istype(O, /obj/item/weapon/wirecutters) || istype(O, /obj/item/weapon/scalpel))

		if(!seed)
			user << "There is nothing to take a sample from in \the [src]."
			return

		seed.harvest(user,yield_mod,1)
		health -= (rand(1,5)*10)
		check_level_sanity()

		force_update = 1
		process()

		return

	else if(istype(O, /obj/item/weapon/reagent_containers/syringe))

		var/obj/item/weapon/reagent_containers/syringe/S = O

		if (S.mode == 1)
			if(seed)
				return ..()
			else
				user << "There's no plant in the tray to inject."
				return 1
		else
			if(seed)
				//Leaving this in in case we want to extract from plants later.
				user << "You can't get any extract out of this plant."
			else
				user << "There's nothing in the tray to draw something from."
			return 1

	else if (istype(O, /obj/item/seeds))

		if(!seed)

			var/obj/item/seeds/S = O
			user.drop_item(O)

			if(!S.seed)
				user << "The packet seems to be empty. You throw it away."
				del(O)
				return

			user << "You plant the [S.seed.seed_name] [S.seed.seed_noun]."

			if(S.seed.spread == 1)
				msg_admin_attack("[key_name(user)] has planted a creeper packet.")
				var/obj/effect/plant_controller/creeper/PC = new(get_turf(src))
				if(PC)
					PC.seed = S.seed
			else if(S.seed.spread == 2)
				msg_admin_attack("[key_name(user)] has planted a spreading vine packet.")
				var/obj/effect/plant_controller/PC = new(get_turf(src))
				if(PC)
					PC.seed = S.seed
			else
				seed = S.seed //Grab the seed datum.
				dead = 0
				age = 1
				//Snowflakey, maybe move this to the seed datum
				health = (istype(S, /obj/item/seeds/cutting) ? round(seed.endurance/rand(2,5)) : seed.endurance)

				lastcycle = world.time

			del(O)

			check_level_sanity()
			update_icon()

		else
			user << "\red \The [src] already has seeds in it!"

	else if (istype(O, /obj/item/weapon/minihoe))  // The minihoe
		//var/deweeding
		if(weedlevel > 0)
			user.visible_message("\red [user] starts uprooting the weeds.", "\red You remove the weeds from the [src].")
			weedlevel = 0
			update_icon()
		else
			user << "\red This plot is completely devoid of weeds. It doesn't need uprooting."

	else if (istype(O, /obj/item/weapon/storage/bag/plants))

		attack_hand(user)

		var/obj/item/weapon/storage/bag/plants/S = O
		for (var/obj/item/weapon/reagent_containers/food/snacks/grown/G in locate(user.x,user.y,user.z))
			if(!S.can_be_inserted(G))
				return
			S.handle_item_insertion(G, 1)

	else if(istype(O, /obj/item/weapon/wrench))

		//If there's a connector here, the portable_atmospherics setup can handle it.
		if(locate(/obj/machinery/atmospherics/portables_connector/) in loc)
			return ..()

		playsound(loc, 'sound/items/Ratchet.ogg', 50, 1)
		anchored = !anchored
		user << "You [anchored ? "wrench" : "unwrench"] \the [src]."

	else if(istype(O, /obj/item/apiary))

		if(seed)
			user << "\red [src] is already occupied!"
		else
			user.drop_item()
			del(O)

			var/obj/machinery/apiary/A = new(src.loc)
			A.icon = src.icon
			A.icon_state = src.icon_state
			A.hydrotray_type = src.type
			del(src)
	return

/obj/machinery/portable_atmospherics/hydroponics/attack_tk(mob/user as mob)

	if(harvest)
		harvest(user)

	else if(dead)
		remove_dead(user)

/obj/machinery/portable_atmospherics/hydroponics/attack_hand(mob/user as mob)

	if(istype(usr,/mob/living/silicon))
		return

	if(harvest)
		harvest(user)
	else if(dead)
		remove_dead(user)

	else
		if(seed && !dead)
			usr << "[src] has \blue [seed.display_name] \black planted."
			if(health <= (seed.endurance / 2))
				usr << "The plant looks \red unhealthy."
		else
			usr << "[src] is empty."
		usr << "Water: [round(waterlevel,0.1)]/100"
		usr << "Nutrient: [round(nutrilevel,0.1)]/10"
		if(weedlevel >= 5)
			usr << "[src] is \red filled with weeds!"
		if(pestlevel >= 5)
			usr << "[src] is \red filled with tiny worms!"

		if(!istype(src,/obj/machinery/portable_atmospherics/hydroponics/soil))

			var/turf/T = loc
			var/datum/gas_mixture/environment

			if(closed_system && (connected_port || holding))
				environment = air_contents

			if(!environment)
				if(istype(T))
					environment = T.return_air()

			if(!environment) //We're in a crate or nullspace, bail out.
				return

			var/area/A = T.loc
			var/light_available
			if(A)
				if(A.lighting_use_dynamic)
					light_available = max(0,min(10,T.lighting_lumcount)-5)
				else
					light_available =  5

			usr << "The tray's sensor suite is reporting a light level of [light_available] lumens and a temperature of [environment.temperature]K."

/obj/machinery/portable_atmospherics/hydroponics/verb/close_lid()
	set name = "Toggle Tray Lid"
	set category = "Object"
	set src in view(1)

	if(!usr || usr.stat || usr.restrained())
		return

	closed_system = !closed_system
	usr << "You [closed_system ? "close" : "open"] the tray's lid."
	if(closed_system)
		flags &= ~OPENCONTAINER
	else
		flags |= OPENCONTAINER

	update_icon()

/obj/machinery/portable_atmospherics/hydroponics/soil
	name = "soil"
	icon = 'icons/obj/hydroponics.dmi'
	icon_state = "soil"
	density = 0
	use_power = 0
	draw_warnings = 0

/obj/machinery/portable_atmospherics/hydroponics/soil/attackby(var/obj/item/O as obj, var/mob/user as mob, params)
	if(istype(O, /obj/item/weapon/shovel))
		user << "You clear up [src]!"
		del(src)
	else if(istype(O,/obj/item/weapon/shovel) || istype(O,/obj/item/weapon/tank))
		return
	else
		..()

/obj/machinery/portable_atmospherics/hydroponics/soil/New()
	..()
	verbs -= /obj/machinery/portable_atmospherics/hydroponics/verb/close_lid

#undef HYDRO_SPEED_MULTIPLIER
