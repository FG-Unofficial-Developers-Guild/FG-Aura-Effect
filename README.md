[![Build FG-Usable File](https://github.com/FG-Unofficial-Developers-Guild/FG-Aura-Effect/actions/workflows/create-ext.yml/badge.svg)](https://github.com/FG-Unofficial-Developers-Guild/FG-Aura-Effect/actions/workflows/create-ext.yml) [![Luacheck](https://github.com/FG-Unofficial-Developers-Guild/FG-Aura-Effect/actions/workflows/luacheck.yml/badge.svg)](https://github.com/FG-Unofficial-Developers-Guild/FG-Aura-Effect/actions/workflows/luacheck.yml)

# FG Aura Effect
This extension accommodates auras and area-of-effect buffs/debuffs by adding/removing effects to other characters based on proximity.

# Compatibility and Instructions
This extension has been tested with [FantasyGrounds Unity](https://www.fantasygrounds.com/home/FantasyGroundsUnity.php) v4.4.3(2023-09-30).

It works with the 3.5E, 5E, PFRPG, PFRPG2, and SFRPG rulesets.

Mattekure's [Complete Offensive Package Aura Extension](https://forge.fantasygrounds.com/shop/items/620/view) also allows you to see the auras that this extension creates. It is a paid extension.

### AURA Effect
```AURA: 10 friend; Aura of Protection; SAVE: 5```

This will add a 10 foot aura around the person who has this effect.

Allies within 10' will receive an effect "Aura of Protection; SAVE: 5".

While a name (such as 'Aura of Protection' in the above example) is not required it is highly recommended to help avoid collisions between effects.

If IF/IFT conditions are included *before* the "AURA" effect, they will act to enable/disable parsing of the aura such as for auras that occur automatically when some conditions are met. If IF/IFT conditions are included after the aura, they will be copied to the recipients.

The bearer of the AURA effect will also receive its benefits. If this is not desired, see below.

The following faction types are available:
* **all** - applies aura to all. if not specified, all is assumed.
* **ally** - applies aura to actors whose faction matches the effect source's faction
* **enemy** - applies aura to actors whose faction is "foe" when the effect source's faction is "friend" (or vice versa)
* **foe** - applies aura to actors whose faction is "foe"
* **friend** - applies aura to actors whose faction is "friend"
* **neutral** - applies aura to actors whose faction is "neutral"
* **none** - applies aura to actors whose faction is "none" or blank

You can also use the "!" or "~" operators to reverse the results such as "!friend", or "~ally".

#### Exceptions
If a resulting aura applied effect is set to "off" in the combat tracker, then the effect will not be removed based on token movement. This allows you to set the automatic effects of creatures that saved or are immune to "off".

A CT token that has a faction of *none*, the factional relationship of ally or enemy will be evaluated from the source of the aura effect with regards if a aura applied effect should be applied.

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

#### Aura Use
Auras affect source of the aura by default. To have the aura **NOT** affect the source of the aura, a FACTION conditional operator is needed using one of the following descriptors *!self* or *~self* or *notself* when the aura is placed on the source node. The source of the aura does not benefit from the aura in the following example.

```AURA: 10 ally; Test; IF: FACTION(!self); ATK: 5```

If using a proxy CT token to define an aura area, it is recommended to set the proxy CT entry to NONE and check for *!none* as in the following example. Having all proxy auras check for faction will ensure they don't affect one another or themselves.
```AURA: 10 all; Debuff Area; IF: FACTION(!none); poisoned```

Unless there is a specific advanced case to do so, any other FACTION conditional operators are not needed for an aura.

### Special AURA types
Special aura types change the default behavior of auras. They are specified in the AURA effect descriptors. Multiple special aura types can be combined to create even more unique aruas such as cube that is single and sticky.

|Descriptor|Notes|Example|
|----------|-----|-------|
|**cube**|Default auras are spheres. The length of the side of the cube is defined by the aura value. In the case of the example, the length of a side of the cube aura is 10.|```AURA: 10 all,cube; ATK: -5```|
|**single**|There are a number of spells and effects, particularly in the 5E ruleset, which necessitate a slightly different aura behavior. These have the text or something similar *"When the creature enters the area for the first time on a turn or starts its turn there"*. The aura will be applied to the target only when the target starts its turn in the aura or enters (moves into) the area for the first time on a turn. It will not be reapplied if the target leaves the area and returns on the same turn. It also will not be applied if the actor is in the area when cast or if the aura area moves onto the actor.|```AURA: 10 !ally,single; Test; IF: FACTION(!self); ATK: -5```|
|**sticky**|Applied aura effects will not be removed from actors|```AURA: 10 all,sticky; Poison Trap; IF: FACTION(!self); Poisoned```|
|**once**|The aura will only apply once per turn to an actor that starts or enters the area or if the area moves onto the actor. Leaving and re-entering the area on the same turn will not reapply the aura| ```AURA: 10 all,once; ATK: -5```|
### Option for disabling aura effect chat messages
"Silence Notifications for Aura Types" can be used to hide aura apply/removal chat messages for a particular faction, relationship, or all.

# Effect Sharing Threads
5E: https://www.fantasygrounds.com/forums/showthread.php?69965-5E-Aura-Effects-Coding

... if you create a thread for your ruleset let me know and I will add it to this list.

# Video Demonstration (click for video)
[<img src="https://i.ytimg.com/vi_webp/e2JQzf5HI6I/hqdefault.webp">](https://www.youtube.com/watch?v=e2JQzf5HI6I)
