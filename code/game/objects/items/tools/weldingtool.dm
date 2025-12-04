/// MARK: BASE WELDER
/obj/item/weldingtool
	name = "abstract welding tool"
	desc = "REPORT TO CODERS IF YOU SEE THIS SHIT!"
	icon = 'icons/obj/tools.dmi'
	lefthand_file = 'icons/mob/inhands/equipment/tools_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/tools_righthand.dmi'
	obj_flags = CONDUCTS_ELECTRICITY
	slot_flags = ITEM_SLOT_BELT
	force = 3
	throwforce = 5
	hitsound = SFX_SWING_HIT
	drop_sound = 'sound/items/handling/tools/weldingtool_drop.ogg'
	pickup_sound = 'sound/items/handling/tools/weldingtool_pickup.ogg'
	throw_speed = 3
	throw_range = 5
	light_range = 2
	w_class = WEIGHT_CLASS_NORMAL
	armor_type = /datum/armor/item_weldingtool
	resistance_flags = FIRE_PROOF
	heat = 3800
	tool_behaviour = TOOL_WELDER
	toolspeed = 1
	wound_bonus = 10
	exposed_wound_bonus = 15
	custom_materials = list(/datum/material/iron=SMALL_MATERIAL_AMOUNT*0.7, /datum/material/glass=SMALL_MATERIAL_AMOUNT*0.3)
	/// Whether the welding tool is on or off.
	var/welding = FALSE
	/// Used in process(), dictates whether or not we're calling STOP_PROCESSING whilst we're not welding.
	var/can_off_process = FALSE
	var/emits_light = TRUE
	var/activation_sound
	var/deactivation_sound

/datum/armor/item_weldingtool
	fire = 100
	acid = 30

/// Toggles the welding value.
/obj/item/weldingtool/proc/set_welding(new_value)
	if(welding == new_value)
		return
	. = welding
	welding = new_value
	if(emits_light)
		set_light_on(welding)

/// Switches the welder off
/obj/item/weldingtool/proc/switched_off(mob/user)
	set_welding(FALSE)

	force = 3
	damtype = BRUTE
	hitsound = SFX_SWING_HIT
	update_appearance()

/// Returns whether or not the welding tool is currently on.
/obj/item/weldingtool/proc/isOn()
	return welding

/obj/item/weldingtool/use_tool(atom/target, mob/living/user, delay, amount, volume, datum/callback/extra_checks)
	var/mutable_appearance/sparks = mutable_appearance('icons/effects/welding_effect.dmi', "welding_sparks", GASFIRE_LAYER, src, ABOVE_LIGHTING_PLANE)
	target.add_overlay(sparks)
	LAZYADD(target.update_overlays_on_z, sparks)
	. = ..()
	LAZYREMOVE(target.update_overlays_on_z, sparks)
	target.cut_overlay(sparks)

/obj/item/weldingtool/get_temperature()
	return welding * heat

