-- luacheck: globals createEffectString target aura_faction_conditional conditional_not
function createEffectString()
	local sReturn
	if conditional_not.getValue() > 0 then
		sReturn = 'IF: !FACTION(' .. aura_faction_conditional.getStringValue() .. ')'
	else
		sReturn = 'IF: FACTION(' .. aura_faction_conditional.getStringValue() .. ')'
	end
	return sReturn
end
