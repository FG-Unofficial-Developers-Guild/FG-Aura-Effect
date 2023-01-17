-- luacheck: globals createEffectString target aura_faction_conditional

function createEffectString() return 'IF: FACTION(' .. aura_faction_conditional.getStringValue() .. ')' end
