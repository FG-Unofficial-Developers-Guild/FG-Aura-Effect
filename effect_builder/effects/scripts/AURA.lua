-- luacheck: globals createEffectString parentcontrol number_value effect_auraFaction effect_auraSingle effect_auraCube
-- luacheck: globals effect_auraSticky

function createEffectString()
	local effectString = parentcontrol.window.effect.getStringValue() .. ': ' .. number_value.getStringValue()
	if not effect_auraFaction.isEmpty() then effectString = effectString .. ' ' .. effect_auraFaction.getStringValue() end

	if not effect_auraFaction.isEmpty() and effect_auraSingle.getValue() > 0 then effectString = effectString .. ',single' end
	if not effect_auraFaction.isEmpty() and effect_auraCube.getValue() > 0 then effectString = effectString .. ',cube' end
	if not effect_auraFaction.isEmpty() and effect_auraSticky.getValue() > 0 then effectString = effectString .. ',sticky' end
	return effectString
end
