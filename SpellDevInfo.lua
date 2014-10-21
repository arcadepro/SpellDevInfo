--[==[
SpellDevInfo

Copyright (C) 2014 Adirelle <adirelle@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--]==]


local strmatch, strformat, ceil = string.match, string.format, math.ceil

local function GetUnitName(unitId)
	local name = UnitName(unitId)
	if name then
		if UnitIsPlayer(unitId) then
			local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[select(2, UnitClass(unitId))]
			if color then
				name = strformat("|cff%02x%02x%02x%s|r", ceil(color.r*255), ceil(color.g*255), ceil(color.b*255), name)
			end
		end
		if unitId == "pet" or unitId == "vehicle" then
			return name .. ' <' .. GetUnitName('player') .. '>'
		end
		local partyPetIndex = tonumber(strmatch(unitId, '^partypet(%d+)$') or "")
		if partyPetIndex then
			return name .. ' <' .. GetUnitName('party'..partyPetIndex) .. ">"
		end
		local raidPetIndex = tonumber(strmatch(unitId, '^raidpet(%d+)$') or "")
		if raidPetIndex then
			return name .. ' <' .. GetUnitName('raid'..raidPetIndex) .. ">"
		end
	else
		return '|cfff888888'..unitId..'|r'
	end
	return name
end

local function BoolStr(value)
	return value and '|cff00ff00yes|r' or '|cffff0000no|r'
end

local function ShowSpellList(a, ...)
	if type(a) == "table" then
		return strjoin(" ", ShowSpellList(unpack(a))), ShowSpellList(...)
	elseif type(a) == "number" then
		return GetSpellLink(a) or format("[#%d]", a), ShowSpellList(...)
	end
end

local NOOP = function() end
local AddLibPlayerSpellsInfo = NOOP
local AddLibDispellableInfo = NOOP
local AddDRDataInfo = NOOP
local AddLibItemBuffsInfo = NOOP

local LibPlayerSpells, LPSMinor = LibStub('LibPlayerSpells-1.0', true)
if LibPlayerSpells then
	local band, bor = bit.band, bit.bor
	local c = LibPlayerSpells.constants
	local m = LibPlayerSpells.masks
	local OTHERS = bor(c.AURA, c.UNIQUE_AURA, c.COOLDOWN, c.SURVIVAL, c.BURST, c.MANA_REGEN, c.POWER_REGEN, c.IMPORTANT, c.INVERT_AURA)
	
	local function _ShowFlags(value, name, flag)
		if not name then return end
		if value == flag then
			return name, _ShowFlags(value, next(c, name))
		else
			return _ShowFlags(value, next(c, name))
		end
	end
	
	local function ShowFlags(value, mask)
		local value = band(value, mask)
		if value == 0 then
			return
		end
		return strjoin(" | ", _ShowFlags(value, next(c)))
	end

	function AddLibPlayerSpellsInfo(tooltip, id)
	
		tooltip:AddLine("|cffffffff=== LibPlayerSpells-1.0-"..LPSMinor.." ===|r")
		
		local flags, providers, modifiers, raidbuff, category = LibPlayerSpells:GetSpellInfo(id)
		
		if not flags then
			return tooltip:AddLine("No information", 0.5, 0.5, 0.5)
		end
		tooltip:AddDoubleLine("Type", ShowFlags(flags, m.TYPE) or "regular")
		tooltip:AddDoubleLine("Targeting", ShowFlags(flags, m.TARGETING))
		tooltip:AddDoubleLine("Other flags", ShowFlags(flags, OTHERS) or "none")
		if band(flags, m.TYPE) == c.RAIDBUFF then
			tooltip:AddDoubleLine("Raid buffs", ShowFlags(raidbuff, m.RAIDBUFF_TYPE))
		end
		tooltip:AddDoubleLine("Provider(s)", ShowSpellList(providers))
		tooltip:AddDoubleLine("Modifier(s)", ShowSpellList(modifiers))

		local _, patch, revision = LibPlayerSpells:GetVersionInfo(category)
		tooltip:AddDoubleLine("Source category", category)
		tooltip:AddDoubleLine("Data patch", patch)
		tooltip:AddDoubleLine("Data revision", revision)
	end
end

