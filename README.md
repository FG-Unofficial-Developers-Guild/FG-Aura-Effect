[![Build FG-Usable File](https://github.com/FG-Unofficial-Developers-Guild/FG-Aura-Effect/actions/workflows/release.yml/badge.svg)](https://github.com/FG-Unofficial-Developers-Guild/FG-Aura-Effect/actions/workflows/release.yml) [![Luacheck](https://github.com/FG-Unofficial-Developers-Guild/FG-Aura-Effect/actions/workflows/luacheck.yml/badge.svg)](https://github.com/FG-Unofficial-Developers-Guild/FG-Aura-Effect/actions/workflows/luacheck.yml)

# Aura Effect

This extension accommodates auras and area-of-effect buffs/debuffs by adding/removing effects to other characters based on proximity.

## Compatibility and Instructions

This extension has been tested with [FantasyGrounds Unity](https://www.fantasygrounds.com/home/FantasyGroundsUnity.php) v4.4.3(2023-09-30).

It works with the 3.5E, 4E, 5E, PFRPG, PFRPG2, and SFRPG rulesets.

Mattekure's [Complete Offensive Package Aura Extension](https://forge.fantasygrounds.com/shop/items/620/view) also allows you to see the auras that this extension creates. It is a paid extension.

### AURA Effect

```AURA: 10 ally; Aura of Protection; SAVE: 5```

This will add a 10 foot aura around the person who has this effect.

Allies within 10' will receive an effect "Aura of Protection; SAVE: 5".

While a name (such as 'Aura of Protection' in the above example) is not required it is highly recommended to help avoid collisions between effects.

If IF/IFT conditions are included *before* the "AURA" effect, they will act to enable/disable parsing of the aura such as for auras that occur automatically when some conditions are met. If IF/IFT conditions are included after the aura, they will be copied to the recipients.

The bearer of the AURA effect will also receive its benefits. If this is not desired, see FACTION() below.

The following descriptor types are available to determine if an aura applies to an actor. They can be combined and all must be true (logical and) for an aura to apply.

**Note**: You can also use the "!" or "~" operators to reverse the results such as "!friend", or "~ally" for all the following descriptors.

#### Faction

* **all** - applies aura to all. if not specified, all is assumed.
* **ally** - applies aura to actors whose faction matches the effect source's faction
* **enemy** - applies aura to actors whose faction is "foe" when the effect source's faction is "friend" (or vice versa)
* **foe** - applies aura to actors whose faction is "foe"
* **friend** - applies aura to actors whose faction is "friend"
* **neutral** - applies aura to actors whose faction is "neutral"
* **none** - applies aura to actors whose faction is "none" or blank

#### Alignment

* **Supported Rulesets**: lawful, chaotic, good, evil, l, c, g, e, n, lg, ln, le, ng, ne, cg, cn, ce

**Note**: neutral is checked against faction. 'n' should be when specifying neutral alignment

#### Size

* **5E**: tiny, small, medium, large, huge, gargantuan
* **4E**: tiny, small, medium, large, huge, gargantuan
* **3.5E/PFRPG**: fine, diminutive, tiny, small, medium, large, huge, gargantuan, colossal
* **PFRPG2**: fine, diminutive, tiny, small, medium, large, huge, gargantuan, colossal
* **SFRPG**: fine, diminutive, tiny, small, medium, large, huge, gargantuan, colossal

#### Type

* **5E**: aberration, beast, celestial, construct, dragon, elemental, fey, fiend, giant, humanoid, monstrosity, ooze, plant, undead, living construct, aarakocra, bullywug, demon, devil, dragonborn, dwarf, elf, gith, gnoll, gnome, goblinoid, grimlock, halfling, human, kenku, kuo-toa, kobold, lizardfolk, merfolk, orc, quaggoth, sahuagin, shapechanger, thri-kreen, titan, troglodyte, yuan-ti, yugoloth
* **4E**: magical beast, animate, beast, humanoid, living construct, air, angel, aquatic, cold, construct, demon, devil, dragon, earth, fire, giant, homunculus, mount, ooze, plant, reptile, shapechanger, spider, swarm, undead, water
* **3.5E/PFRPG**: magical beast, monstrous humanoid, aberration, animal, construct, dragon, elemental, fey, giant, humanoid, ooze, outsider, plant, undead, vermin, living construct, air, angel, aquatic, archon, augmented, cold, demon, devil, earth, extraplanar, fire, incorporeal, native, psionic, shapechanger, swarm, water, dwarf, elf, gnoll, gnome, goblinoid, gnoll, halfling, human, orc, reptilian
* **PFRPG2**: aberration, animal, beast, celestial, construct, dragon, elemental, fey, fiend, fungus, humanoid, monitor, ooze, plant, undead, adlet, aeon, agathion, air, angel, aquatic, archon, asura, augmented, azata, behemoth, catfolk, clockwork, cold, colossus, daemon, dark folk, demodand, demon, devil, div, dwarf, earth, elemental, elf, extraplanar, fire, giant, gnome, goblinoid, godspawn, great old one, halfling, herald, human, incorporeal, inevitable, kaiju, kami, kasatha, kitsune, kyton, leshy, living construct, mythic, native, nightshade, oni, orc, protean, psychopomp, qlippoth, rakshasa, ratfolk, reptilian, robot, samsaran, sasquatch, shapechanger, swarm, troop, udaeus, unbreathing, vanara, vishkanya, water
* **SFRPG**: magical beast, monstrous humanoid, aberration, animal, companion, construct, dragon, fey, giant, humanoid, ooze, outsider, plant, undead, vermin,living construct, aeon, agathion, air, angel, aquatic, archon, augmented, cold, demon, devil, earth, extraplanar, fire, incorporeal, native, psionic, shapechanger, swarm, water, dwarf, elf, gnoll, gnome, goblinoid, halfling, human, orc, reptilian

#### Dying

When the descriptor dying is used, the actor with AURA will only apply the aura effect when dying, or at 0 HP. Conversely !dying will only apply the aura effect when not dying (HP > 0)

#### Exceptions

If a resulting aura applied effect is set to "off" in the combat tracker, then the effect will not be removed based on token movement. This allows you to set the automatic effects of creatures that saved or are immune to "off".

The factional relationship of ally or enemy will be evaluated from the source of the aura effect with regards if a aura applied effect should be applied.

#### 5E Concentration (C)

Concentration spells the (C) should be in it's own clause before the AURA clause or in the AURA clause. It should not be in a clause after after the AURA clause (applied effect)

* **Correct** ```Example; (C); AURA: 10 all; Example; Do something```
* **Correct** ```Example; AURA: 10 all (C); Example; Do something```
* **Incorrect** ```Example; AURA: 10 all; Example; Do something (C)```

### FACTION() Conditional Operator

* Not case-sensitive
* ! or ~ can be prepended to FACTION to provide a logical not.

A factional conditional operator that expands IF/IFT. The conditional operator returns true if factional relationship is true. This feature works generically within Fantasy Grounds and can be used outside of an aura effect.

* **ally** - True if source faction matches the target faction. Always True with IF
* **enemy** - True if the source faction is "foe" and target faction is "friend" **or** if the source faction is "friend" and target faction is "foe. Always False with IF
* **foe** - True if the faction is "foe"
* **friend** - True if the faction is "friend"
* **neutral** - TRUE if the faction is "neutral"
* **none** - True if the faction is "none"
* **notself** - (Legacy, same as !self), True If the actor indicated by the conditional effect is NOT the source of the effect
* **self** - True If the actor indicated by the conditional effect is the source of the effect

**!** or **~** can be prepended to any of the above to provide a logical not
Multiple of the above can be combined

### Aura Use

Auras affect source of the aura by default. To have the aura **NOT** affect the source of the aura, a FACTION conditional operator is needed using one of the following descriptors *!self* or *~self* or *notself* when the aura is placed on the source node. The source of the aura does not benefit from the aura in the following example.

```AURA: 10 ally; Test; IF: FACTION(!self); ATK: 5```

If using a proxy CT token to define an aura area, it is recommended to set the proxy CT entry to NONE and check for *!none* as in the following example. Having all proxy auras check for faction will ensure they don't affect one another or themselves.
```AURA: 10 all; Debuff Area; IF: FACTION(!none); poisoned```

Unless there is a specific advanced case to do so, any other FACTION conditional operators are not needed for an aura.

### Special AURA Types

Special aura types change the default behavior of auras. They are specified in the AURA effect descriptors. Multiple special aura types can be combined to create even more unique auras such as cube that is single and sticky.

|Descriptor|Notes|Example|
|----------|-----|-------|
|**cube**|Default auras are spheres. The length of the side of the cube is defined by the aura value. In the case of the example, the length of a side of the cube aura is 10.|```AURA: 10 all,cube; ATK: -5```|
|**single**|There are a number of spells and effects, particularly in the 5E ruleset, which necessitate a slightly different aura behavior. These have the text or something similar *"When the creature enters the area for the first time on a turn or starts its turn there"*. The aura will be applied to the target only when the target starts its turn in the aura or enters (moves into) the area for the first time on a turn. It will not be reapplied if the target leaves the area and returns on the same turn. It also will not be applied if the actor is in the area when cast or if the aura area moves onto the actor.|```AURA: 10 !ally,single; Test; IF: FACTION(!self); ATK: -5```|
|**sticky**|Applied aura effects will not be removed from actors|```AURA: 10 all,sticky; Poison Trap; IF: FACTION(!self); Poisoned```|
|**once**|The aura will only apply once per turn to an actor that starts or enters the area or if the area moves onto the actor. Leaving and re-entering the area on the same turn will not reapply the aura| ```AURA: 10 all,once; ATK: -5```|

#### Point Descriptor

By default the sphere aura distance is calcuated from the outside of the token that is linked to the CT Actor. The descriptor "point" can be added to have that distance instead be calculated from the center of the token. Points are always calcuated with RAW diagional distance. Cubes are always calcuated using the point method.
```AURA: 10 all,point; ATK: -5```

### GM Holding Shift

As long as the GM is holding shift, Aura calcuations will be disabled. This allows the GM to move a token through an aura without the Aura affecting the token.

### Option for Disabling Aura Effect Chat Messages

"Silence Notifications for Aura Types" can be used to hide aura apply/removal chat messages for a particular faction, relationship, or all.

### Option for Diagonal Distance Multiplier

"Diagonal Multiplier for Aura Distance" defines how diagonals are calcuated with respect to distance between tokens

* ***Raw*** - Default, Diagonals are measured explicitly (Pythagorean Theorem)
* ***Ruleset*** - Diagonals are measured as per Ruleset definition

## Effect Sharing Threads

5E: https://www.fantasygrounds.com/forums/showthread.php?69965-5E-Aura-Effects-Coding

... if you create a thread for your ruleset let me know and I will add it to this list.

## Video Demonstration (click for video)

[<img src="https://i.ytimg.com/vi_webp/e2JQzf5HI6I/hqdefault.webp">](https://www.youtube.com/watch?v=e2JQzf5HI6I)

## API

An API has been added for those developers who wish to interact with this extension more closely. Documentation is found in the code. [Aura API](https://github.com/FG-Unofficial-Developers-Guild/FG-Aura-Effect/blob/main/scripts/manager_aura_api.lua)
