# FG Aura Effect
This extension accommodates auras and AoE buffs/debuffs by adding/removing effects to other characters based on proximity.

# Compatibility and Instructions
This extension has been tested with [FantasyGrounds Unity](https://www.fantasygrounds.com/home/FantasyGroundsUnity.php) 4.0.10 (2021-02-04) and 4.1.0 (2021-05-15). It works with the 3.5E, 4E, 5E, and PFRPG rulesets. When using with versions before v4.1.0, you must have token locking enabled (and you still may encounter some issues).

Users might also want to use [GKEnialb](https://www.fantasygrounds.com/forums/member.php?70614-GKEnialb)'s [Token Height Indicator](https://www.fantasygrounds.com/forums/showthread.php?66566-5E-Token-Height-Indicator) which makes the auras height-aware.

This extension is not fully compatible with SilentRuin's [Polymorphism Extension](https://www.fantasygrounds.com/forums/showthread.php?61009). It seems that when concentration on polymorph is broken, a script error is triggered in SilentRuin's code (which I am unable to test for/fix since I don't own that extension).

### AURA Effect
```AURA: 10 friend; Aura of Protection; SAVE: 5```

This will add a 10 foot aura around the person who has this effect.

Allies within 10' will receive an effect "FROMAURA; Aura of Protection; SAVE: 5".

While a name (such as 'Aura of Protection' in the above example) is not required it is highly reccomended to help avoid collisions between effects.

The bearer of the AURA effect will also receive its benefits.

The following aura types (used for AURA: 15 friend) are allowed:

* friend
* foe
* all

### FACTION() conditional check
To further limit bonuses/penalties/conditions applying to the bearer of the AURA effect, there is also an additional conditional type "FACTION()".
```AURA: 10 foe; Test; IF: FACTION(foe); ATK: -5```

The IF: FACTION(foe) ensures that the penalty to attacks does not impact the bearer of the AURA effect but only their foes.

The following faction types (used for IF: FACTION(friend)) are allowed:

* friend
* foe
* neutral
* faction
* notself

You can also use the "!" operator in a FACTION conditional to reverse the results:
```AURA: 10 all; Test; IF: FACTION(!foe); ATK: -5```

This will add a 10 foot aura around the person who has this effect.

Anyone within 10' will receive an effect "FROMAURA; Test; IF: FACTION(!foe); ATK: -5".

Although the effect will be visible on all actors within 10', the penalty will only be applied to people who are not specifically foes.

### Option for disabling aura effect chat messages
![image](https://user-images.githubusercontent.com/1916835/116077909-0245c780-a664-11eb-8cb7-0b0e8ec855c9.png)

"Silence Notifications for Aura Types" can be set to a faction to hide their aura apply/removal chat messages.