local LibDispellable, LDMinor = LibStub('LibDispellable-1.0', true)
if LibDispellable then
	function AddLibDispellableInfo(tooltip, id)
		tooltip:AddLine("|cffffffff=== LibDispellable-1.0-"..LDMinor.." ===|r")
		tooltip:AddDoubleLine("Enrage ?", BoolStr(LibDispellable:IsEnrageEffect(id)))
		tooltip:AddDoubleLine("Can dispell:", LibDispellable.spells[id] or "nothing")
	end
end

local LibItemBuffs, LIBMinor = LibStub('LibItemBuffs-1.0', true)
if LibItemBuffs then
	function AddLibItemBuffsInfo(tooltip, id)
		tooltip:AddLine("|cffffffff=== LibItemBuffs-1.0-"..LIBMinor.." ===|r")
		tooltip:AddLine("Buffs", ShowSpellList(LibItemBuffs:GetItemBuffs(id)) or "none")
	end
end

local DRData, DRMinor = LibStub('DRData-1.0', true)
if DRData then
	function AddDRDataInfo(tooltip, id)
		tooltip:AddLine("|cffffffff=== DRData-1.0-"..DRMinor.." ===|r")
		local category = DRData:GetSpellCategory(id)
		if category == "" then category = nil end
		tooltip:AddLine("DR category", category or "none")
		for s, p in pairs(DRData:GetProviders()) do
			if p == id then
				local category = DRData:GetSpellCategory(s)
				tooltip:AddLine("Provides", ShowSpellList(s).." "..category)
			end
		end
	end
end

local function Chain(func, tooltip, first, ...)
	if not (first and func(tooltip, first, ...)) then
		tooltip:Show()
	end
	return true
end

local function AddGenericValues(tooltip, start, ...)
	for i = start, select('#', ...) do
		tooltip:AddDoubleLine('Generic #'..i, tostring(select(i, ...)))
	end
end

local powerCostFmt = {}
for k, v in pairs(_G) do
	if strmatch(k, "^SPELL_POWER_") then
		local power = strsub(k, 13)
		powerCostFmt[v] = _G[power..'_COST']
	end
end

local function AddSpellInfo(tooltip, id)
	if not IsModifierKeyDown() then return end
	local name, _, _, cost, isFunnel, powerType, castTime, minRange, maxRange = GetSpellInfo(id)
	if not name then return end

	id = tonumber(id)

	tooltip:AddLine("|cffffffff=== Spell data ===|r")
	tooltip:AddDoubleLine("Id", id or "?")
	tooltip:AddDoubleLine("Name", name or "?")
	local costFmt = powerType and powerCostFmt[powerType]
	if costFmt and powerType then
		tooltip:AddDoubleLine("Cost", strformat(costFmt, cost))
	else
		tooltip:AddDoubleLine("Cost", cost or "?")
		tooltip:AddDoubleLine("Power Type", powerType or "?")
	end
	tooltip:AddDoubleLine("Funnel ?", BoolStr(isFunnel))
	tooltip:AddDoubleLine("Cast time", castTime and strformat("%5.3fs", castTime/1000.0) or "?")
	tooltip:AddDoubleLine("Min range", minRange or "?")
	tooltip:AddDoubleLine("Max range", maxRange or "?")
	AddGenericValues(tooltip, 10, GetSpellInfo(id))

	local spec, class = IsSpellClassOrSpec(name)
	tooltip:AddDoubleLine("Class", class or "?")
	tooltip:AddDoubleLine("Specialization", spec or "?")
	tooltip:AddDoubleLine("Talent ?", BoolStr(IsTalentSpell(name)))

	if id then
		tooltip:AddDoubleLine("Player Spell ?", BoolStr(IsPlayerSpell(id)))
		tooltip:AddDoubleLine("Known ?", BoolStr(IsSpellKnown(id)))
	end

	tooltip:AddDoubleLine("Consumable ?", BoolStr(IsConsumableSpell(id or name)))
	tooltip:AddDoubleLine("Helpful ?", BoolStr(IsHelpfulSpell(id or name)))
	tooltip:AddDoubleLine("Harmful ?", BoolStr(IsHarmfulSpell(id or name)))
	tooltip:AddDoubleLine("Passive ?", BoolStr(IsPassiveSpell(id or name)))

	local usable, nopower = IsUsableSpell(id)
	tooltip:AddDoubleLine("Usable ?", BoolStr(usable))
	tooltip:AddDoubleLine("Not enough power ?", BoolStr(nopower))

	AddLibPlayerSpellsInfo(tooltip, id)
	AddLibDispellableInfo(tooltip, id)
	AddDRDataInfo(tooltip, id)

	tooltip:Show()
	return true
