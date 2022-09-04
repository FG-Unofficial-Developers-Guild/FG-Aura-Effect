[![Build FG-Usable File](https://github.com/FG-Unofficial-Developers-Guild/FG-Aura-Effect/actions/workflows/create-ext.yml/badge.svg)](https://github.com/FG-Unofficial-Developers-Guild/FG-Aura-Effect/actions/workflows/create-ext.yml) [![Luacheck](https://github.com/FG-Unofficial-Developers-Guild/FG-Aura-Effect/actions/workflows/luacheck.yml/badge.svg)](https://github.com/FG-Unofficial-Developers-Guild/FG-Aura-Effect/actions/workflows/luacheck.yml)

# FG Aura Effect
This extension accommodates auras and area-of-effect buffs/debuffs by adding/removing effects to other characters based on proximity.

# Compatibility and Instructions
This extension has been tested with [FantasyGrounds Unity](https://www.fantasygrounds.com/home/FantasyGroundsUnity.php) 4.2.2 (2022-06-07).

It works with the 3.5E, 4E, 5E, PFRPG, PFRPG2, and SFRPG rulesets.

Users might also want to use [GKEnialb](https://www.fantasygrounds.com/forums/member.php?70614-GKEnialb)'s [Token Height Indicator](https://www.fantasygrounds.com/forums/showthread.php?66566-5E-Token-Height-Indicator) which makes the auras height-aware.

Mattekure's [Complete Offensive Package Aura Extension](https://forge.fantasygrounds.com/shop/items/620/view) also allows you to see the auras that this extension creates. It is a paid extension.

### AURA Effect
```AURA: 10 friend; Aura of Protection; SAVE: 5```

This will add a 10 foot aura around the person who has this effect.

Allies within 10' will receive an effect "FROMAURA; Aura of Protection; SAVE: 5".

While a name (such as 'Aura of Protection' in the above example) is not required it is highly reccomended to help avoid collisions between effects.

Characters with the condition DEAD, DYING, or UNCONSCIOUS will have their auras disabled. In PFRPG this does not function for the "Unconscious" effect at this time.

The bearer of the AURA effect will also receive its benefits.

The following aura types (used for AURA: 15 friend) are allowed:

* friend
* foe
* all

#### Exceptions
If a resulting FROMAURA is set to "off" in the combat tracker, then the effect will not be removed based on token movement. This allows you to set the automatic effects of creatures that saved or are immune to "off".

### FACTION() conditional check
To further limit bonuses/penalties/conditions applying to the bearer of the AURA effect, there is also an additional conditional type "FACTION()".
```AURA: 10 foe; Test; IF: FACTION(foe); ATK: -5```

The IF: FACTION(foe) ensures that the penalty to attacks does not impact the bearer of the AURA effect but only their foes.

The following faction types (used for IF: FACTION(friend)) are allowed:

* notself
* friend
* foe
* neutral

You can also use the "!" operator in a FACTION conditional to reverse the results:
```AURA: 10 all; Test; IF: FACTION(!foe); ATK: -5```

This will add a 10 foot aura around the person who has this effect.

Anyone within 10' will receive an effect "FROMAURA; Test; IF: FACTION(!foe); ATK: -5".

Although the effect will be visible on all actors within 10', the penalty will only be applied to people who are not specifically foes.

### Option for disabling aura effect chat messages
"Silence Notifications for Aura Types" can be used to hide aura apply/removal chat messages.

# Effect Sharing Threads
5E: https://www.fantasygrounds.com/forums/showthread.php?69965-5E-Aura-Effects-Coding

... if you create a thread for your ruleset let me know and I will add it to this list.

# Video Demonstration (click for video)
[<img src="https://i.ytimg.com/vi_webp/e2JQzf5HI6I/hqdefault.webp">](https://www.youtube.com/watch?v=e2JQzf5HI6I)