/obj/item/weldingtool/proc/try_heal_loop(atom/interacting_with, mob/living/user, repeating = FALSE)
	var/mob/living/carbon/human/attacked_humanoid = interacting_with
	var/obj/item/bodypart/affecting = attacked_humanoid.get_bodypart(check_zone(user.zone_selected))
	if(isnull(affecting) || !IS_ROBOTIC_LIMB(affecting))
		return NONE

	if (!affecting.brute_dam)
		balloon_alert(user, "limb not damaged")
		return ITEM_INTERACT_BLOCKING

	user.visible_message(span_notice("[user] starts to fix some of the dents on [attacked_humanoid == user ? user.p_their() : "[attacked_humanoid]'s"] [affecting.name]."),
		span_notice("You start fixing some of the dents on [attacked_humanoid == user ? "your" : "[attacked_humanoid]'s"] [affecting.name]."))
	var/use_delay = repeating ? 1 SECONDS : 0
	if(user == attacked_humanoid)
		use_delay = 5 SECONDS

	if(!use_tool(attacked_humanoid, user, use_delay, volume=50, amount=1))
		return ITEM_INTERACT_BLOCKING

	if (!attacked_humanoid.item_heal(user, brute_heal = 15, burn_heal = 0, heal_message_brute = "dents", heal_message_burn = "burnt wires", required_bodytype = BODYTYPE_ROBOTIC))
		return ITEM_INTERACT_BLOCKING

	INVOKE_ASYNC(src, PROC_REF(try_heal_loop), interacting_with, user, TRUE)
	return ITEM_INTERACT_SUCCESS

/// MARK: FUELED WELDERS
/obj/item/weldingtool/fueled
	name = "welding torch"
	desc = "A standard edition welding torch with a port for attaching fuel tanks."
	icon_state = "welder"
	inhand_icon_state = "welder"
	worn_icon_state = "welder"
	usesound = 'sound/items/tools/welder.ogg'
	light_system = OVERLAY_LIGHT
	light_power = 1.5
	light_color = LIGHT_COLOR_FIRE
	light_on = FALSE
	/// Whether or not we're changing the icon based on fuel left.
	var/change_icons = TRUE
	/// Whether the welder is secured or unsecured (able to attach rods to it to make a flamethrower)
	var/status = TRUE
	/// TRUE if using interchangeable fuel tanks, FALSE if using integrated fuel storage
	var/integrated_tank = FALSE
	/// Where the fuel is stored.
	var/obj/item/welder_tank/inserted_tank = /obj/item/welder_tank
	/// When fuel was last removed.
	var/burned_fuel_for = 0
	/// TRUE if need oxygen to weld
	var/need_oxygen = TRUE

	activation_sound = 'sound/items/tools/welderactivate.ogg'
	deactivation_sound = 'sound/items/tools/welderdeactivate.ogg'

/obj/item/weldingtool/fueled/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/update_icon_updates_onmob)
	AddElement(/datum/element/tool_flash, light_range)
	AddElement(/datum/element/falling_hazard, damage = force, wound_bonus = wound_bonus, hardhat_safety = TRUE, crushes = FALSE, impact_sound = hitsound)

	if(ispath(inserted_tank))
		inserted_tank = new inserted_tank

	update_appearance()
	register_context()

/obj/item/weldingtool/fueled/add_context(atom/source, list/context, obj/item/held_item, mob/living/user)
	if(inserted_tank)
		context[SCREENTIP_CONTEXT_RMB] = "Remove tank"
	else if(istype(held_item, /obj/item/welder_tank))
		context[SCREENTIP_CONTEXT_LMB] = "Insert tank"
	return CONTEXTUAL_SCREENTIP_SET

/obj/item/weldingtool/fueled/update_icon_state()
	if(welding)
		inhand_icon_state = "[initial(inhand_icon_state)]1"
	else
		inhand_icon_state = "[initial(inhand_icon_state)]"
	return ..()

/obj/item/weldingtool/fueled/update_overlays()
	. = ..()
	if(change_icons)
		if(!inserted_tank)
			. += "[initial(icon_state)][0]"
		else
			var/ratio = inserted_tank.get_fuel() / inserted_tank.max_fuel
			ratio = CEILING(ratio*4, 1) * 25
			. += "[initial(icon_state)][ratio]"
	if(welding)
		. += "[initial(icon_state)]-on"

	if(inserted_tank && !integrated_tank)
		var/inserted_tank_state = inserted_tank.icon_state
		. += "[initial(icon_state)]-[inserted_tank_state]"

/// Checks that we have enough oxygen to weld
/obj/item/weldingtool/fueled/proc/check_oxydizer()
	var/datum/gas_mixture/air = return_air()
	if(!isnull(air) && (air.has_gas(/datum/gas/oxygen, 1) || air.has_gas(/datum/gas/nitrous_oxide, 1)))
		return TRUE

/obj/item/weldingtool/fueled/process(seconds_per_tick)
	if(welding)
		force = 15
		damtype = BURN
		burned_fuel_for += seconds_per_tick
		if(need_oxygen && !check_oxydizer(src.loc))
			switched_off()
		if(burned_fuel_for >= TOOL_FUEL_BURN_INTERVAL)
			use(TRUE)
		update_appearance()

	//Welders left on now use up fuel, but lets not have them run out quite that fast
	else
		force = 3
		damtype = BRUTE
		update_appearance()
		if(!can_off_process)
			STOP_PROCESSING(SSobj, src)
		return

	//This is to start fires. process() is only called if the welder is on.
	open_flame()

/obj/item/weldingtool/fueled/suicide_act(mob/living/user)
	user.visible_message(span_suicide("[user] welds [user.p_their()] every orifice closed! It looks like [user.p_theyre()] trying to commit suicide!"))
	return FIRELOSS

/obj/item/weldingtool/fueled/screwdriver_act(mob/living/user, obj/item/tool)
	flamethrower_screwdriver(tool, user)
	return ITEM_INTERACT_SUCCESS

/obj/item/weldingtool/fueled/attackby(obj/item/tool, mob/user, list/modifiers, list/attack_modifiers)
	if(istype(tool, /obj/item/stack/rods))
		if(inserted_tank)
			to_chat(user, span_warning("\The [src] has a tank attached - remove it first."))
			return TRUE
		flamethrower_rods(tool, user)
	if(!integrated_tank)
		if(istype(tool, /obj/item/welder_tank))
			if(inserted_tank)
				to_chat(user, span_warning("\The [src] already has a tank attached - remove it first."))
				return TRUE
			inserted_tank = tool
			balloon_alert(user, "inserted tank")
			user.transferItemToLoc(tool, src)
			playsound(src, 'sound/items/tools/weldertank_insert.ogg', 25, 1)
			update_icon()
			return TRUE
	else
		. = ..()
	update_appearance()

/obj/item/weldingtool/fueled/proc/explode()
	var/plasmaAmount = inserted_tank.reagents.get_reagent_amount(/datum/reagent/toxin/plasma)
	dyn_explosion(src, plasmaAmount/5, explosion_cause = src) // 20 plasma in a standard welder has a 4 power explosion. no breaches, but enough to kill/dismember holder
	QDEL_NULL(inserted_tank)
	qdel(src)

/obj/item/weldingtool/fueled/cyborg_unequip(mob/user)
	if(!isOn())
		return
	switched_on(user)

/obj/item/weldingtool/fueled/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!status && interacting_with.is_refillable())
		inserted_tank.reagents.trans_to(interacting_with, inserted_tank.reagents.total_volume, transferred_by = user)
		to_chat(user, span_notice("You empty [src]'s fuel tank into [interacting_with]."))
		update_appearance()
		return ITEM_INTERACT_SUCCESS

	if(!ishuman(interacting_with))
		return NONE

	if(user.combat_mode)
		return NONE

	return try_heal_loop(interacting_with, user)

/obj/item/weldingtool/fueled/attack_hand_secondary(mob/user as mob)
	. = ..()
	if(. == SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN)
		return
	if(!inserted_tank)
		return
	if(integrated_tank)
		return
	else
		if(welding)
			to_chat(user, span_danger("Turn off the welder first!"))
			return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN
		else
			balloon_alert(user, "removed tank")
			user.put_in_hands(inserted_tank)
			inserted_tank = NONE
			playsound(src, 'sound/items/tools/weldertank_remove.ogg', 25, 1)
			update_icon()

	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

/obj/item/weldingtool/fueled/afterattack(atom/target, mob/user, list/modifiers, list/attack_modifiers)
	if(!isOn())
		return
	use(1)
	var/turf/location = get_turf(user)
	location.hotspot_expose(700, 50, 1)
	if(QDELETED(target) || !isliving(target)) // can't ignite something that doesn't exist
		return
	var/mob/living/attacked_mob = target
	if(attacked_mob.ignite_mob())
		message_admins("[ADMIN_LOOKUPFLW(user)] set [key_name_admin(attacked_mob)] on fire with [src] at [AREACOORD(user)]")
		user.log_message("set [key_name(attacked_mob)] on fire with [src].", LOG_ATTACK)

/obj/item/weldingtool/fueled/attack_self(mob/user)
	if(!inserted_tank)
		balloon_alert(user, "no tank!")
		return
	if(need_oxygen && !check_oxydizer(user)) //torches need oxygen
		return
	if(inserted_tank && !inserted_tank.reagents)
		balloon_alert(user, "no fuel!")
		return
	if(inserted_tank.reagents.has_reagent(/datum/reagent/toxin/plasma))
		message_admins("[ADMIN_LOOKUPFLW(user)] activated a rigged welder at [AREACOORD(user)].")
		user.log_message("activated a rigged welder", LOG_VICTIM)
		explode()
		return

	switched_on(user)
	update_appearance()

/// Uses fuel from the welding tool.
/obj/item/weldingtool/fueled/use(used = 0)
	if(!isOn() || !check_fuel())
		return FALSE

	if(used > 0)
		burned_fuel_for = 0

	if(inserted_tank.get_fuel() >= used)
		inserted_tank.reagents.remove_reagent(/datum/reagent/fuel, used)
		check_fuel()
		return TRUE
	else
		return FALSE

/// Turns off the welder if there is no more fuel (does this really need to be its own proc?)
/obj/item/weldingtool/fueled/proc/check_fuel(mob/user)
	if(inserted_tank.get_fuel() <= 0 && welding)
		set_light_on(FALSE)
		switched_on(user)
		update_appearance()
		return FALSE
	return TRUE

// /Switches the welder on
/obj/item/weldingtool/fueled/proc/switched_on(mob/user)
	if(!status)
		balloon_alert(user, "unsecured!")
		return
	set_welding(!welding)
	if(welding)
		if(inserted_tank.get_fuel() >= 1)
			playsound(loc, activation_sound, 50, TRUE)
			force = 15
			damtype = BURN
			hitsound = 'sound/items/tools/welder.ogg'
			update_appearance()
			START_PROCESSING(SSobj, src)
		else
			balloon_alert(user, "no fuel!")
			switched_off(user)
	else
		playsound(loc, deactivation_sound, 50, TRUE)
		switched_off(user)

/obj/item/weldingtool/fueled/examine(mob/user)
	. = ..()
	if(inserted_tank)
		. += "It contains [inserted_tank.get_fuel()] unit\s of fuel out of [inserted_tank.max_fuel]."

/// If welding tool ran out of fuel during a construction task, construction fails.
/obj/item/weldingtool/fueled/tool_use_check(mob/living/user, amount, heat_required)
	if(!isOn() || !check_fuel())
		to_chat(user, span_warning("[src] has to be on to complete this task!"))
		return FALSE
	if(inserted_tank.get_fuel() < amount)
		to_chat(user, span_warning("You need more welding fuel to complete this task!"))
		return FALSE
	if(heat < heat_required)
		to_chat(user, span_warning("[src] is not hot enough to complete this task!"))
		return FALSE
	return TRUE

/obj/item/weldingtool/fueled/ignition_effect(atom/ignitable_atom, mob/user)
	if(use_tool(ignitable_atom, user, 0))
		return span_rose("[user] casually lights [ignitable_atom] with [src], what a badass.")
	else
		return ""

/obj/item/weldingtool/fueled/empty
	inserted_tank = NONE

/// LARGETANK WELDER
/obj/item/weldingtool/fueled/largetank
	inserted_tank = /obj/item/welder_tank/large

/// BORGIE WELDER
/obj/item/weldingtool/fueled/cyborg
	name = "integrated welding torch"
	desc = "An advanced welder designed to be used in robotic systems. Custom framework doubles the speed of welding."
	icon = 'icons/obj/items_cyborg.dmi'
	icon_state = "indwelder_cyborg"
	toolspeed = 0.5
	integrated_tank = TRUE

/// MINI WELDER
/obj/item/weldingtool/fueled/mini
	name = "emergency welding torch"
	desc = "A miniature welder used during emergencies."
	icon_state = "miniwelder"
	w_class = WEIGHT_CLASS_TINY
	custom_materials = list(/datum/material/iron=SMALL_MATERIAL_AMOUNT*0.3, /datum/material/glass=SMALL_MATERIAL_AMOUNT*0.1)
	change_icons = TRUE
	inserted_tank = /obj/item/welder_tank/mini
	integrated_tank = TRUE

/obj/item/weldingtool/fueled/mini/flamethrower_screwdriver()
	return

/obj/item/weldingtool/fueled/mini/empty
	inserted_tank = /obj/item/welder_tank/mini/empty

/// ALIEN WELDER
/obj/item/weldingtool/fueled/abductor
	name = "alien welding torch"
	desc = "An alien welding tool. Whatever fuel it uses, it can weld without oxygen and never runs out."
	icon = 'icons/obj/antags/abductor.dmi'
	icon_state = "welder"
	toolspeed = 0.1
	custom_materials = list(/datum/material/iron =SHEET_MATERIAL_AMOUNT * 2.5, /datum/material/silver = SHEET_MATERIAL_AMOUNT*1.25, /datum/material/plasma =SHEET_MATERIAL_AMOUNT * 2.5, /datum/material/titanium =SHEET_MATERIAL_AMOUNT, /datum/material/diamond =SHEET_MATERIAL_AMOUNT)
	light_system = NO_LIGHT_SUPPORT
	light_range = 0
	change_icons = FALSE
	inserted_tank = /obj/item/welder_tank/mini
	integrated_tank = TRUE
	need_oxygen = FALSE

/obj/item/weldingtool/fueled/abductor/process()
	if(inserted_tank)
		if(inserted_tank.get_fuel() <= inserted_tank.max_fuel)
			inserted_tank.reagents.add_reagent(/datum/reagent/fuel, 1)
	..()

/// RND WELDER
/obj/item/weldingtool/fueled/experimental
	name = "experimental welding torch"
	desc = "An experimental welder capable of self-fuel generation and less harmful to the eyes."
	icon_state = "exwelder"
	inhand_icon_state = "exwelder"
	custom_materials = list(/datum/material/iron =HALF_SHEET_MATERIAL_AMOUNT, /datum/material/glass = SMALL_MATERIAL_AMOUNT*5, /datum/material/plasma =HALF_SHEET_MATERIAL_AMOUNT*1.5, /datum/material/uranium =SMALL_MATERIAL_AMOUNT * 2)
	change_icons = FALSE
	can_off_process = TRUE
	light_range = 1
	w_class = WEIGHT_CLASS_NORMAL
	toolspeed = 0.5
	inserted_tank = /obj/item/welder_tank/mini
	integrated_tank = TRUE
	var/last_gen = 0
	var/nextrefueltick = 0

/obj/item/weldingtool/fueled/experimental/process()
	..()
	if(inserted_tank)
		if(inserted_tank.get_fuel() < inserted_tank.max_fuel && nextrefueltick < world.time)
			nextrefueltick = world.time + 10
			inserted_tank.reagents.add_reagent(/datum/reagent/fuel, 1)

/// BIG WELDER
/// Mostly used for flamethrower crafting
/obj/item/weldingtool/fueled/big
	name = "industrial welding torch"
	desc = "An industrial-grade fueled welder, trades all compactness for unparalleled welding speed."
	icon_state = "bigwelder"
	inhand_icon_state = "bigwelder"
	custom_materials = list(/datum/material/iron=SMALL_MATERIAL_AMOUNT*2.8, /datum/material/glass=SMALL_MATERIAL_AMOUNT*1.2)
	change_icons = FALSE
	w_class = WEIGHT_CLASS_BULKY
	toolspeed = 0.5
	inserted_tank = /obj/item/welder_tank/large

/// Ran when the welder is attacked by a screwdriver.
/obj/item/weldingtool/fueled/big/proc/flamethrower_screwdriver(obj/item/tool, mob/user)
	if(inserted_tank)
		to_chat(user, span_warning("Remove fuel tank first!"))
		return
	if(welding)
		to_chat(user, span_warning("Turn it off first!"))
		return
	status = !status
	if(status)
		to_chat(user, span_notice("You resecure [src] and close the fuel tank."))
		reagents.flags &= ~(OPENCONTAINER)
	else
		to_chat(user, span_notice("[src] can now be attached, modified, and refuelled."))
		reagents.flags |= OPENCONTAINER
	add_fingerprint(user)

/// First step of building a flamethrower (when a welder is attacked by rods)
/obj/item/weldingtool/fueled/big/proc/flamethrower_rods(obj/item/tool, mob/user)
	if(!status)
		var/obj/item/stack/rods/used_rods = tool
		if (used_rods.use(1))
			var/obj/item/flamethrower/flamethrower_frame = new /obj/item/flamethrower(user.loc)
			if(!remove_item_from_storage(flamethrower_frame, user))
				user.transferItemToLoc(src, flamethrower_frame, TRUE)
			flamethrower_frame.weldtool = src
			add_fingerprint(user)
			to_chat(user, span_notice("You add a rod to a welder, starting to build a flamethrower."))
			user.put_in_hands(flamethrower_frame)
		else
			to_chat(user, span_warning("You need one rod to start building a flamethrower!"))

/// MARK: WELDING TANKS
/obj/item/welder_tank
	name = "\improper welding cartridge"
	desc = "An interchangeable fuel tank meant for a welding torch."
	icon = 'icons/obj/tools.dmi'
	icon_state = "weldertank"
	pickup_sound = 'sound/items/handling/grenade/grenade_pick_up.ogg'
	drop_sound = 'sound/items/handling/grenade/grenade_drop.ogg'
	w_class = WEIGHT_CLASS_SMALL
	force = 5
	throwforce = 5
	custom_materials = list(/datum/material/iron =SHEET_MATERIAL_AMOUNT * 0.25)
	custom_price = PAYCHECK_CREW * 0.5
	var/max_fuel = 20

/obj/item/welder_tank/Initialize()
	create_reagents(max_fuel)
	reagents.add_reagent(/datum/reagent/fuel, max_fuel)
	. = ..()

/obj/item/welder_tank/proc/get_fuel()
	return reagents.get_reagent_amount(/datum/reagent/fuel) + reagents.get_reagent_amount(/datum/reagent/toxin/plasma)

/obj/item/welder_tank/examine(mob/user)
	. = ..()
	. += "It contains [get_fuel()] unit\s of fuel out of [max_fuel]."

/obj/item/welder_tank/empty/Initialize()
	. = ..()
	create_reagents(max_fuel)

/// LARGE
/obj/item/welder_tank/large
	name = "\improper extended welding cartridge"
	icon_state = "weldertank_large"
	max_fuel = 40
	custom_materials = list(/datum/material/iron =SHEET_MATERIAL_AMOUNT * 0.5)
	custom_price = PAYCHECK_CREW * 1

/obj/item/welder_tank/large/empty/Initialize()
	. = ..()
	create_reagents(max_fuel)

/// MINI
/obj/item/welder_tank/mini
	name = "integrated welding mini cartridge"
	desc = "You shouldn't see this shit, report to coders."
	max_fuel = 10

/obj/item/welder_tank/mini/empty/Initialize()
	. = ..()
	create_reagents(max_fuel)

/// INF
/obj/item/welder_tank/infinite
	name = "integrated welding infinite cartridge"
	desc = "You shouldn't see this shit, report to coders."
	max_fuel = INFINITY


/// MARK: ELECTRIC WELDERS
/obj/item/weldingtool/electric
	name = "arc welder"
	desc = "A welding tool capable of welding functionality through the use of electricity, has a port for inserting power cells."
	icon_state = "elwelder"
	emits_light = FALSE
	toolspeed = 2
	usesound = 'sound/items/tools/welder2.ogg'
	var/obj/item/stock_parts/power_store/cell/inserted_cell = /obj/item/stock_parts/power_store/cell
	var/power_use_amount = STANDARD_CELL_CHARGE * 0.2
	/// List of cells we dont want to be insertable in welders
	var/static/list/prohibited_cells

/obj/item/weldingtool/electric/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/update_icon_updates_onmob)
	AddElement(/datum/element/tool_flash, light_range)
	AddElement(/datum/element/falling_hazard, damage = force, wound_bonus = wound_bonus, hardhat_safety = TRUE, crushes = FALSE, impact_sound = hitsound)

	if(ispath(inserted_cell))
		inserted_cell = new inserted_cell

	if(!prohibited_cells)
		prohibited_cells = typecacheof(list(
			/obj/item/stock_parts/power_store/cell/crap,
			/obj/item/stock_parts/power_store/cell/secborg,
			/obj/item/stock_parts/power_store/cell/mini_egun,
			/obj/item/stock_parts/power_store/cell/hos_gun,
			/obj/item/stock_parts/power_store/cell/pulse,
			/obj/item/stock_parts/power_store/cell/ethereal,
			/obj/item/stock_parts/power_store/cell/crystal_cell,
			/obj/item/stock_parts/power_store/cell/emergency_light,
		))

	update_appearance()
	register_item_context()
	register_context()

