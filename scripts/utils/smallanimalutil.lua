-- Rabbits, birds and the like: Kiritzuka and Manutsawee leave them be unless hunger drives them to it,
-- and even then barely hurt them. A blow that catches them in passing is another matter.
local SmallAnimalUtil = {}

local HUNTERS = {
    kiritzuka = true,
    manutsawee = true,
}

-- Frogs and moonblind crows come at her, so they are fair game.
function SmallAnimalUtil.IsSmallAnimal(target)
    return target:HasAnyTag(unpack(TUNING.SMALL_ANIMALS.TAGS)) and not target:HasTag("hostile")
end

function SmallAnimalUtil.IsHunter(inst)
    return HUNTERS[inst.prefab] == true
end

-- Takes the hunger component or its replica.
function SmallAnimalUtil.IsStarving(hunger)
    return hunger ~= nil and hunger:GetPercent() < TUNING.SMALL_ANIMALS.HUNGER
end

-- For combat's customdamagemultfn: nothing until starving, and little even then.
function SmallAnimalUtil.GetDamageMult(inst, target)
    if target == nil or not SmallAnimalUtil.IsSmallAnimal(target) then
        return 1
    end
    return SmallAnimalUtil.IsStarving(inst.components.hunger) and TUNING.SMALL_ANIMALS.DAMAGE_MULT or 0
end

return SmallAnimalUtil
