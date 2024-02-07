-- luacheck: globals createEffectString parentcontrol number_value effect_auraFaction effect_auraSingle effect_auraCube
-- luacheck: globals effect_auraSticky effect_auraOnce effect_auraPoint

function createEffectString()
	local effectString = parentcontrol.window.effect.getStringValue() .. ': ' .. number_value.getStringValue()
	if not effect_auraFaction.isEmpty() then
		effectString = effectString .. ' ' .. effect_auraFaction.getStringValue()
	end

	if not effect_auraSingle.isEmpty() and effect_auraSingle.getValue() > 0 then
		effectString = effectString .. ',single'
	end
	if not effect_auraCube.isEmpty() and effect_auraCube.getValue() > 0 then
		effectString = effectString .. ',cube'
	end
	if not effect_auraSticky.isEmpty() and effect_auraSticky.getValue() > 0 then
		effectString = effectString .. ',sticky'
	end
	if not effect_auraOnce.isEmpty() and effect_auraOnce.getValue() > 0 then
		effectString = effectString .. ',once'
	end
	if not effect_auraPoint.isEmpty() and effect_auraPoint.getValue() > 0 then
		effectString = effectString .. ',point'
	end
	return effectString
end