end

local mountFlags = {
	[ 1] = "Ground ?",
	[ 2] = "Can fly ?",
	[ 4] = "Hovering ?",
	[ 8] = "Underwater ?",
	[16] = "Can jump ?"
}

local function AddCompanionInfo(tooltip, ctype, id)
	for index = 1, GetNumCompanions("MOUNT") do
		local creatureID, creatureName, creatureSpellID, _, issummoned, mountType = GetCompanionInfo(ctype, index)
		if creatureSpellID == id then
			--if not creatureID then return end

			tooltip:AddLine("|cffffffff=== Companion data ===|r")
			tooltip:AddDoubleLine("Type", ctype)
			tooltip:AddDoubleLine("Index", Index)
			tooltip:AddDoubleLine("Creature Id", creatureID or "?")
			tooltip:AddDoubleLine("Creature Name", creatureName or "?")
			tooltip:AddDoubleLine("Spell Id", creatureSpellID)
			tooltip:AddDoubleLine("Summoned ?", BoolStr(issummoned))
			if mountType then
				for flag, label in pairs(mountFlags) do
					tooltip:AddDoubleLine(label, BoolStr(bit.band(mountType, flag) == flag))
				end
			end

			AddGenericValues(tooltip, 7, GetCompanionInfo(ctype, index))

			return Chain(AddSpellInfo, tooltip, creatureSpellID)
		end
	end
end

local function AddItemInfo(tooltip, id)
	local name, _, rarity, level, minLevel, type, subType, stackCount,
equipLoc, _, sellPrice = GetItemInfo(id)
	if not name then return end

	id = tonumber(id)

	tooltip:AddLine("|cffffffff=== Item data ===|r")
	tooltip:AddDoubleLine("Id", id or "?")
	tooltip:AddDoubleLine("Name", name or "?")
	if rarity then
		tooltip:AddDoubleLine("Rarity", _G["ITEM_QUALITY"..rarity.."_DESC"].." ("..rarity..")")
	end
	tooltip:AddDoubleLine("Level", level or "?")
	tooltip:AddDoubleLine("Min level", minLevel or "?")
	tooltip:AddDoubleLine("Type", type or "?")
	tooltip:AddDoubleLine("Subtype", subType or "?")
	tooltip:AddDoubleLine("Stack size", stackCount or "?")
	if equipLoc then
		tooltip:AddDoubleLine("Equipment slot", equipLoc)
	end
	if sellPrice and sellPrice > 0 then
		tooltip:AddDoubleLine("Sell price", sellPrice)
	end
	AddGenericValues(tooltip, 12, GetItemInfo(id or name))

	tooltip:AddDoubleLine("Consumable ?", BoolStr(IsConsumableItem(id or name)))
	tooltip:AddDoubleLine("Helpful ?", BoolStr(IsHelpfulItem(id or name)))
	tooltip:AddDoubleLine("Harmful ?", BoolStr(IsHarmfulItem(id or name)))

	local usable, nopower = IsUsableItem(id)
	tooltip:AddDoubleLine("Usable ?", BoolStr(usable))
	tooltip:AddDoubleLine("Not enough power ?", BoolStr(nopower))
	
	AddLibItemBuffsInfo(tooltip, id or name)

	local spell = GetItemSpell(id or name)
	if spell then
		tooltip:AddDoubleLine("Item spell", spell)
	end

	return Chain(AddSpellInfo, tooltip, spell)
end

local function AddMacroInfo(tooltip, index)
	local name, _, _, isLocal = GetMacroInfo(index)
	if not name then return end

	tooltip:AddLine("|cffffffff=== Macro data ===|r")
	tooltip:AddDoubleLine("Index", index)
	tooltip:AddDoubleLine("Name", name)
	tooltip:AddDoubleLine("Local ?", BoolStr(isLocal))
	AddGenericValues(tooltip, 4, GetMacroInfo(index))

	local spell, rank, spellId = GetMacroSpell(index)
	if spellId then
		tooltip:AddDoubleLine("Spell", spell)
		return Chain(AddSpellInfo, tooltip, spellId)
	end

	local item, link = GetMacroItem(index)
	if link then
		tooltip:AddDoubleLine("Item", item)
		local _, itemId = strmatch(link, "item:(%d+)")
		return Chain(AddItemInfo, tooltip, tonumber(itemId))
	end

	tooltip:Show()
	return true
