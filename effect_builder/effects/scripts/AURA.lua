-- luacheck: globals createEffectString parentcontrol number_value effect_faction

function createEffectString()
    local effectString = parentcontrol.window.effect.getStringValue() .. ": " .. number_value.getStringValue()
    if not effect_faction.isEmpty() then
        effectString = effectString .. " " .. effect_faction.getValue()
    end
    return effectString
end