/obj/item/weldingtool/electric/add_context(atom/source, list/context, obj/item/held_item, mob/living/user)
	if(inserted_cell)
		context[SCREENTIP_CONTEXT_RMB] = "Remove cell"
	else if(istype(held_item, /obj/item/stock_parts/power_store/cell))
		context[SCREENTIP_CONTEXT_LMB] = "Insert cell"
	return CONTEXTUAL_SCREENTIP_SET

/obj/item/weldingtool/electric/examine()
	. = ..()
	if(inserted_cell)
		. += "The charge meter reads [CEILING(inserted_cell.percent(), 0.1)]%."

/obj/item/weldingtool/electric/update_overlays()
	. = ..()
	if(welding)
		. += "[initial(icon_state)]-on"
	else
		. += "[initial(icon_state)]-off"

	if(inserted_cell)
		. += "[initial(icon_state)]_cell"

/obj/item/weldingtool/electric/attack_self(mob/user)
	if(!inserted_cell)
		balloon_alert(user, "no cell!")
		return
	if(inserted_cell.charge < power_use_amount)
		balloon_alert(user, "low charge!")
		return

	switched_on(user)
	update_appearance()
	playsound(src, SFX_SPARKS, 75, TRUE, -1)

/obj/item/weldingtool/electric/proc/switched_on(mob/user)
	set_welding(!welding)
	if(welding)
		if(inserted_cell.charge >= power_use_amount)
			force = 15
			damtype = BURN
			hitsound = 'sound/items/tools/welder2.ogg'
			update_appearance()
			START_PROCESSING(SSobj, src)
		else
			balloon_alert(user, "low charge!")
			switched_off(user)
	else
		switched_off(user)