end

local function AddActionInfo(tooltip, slot)
	if not IsModifierKeyDown() then return end
	local actionType, id, subType = GetActionInfo(slot)
	if not actionType then return end

	tooltip:AddLine("|cffffffff=== Action data ===|r")
	tooltip:AddDoubleLine("Slot", slot)
	tooltip:AddDoubleLine("Type", actionType)
	if subType then
		tooltip:AddDoubleLine("Subtype", subType)
	end
	tooltip:AddDoubleLine("Id", id)
	AddGenericValues(tooltip, 4, GetActionInfo(slot))

	local usable, nopower = IsUsableAction(slot)
	tooltip:AddDoubleLine("Usable ?", BoolStr(usable))
	tooltip:AddDoubleLine("Not enough power ?", BoolStr(nopower))

	tooltip:AddDoubleLine("Consumable ?", BoolStr(IsConsumableAction(slot)))

	if actionType then
		if actionType == "spell" then
			return Chain(AddSpellInfo, tooltip, id)
		elseif actionType == "companion" then
			return Chain(AddCompanionInfo, tooltip, subType, id)
		elseif actionType == "macro" then
			return Chain(AddMacroInfo, tooltip, id)
		elseif actionType == "item" then
			return Chain(AddItemInfo, tooltip, id)
		end
	end

	tooltip:Show()
	return true
end

local function AddAuraInfo(func, tooltip, ...)
	if not IsModifierKeyDown() then return end
	local name, _, _, _, debuffType, _, _, unitCaster, isStealable, shouldConsolidate, spellId, canApplyAura, isBossDebuff = func(...)
	if not name then return end

	tooltip:AddLine("|cffffffff=== Aura data ===|r")
	tooltip:AddDoubleLine("Caster", unitCaster and GetUnitName(unitCaster) or "?")
	tooltip:AddDoubleLine("Type", debuffType or "-")
	tooltip:AddDoubleLine("Spell ID", spellId or "?")
	tooltip:AddDoubleLine("Stealable ?", BoolStr(isStealable))
	tooltip:AddDoubleLine("Consolidate ?", BoolStr(shouldConsolidate))
	tooltip:AddDoubleLine("Can apply ?", BoolStr(canApplyAura))
	tooltip:AddDoubleLine("Boss ?", BoolStr(isBossDebuff))
	AddGenericValues(tooltip, 14, func(...))

	return Chain(AddSpellInfo, tooltip, spellId)
end

local function AddSpellbookInfo(tooltip, slot, bookType)
	if not IsModifierKeyDown() then return end

	tooltip:AddLine("|cffffffff=== Spellbook data ===|r")

	tooltip:AddDoubleLine("Slot", slot or "?")
	tooltip:AddDoubleLine("Book type", bookType or "-")

	local slotType, slotId = GetSpellBookItemInfo(slot, bookType)
	tooltip:AddDoubleLine("Slot type", slotType or "?")
	tooltip:AddDoubleLine("Slot id", slotId or "-")

	local name, subName = GetSpellBookItemName(slot, bookType)
	tooltip:AddDoubleLine("Name", name or "?")
	tooltip:AddDoubleLine("subName", subName or "-")

	if slotType == "SPELL" then
		return Chain(AddSpellInfo, tooltip, slotId)
	else
		tooltip:Show()
		return true
	end
end

local proto = getmetatable(GameTooltip).__index
hooksecurefunc(proto, "SetUnitAura", function(...) return AddAuraInfo(UnitAura, ...) end)
hooksecurefunc(proto, "SetUnitBuff", function(...) return AddAuraInfo(UnitBuff, ...) end)
hooksecurefunc(proto, "SetUnitDebuff", function(...) return AddAuraInfo(UnitDebuff, ...) end)
hooksecurefunc(proto, "SetSpellByID", AddSpellInfo)
hooksecurefunc(proto, "SetSpellBookItem", AddSpellbookInfo)
hooksecurefunc(proto, "SetAction", AddActionInfo)
