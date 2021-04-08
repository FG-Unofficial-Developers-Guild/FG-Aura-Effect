# FG-Aura-Effect
This extension is built to accommodate auras of any kind. Paladin auras, or even spell uras (such as spirit guardians). This is a relatively complex extension and will require some explanation and examples.

I've added a few things in, mainly is the "AURA" effect, the other is an additional conditional helper "FACTION()"

# A few examples for how you would use this:
```AURA: 10 friend; Aura of Protection; SAVE: 5```

This will add a 10 foot aura around the person who has this effect, everyone within 10' will receive an effect "FROMAURA:Aura of Protection; SAVE: 5"

Everything after the "AURA: #distanceInFeet auraType;" will be added to other tokens when applicable inside the distance prepended by "FROMAURA:"

What this means is the paladin themselves will not gain a FROMAURA: effect, however the SAVE: 5 will still work for them as well.

This is why I've added in the additional conditional type "FACTION()"

For things like Spirit Guardians I've used it like this:

```AURA: 15 foe; Spirit Guardians; IF: FACTION(foe); SAVEO: wisdom DC 17 (M)(H); SAVEDMG: 3d8 necrotic; (C)```

The IF: FACTION(foe) insures that the SAVEO and SAVEDMG do not affect the cleric who has cast the spell, while still allowing it to fire on the creatures that gain the effect as "FROMAURA:Spirit Guardians; IF: FACTION(foe); SAVEO: wisdom DC 17 (M)(H); SAVEDMG: 3d8 necrotic; (C);" For this to work you'd also have to be using my ongoing saves extension.

The following aura types are allowed:

* friend
* foe
* all

The following faction types are allowed:

* friend
* foe
* neutral
* faction

One thing to note regarding faction types is you can also use the "!" operator before any of them to include all except for that type. "!friend" would be anything that's not in the same faction as yourself. The foe faction would also do the same thing, as it assumes neutral/faction type enemies are not your friends as well. I can be convinced to adjust this to only include the foe/enemy faction type (the red underlay on map) if that is preferred.

This extension is still not fully tested, so do let me know if there are issues that anyone comes across.

I've also added an option menu to silence the notifications about the effects which can be filtered based on aura type (we found that the paladin's aura was very spammy during play).