/obj/item/weldingtool/electric/process()
	if(welding)
		force = 15
		damtype = BURN
		update_appearance()

	else
		force = 3
		damtype = BRUTE
		update_appearance()
		if(!can_off_process)
			STOP_PROCESSING(SSobj, src)
		return

	open_flame()

/obj/item/weldingtool/electric/proc/check_energy(mob/user)
	if(inserted_cell.charge() <= 0 && welding)
		set_light_on(FALSE)
		switched_on(user)
		update_appearance()
		return FALSE
	return TRUE

/obj/item/weldingtool/electric/use(used, power_use_amount)
	if(!isOn() || !check_energy())
		return FALSE
	if(inserted_cell.charge >= used)
		inserted_cell.use(power_use_amount, force = TRUE)
		check_energy()
		return TRUE
	else
		return FALSE

/obj/item/weldingtool/electric/tool_use_check(mob/living/user, amount, heat_required)
	if(!isOn() || !check_energy())
		to_chat(user, span_warning("[src] has to be on to complete this task!"))
		return FALSE
	if(inserted_cell.charge() < amount)
		to_chat(user, span_warning("You need more energy to complete this task!"))
		return FALSE
	if(heat < heat_required)
		to_chat(user, span_warning("[src] is not hot enough to complete this task!"))
		return FALSE
	return TRUE

