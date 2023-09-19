-- luacheck: globals createEffectString parentcontrol number_value effect_faction effect_auraSingle

function createEffectString()
	local effectString = parentcontrol.window.effect.getStringValue() .. ': ' .. number_value.getStringValue()
	if not effect_faction.isEmpty() then effectString = effectString .. ' ' .. effect_faction.getStringValue() end

	if not effect_faction.isEmpty() and effect_auraSingle.getValue() > 0 then effectString = effectString .. ',single' end
	return effectString
end
