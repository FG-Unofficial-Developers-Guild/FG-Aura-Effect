[![Build FG-Usable File](https://github.com/FG-Unofficial-Developers-Guild/FG-Aura-Effect/actions/workflows/create-ext.yml/badge.svg)](https://github.com/FG-Unofficial-Developers-Guild/FG-Aura-Effect/actions/workflows/create-ext.yml) [![Luacheck](https://github.com/FG-Unofficial-Developers-Guild/FG-Aura-Effect/actions/workflows/luacheck.yml/badge.svg)](https://github.com/FG-Unofficial-Developers-Guild/FG-Aura-Effect/actions/workflows/luacheck.yml)

# FG Aura Effect
This extension accommodates auras and area-of-effect buffs/debuffs by adding/removing effects to other characters based on proximity.

# Compatibility and Instructions
This extension has been tested with [FantasyGrounds Unity](https://www.fantasygrounds.com/home/FantasyGroundsUnity.php) 4.3.2 (2022-12-12).

It works with the 3.5E, 4E, 5E, PFRPG, PFRPG2, and SFRPG rulesets.

Users might also want to use [GKEnialb](https://www.fantasygrounds.com/forums/member.php?70614-GKEnialb)'s [Token Height Indicator](https://www.fantasygrounds.com/forums/showthread.php?66566-5E-Token-Height-Indicator) which makes the auras height-aware.

Mattekure's [Complete Offensive Package Aura Extension](https://forge.fantasygrounds.com/shop/items/620/view) also allows you to see the auras that this extension creates. It is a paid extension.

### AURA Effect
```AURA: 10 friend; Aura of Protection; SAVE: 5```

This will add a 10 foot aura around the person who has this effect.

Allies within 10' will receive an effect "FROMAURA; Aura of Protection; SAVE: 5".

While a name (such as 'Aura of Protection' in the above example) is not required it is highly reccomended to help avoid collisions between effects.

If IF/IFT conditions are included *before* the "AURA" effect, they will act to enable/disable parsing of the aura such as for auras that occur automatically when some conditions are met. If IF/IFT confitions are included after the aura, they will be copied to the recipients.

The bearer of the AURA effect will also receive its benefits. If this is not desired, see below.

The following faction types are available:
* all - applies aura to all. if not specified, all is assumed.
* friend - applies aura to actors whose faction is "friend"
* foe - applies aura to actors whose faction is "foe"
* neutral - applies aura to actors whose faction is "neutral"
* faction - applies aura to actors whose faction is blank
* ally - applies aura to actors whose faction matches the effect source's faction
* enemy - applies aura to actors whose faction is "foe" when the effect source's faction is "friend" (or vice versa)

You can also use the "!" or "~" operators to reverse the results such as "!friend", or "~ally".

#### Exceptions
If a resulting FROMAURA is set to "off" in the combat tracker, then the effect will not be removed based on token movement. This allows you to set the automatic effects of creatures that saved or are immune to "off".

### FACTION() conditional check
To further limit bonuses/penalties/conditions applying to the bearer of the AURA effect, there is also an additional conditional type "FACTION()".
```AURA: 10 all; Test; IF: FACTION(foe); ATK: -5```

The IF: FACTION(foe) ensures that the penalty to attacks does not impact the bearer of the AURA effect but only their foes.

The same faction types as above are available, along with "notself":
* all - does not block processing on any actor
* friend - continues if the effect bearer's faction is "friend"
* foe - continues if the effect bearer's faction is "foe"
* neutral - continues if the effect bearer's faction is "neutral"
* faction - continues if the effect bearer's faction is blank
* ally - continues if the effect bearer's faction matches the effect source's faction
* enemy - continues if the effect bearer's faction is "foe" and the effect source's faction is "friend" (or vice versa)
* notself - continues if the effect bearer does not match the effect source

You can also use the "!" or "~" operators in a FACTION conditional to reverse the results:
```AURA: 10; Save Bonus for All and Attack Bonus Except for Actor With Aura; SAVE: 1; IF: FACTION(notself); ATK: 1```
```AURA: 10 !ally; Attack Penalty for All Except Allies; ATK: -5```
```AURA: 10 ally; Attack Bonus for Allies; IF: FACTION(notself); ATK: 2```
```AURA: 10 all; Speed Bonus for All, Attack Bonus for Blank Factions; SPEED: 20; IF: FACTION(faction); ATK: 2```

### Option for disabling aura effect chat messages
"Silence Notifications for Aura Types" can be used to hide aura apply/removal chat messages for a particular faction, relationship, or all.

# Effect Sharing Threads
5E: https://www.fantasygrounds.com/forums/showthread.php?69965-5E-Aura-Effects-Coding

... if you create a thread for your ruleset let me know and I will add it to this list.

# Video Demonstration (click for video)
[<img src="https://i.ytimg.com/vi_webp/e2JQzf5HI6I/hqdefault.webp">](https://www.youtube.com/watch?v=e2JQzf5HI6I)