/obj/item/weldingtool/electric/attackby(obj/item/tool, mob/user, list/modifiers, list/attack_modifiers)
	if(istype(tool, /obj/item/stock_parts/power_store/cell))
		if(inserted_cell)
			to_chat(user, span_warning("\The [src] already has a cell inserted - remove it first."))
			return TRUE
		if(is_type_in_typecache(tool, prohibited_cells))
			balloon_alert(user, "incompatible cell!")
			return TRUE
		inserted_cell = tool
		balloon_alert(user, "inserted cell")
		user.transferItemToLoc(tool, src)
		update_icon()
		return TRUE
	else
		. = ..()
	update_appearance()

/obj/item/weldingtool/electric/attack_hand_secondary(mob/user as mob)
	. = ..()
	if(. == SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN)
		return
	if(!inserted_cell)
		return
	else
		if(welding)
			to_chat(user, span_danger("Turn off the welder first!"))
			return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN
		else
			balloon_alert(user, "removed cell")
			user.put_in_hands(inserted_cell)
			inserted_cell = NONE
			update_icon()

	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

/// ARC WELDER TYPES
/obj/item/weldingtool/electric/empty
	inserted_cell = NONE

/obj/item/weldingtool/electric/upgraded_cell
	inserted_cell = /obj/item/stock_parts/power_store/cell/upgraded

/obj/item/weldingtool/electric/high_cell
	inserted_cell = /obj/item/stock_parts/power_store/cell/high

/obj/item/weldingtool/electric/infinite_cell
	inserted_cell = /obj/item/stock_parts/power_store/cell/infinite
