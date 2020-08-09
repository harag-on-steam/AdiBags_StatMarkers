--[[
AdiBags - Stat Markers
Copyright 2020 Harag (harag@cortexx.net)
All rights reserved.

This file is an extension to AdiBags.

AdiBags is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

AdiBags is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with AdiBags.  If not, see <http://www.gnu.org/licenses/>.
--]]

--<GLOBALS
local _G = _G
local abs = _G.math.abs
local GetItemInfo = _G.GetItemInfo
local QuestDifficultyColors = _G.QuestDifficultyColors
local UnitLevel = _G.UnitLevel
local modf = _G.math.modf
local max = _G.max
local min = _G.min
local pairs = _G.pairs
local select = _G.select
local unpack = _G.unpack
--GLOBALS>

local addon = LibStub('AceAddon-3.0'):GetAddon('AdiBags')
local L = addon.L

local mod = addon:NewModule('StatMarkers', 'ABEvent-1.0')
mod.uiName = L['Stat Markers']
mod.uiDesc = L['Display markers for secondary stats on equippable items in the bottom right corner of the button.']

local colorSchemes = {
	none = function() return 1, 1 ,1 end,
	gem = function() return 1, 1, 1 end
}

local gemColor = {
	ITEM_MOD_CRIT_RATING_SHORT = 'ffa080',
	ITEM_MOD_HASTE_RATING_SHORT = 'ffff90',
	ITEM_MOD_VERSATILITY = '7080ff',
	ITEM_MOD_MASTERY_RATING_SHORT = 'a070ff',
	ITEM_MOD_AGILITY_SHORT = 'f0f0f0',
	ITEM_MOD_INTELLECT_SHORT = 'f0f0f0',
	ITEM_MOD_STRENGTH_SHORT = 'f0f0f0',
}

local secondary = { -- in game tooltip order
	{
		stat = 'ITEM_MOD_CRIT_RATING_SHORT',
		C = 'C',
		c = 'c',
	},
	{
		stat = 'ITEM_MOD_HASTE_RATING_SHORT',
		C = 'H',
		c = 'h',
	},
	{
		stat = 'ITEM_MOD_VERSATILITY',
		C = 'V',
		c = 'v',
	},
	{
		stat = 'ITEM_MOD_MASTERY_RATING_SHORT',
		C = 'M',
		c = 'm',
	},
}

local texts = {}

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, {
		profile = {
			useSyLevel = false,
			equippableOnly = true,
			colorScheme = 'none',
			minLevel = 1,
			minorPercentage = 75,
			ignoreJunk = true,
			ignoreHeirloom = true,
		},
	})
end

function mod:OnEnable()
	self:RegisterMessage('AdiBags_UpdateButton', 'UpdateButton')
	self:SendMessage('AdiBags_UpdateAllButtons')
end

function mod:OnDisable()
	for _, text in pairs(texts) do
		text:Hide()
	end
end

local function CreateText(button)
	local text = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	text:SetPoint("BOTTOMRIGHT", button, -1, 0)
	text:Hide()
	texts[button] = text
	return text
end

local function ParseItemLink(itemString)
	local itemSplit = {}
	for v in string.gmatch(itemString, ":(%d*)") do
		table.insert(itemSplit, v and tonumber(v) or 0)
	end

	local itemId = itemSplit[1]
	local enchantId = itemSplit[2]
	local gemId = itemSplit[3]

	local bonuses = {}
--	for index = 1, itemSplit[12] do
--	  bonuses[itemSplit[12 + index]] = true
--	end

	return itemId, enchantId, gemId, bonuses
end

function mod:UpdateButton(event, button)
	local settings = self.db.profile
	local link = button:GetItemLink()
	local text = texts[button]

	if link then
		local statText = ""

		if GetItemGem(link, 1) then
			statText = "■"
		elseif link:find(":4802:") then -- socket bonusid -> empty socket
			statText = "□"
		end

		local stats = GetItemStats(link)
		if stats then
			local highestStat = 0

			for i, statInfo in ipairs(secondary) do
				if stats[statInfo.stat] then
					highestStat = max(highestStat, stats[statInfo.stat])
				end
			end

			for i, statInfo in ipairs(secondary) do
				if stats[statInfo.stat] then
					statText = statText .. ((stats[statInfo.stat] * 100 / highestStat < settings.minorPercentage) and statInfo.c or statInfo.C)
				end
			end
		end

		if statText then
			local _, _, quality, _, reqLevel, _, _, _, loc = GetItemInfo(link)
			local item = Item:CreateFromBagAndSlot(button.bag, button.slot)
			local level = item and item:GetCurrentItemLevel() or 0
			if level >= settings.minLevel
				and (quality ~= LE_ITEM_QUALITY_POOR or not settings.ignoreJunk)
				and (loc ~= "" or not settings.equippableOnly)
				and (quality ~= LE_ITEM_QUALITY_HEIRLOOM or not settings.ignoreHeirloom)
			then
				if not text then
					text = CreateText(button)
				end
				text:SetText(statText)
				text:SetTextColor(colorSchemes[settings.colorScheme](level, quality, reqLevel, (loc ~= "")))
				return text:Show()
			end
		end
	end
	if text then
		text:Hide()
	end
end

function mod:GetOptions()
	return {
		equippableOnly = {
			name = L['Only equippable items'],
			desc = L['Do not show level of items that cannot be equipped.'],
			type = 'toggle',
			order = 10,
		} and nil,
		colorScheme = {
			name = L['Color scheme'],
			desc = L['Which color scheme should be used for each stat?'],
			type = 'select',
			values = {
				none  = L['None'],
				gem   = L['Gem colors'],
			},
			order = 20,
		} and nil,
		minLevel = {
			name = L['Mininum level'],
			desc = L['Do not show for item levels under this threshold.'],
			type = 'range',
			min = 1,
			max = 1000,
			step = 1,
			bigStep = 10,
			order = 30,
		},
		minorPercentage = {
			name = L['Minor percentage'],
			desc = L['A stat is marked as minor if it is below this percentage compared to the highest secondary stat'],
			type = 'range',
			min = 0,
			max = 100,
			step = 1,
			bigStep = 5,
			order = 40,
		},
		ignoreJunk = {
			name = L['Ignore low quality items'],
			desc = L['Do not show markers for poor quality items.'],
			type = 'toggle',
			order = 50,
		},
		ignoreHeirloom = {
			name = L['Ignore heirloom items'],
			desc = L['Do not show markers for heirloom items.'],
			type = 'toggle',
			order = 60,
		},
	}, addon:GetOptionHandler(self)
end