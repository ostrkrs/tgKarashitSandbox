/datum/species/vat_grown_human
	name = "\improper Vat-Grown Human"
	id = SPECIES_VATGROWN_HUMAN
	inherent_traits = list(
		TRAIT_USES_SKINTONES,
		TRAIT_IMMUNODEFICIENCY,
	)
	skinned_type = /obj/item/stack/sheet/animalhide/human
	changesource_flags = MIRROR_BADMIN | WABBAJACK | MIRROR_MAGIC | MIRROR_PRIDE | ERT_SPAWN | RACE_SWAP | SLIME_EXTRACT
	payday_modifier = 0.8

/datum/species/vat_grown_human/prepare_human_for_preview(mob/living/carbon/human/species/vat_grown/vat_humie)
	vat_humie.set_hairstyle("Bald", update = TRUE)

/datum/species/vat_grown_human/get_species_description()
	return "ВЫРАЩЕННЫЕ В ПРОБИРКАХ ЛЮДИ (надо будет дополнить)"

/datum/species/vat_grown_human/get_species_lore()
	return list(
		"ВЫРАЩЕННЫЕ В ПРОБИРКАХ ЛЮДИ (надо будет дополнить)",
	)

/datum/species/vat_grown_human/check_roundstart_eligible()
	return TRUE

/datum/species/vat_grown_human/create_pref_unique_perks()
	var/list/to_add = list()

	to_add += list(list(
		SPECIES_PERK_TYPE = SPECIES_NEUTRAL_PERK,
		SPECIES_PERK_ICON = "fa-drumstick-bite",
		SPECIES_PERK_NAME = "Fast Metabolism",
		SPECIES_PERK_DESC = "Vat-grown people have a faster metabolism than baseliners and other human subtypes. They gain hunger and absorb both healing and toxic reagents more quickly.",
	))

	to_add += list(list(
		SPECIES_PERK_TYPE = SPECIES_NEGATIVE_PERK,
		SPECIES_PERK_ICON = "fa-disease",
		SPECIES_PERK_NAME = "Weak Immunity",
		SPECIES_PERK_DESC = "Due to the imperfection of vat-growing technology in maintaining natural microflora at the fetal stage, vat-grown humans has reduced immunity.",
	))

	return to_add
