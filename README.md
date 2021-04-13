# FG Aura Effect
This extension is built to accommodate auras of any kind. Paladin auras, or even spell uras (such as spirit guardians). This is a relatively complex extension and will require some explanation and examples.

# Compatibility and Instructions
This extension has been tested with [FantasyGrounds Unity](https://www.fantasygrounds.com/home/FantasyGroundsUnity.php) 4.1.0 (2021-03-31). It works with the 3.5E, 4E, 5E, and PFRPG rulesets.

5E users should check out [GKEnialb](https://www.fantasygrounds.com/forums/member.php?70614-GKEnialb)'s [Token Height Indicator](https://www.fantasygrounds.com/forums/showthread.php?66566-5E-Token-Height-Indicator) which makes the auras height-aware.

## AURA Effect
```AURA: 10 friend; Aura of Protection; SAVE: 5```

This will add a 10 foot aura around the person who has this effect; allies within 10' will receive an effect "FROMAURA: Aura of Protection; SAVE: 5"

## FACTION() conditional check
As the bonuses/penalties/conditions in the AURA effect will also be applied to the bearer of the AURA effect, there is also an additional conditional type "FACTION()".

```AURA: 10 foe; IF: FACTION(foe); ATK: -5```

The IF: FACTION(foe) insures that the penalty to attacks does not affect the bearer of the AURA effect but only their foes. 

You can also use the "!" operator in a FACTION conditional to include all except for that type. "!friend" would be anything that's not in the same faction as yourself. The foe faction would also do the same thing, as it assumes neutral/faction type enemies are not your friends as well.

### Aura and faction types
The following aura types (used for AURA: 15 friend) are allowed:

* friend
* foe
* all

The following faction types (used for IF: FACTION(friend)) are allowed:

* friend
* foe
* neutral
* faction
