--[[
	Mod by Kotolegokot and Xiong (2012-2013)
	Rev. kilbith and nerzhul (2015)
]]

money = {}

dofile(minetest.get_modpath("money") .. "/settings.txt") -- Loading settings.
dofile(minetest.get_modpath("money") .. "/hud.lua") -- Account display in HUD.
dofile(minetest.get_modpath("money") .. "/shop.lua") -- Account display in HUD.

local accounts = {}
local input = io.open(minetest.get_worldpath() .. "/accounts", "r")
if input then
	accounts = minetest.deserialize(input:read("*l"))
	io.close(input)
end

function money.save_accounts()
	local output = io.open(minetest.get_worldpath() .. "/accounts", "w")
	output:write(minetest.serialize(accounts))
	io.close(output)
end
function money.set_money(name, amount)
	accounts[name].money = amount
	if money.hud[name] ~= nil then
		money.hud_change(name)
	end
	money.save_accounts()
end
function money.get_money(name)
	return accounts[name].money
end
function money.exist(name)
	return accounts[name] ~= nil
end

local save_accounts = money.save_accounts
local set_money = money.set_money
local get_money = money.get_money
local exist = money.exist

minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	if not exist(name) then
		accounts[name] = {money = INITIAL_MONEY}
	end
	money.hud_add(name)
end)

minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	money.hud[name] = nil
end)

minetest.register_privilege("money", "Can use /money [<account> <amount>] command")

minetest.register_chatcommand("money", {
	privs = {money=true},
	params = "[<account> <amount>]",
	description = "Send money",
	func = function(name, param)
		if param == "" then --/money
			minetest.chat_send_player(name, "My money account : " .. CURRENCY_PREFIX .. get_money(name) .. CURRENCY_POSTFIX)
			return true
		end
		local m = string.split(param, " ")
		local param1, param2 = m[1], m[2]
		param2 = tonumber(param2)
		-- Various checks
		if not param1 or not param2 then --/money <account> <amount>
			minetest.chat_send_player(name, "Invalid parameters (see /help money)")
			return false
		end
		if not exist(param1) then
			minetest.chat_send_player(name, "\"" .. param1 .. "\" account don't exist.")
			return false
		end
		if param2 <= 0 then
			minetest.chat_send_player(name, "The amount must be a positive number.")
			return false
		end
		if get_money(name) < param2 then
			minetest.chat_send_player(name, "You don't have " .. CURRENCY_PREFIX .. param2 - get_money(name) .. CURRENCY_POSTFIX .. ".")
			return false
		end
		-- Send the amount
			set_money(param1, get_money(param1) + param2)
			set_money(name, get_money(name) - param2)
			minetest.chat_send_player(param1, name .. " sent you " .. CURRENCY_PREFIX .. param2 .. CURRENCY_POSTFIX .. ".")
			minetest.chat_send_player(name, param1 .. " took your " .. CURRENCY_PREFIX .. param2 .. CURRENCY_POSTFIX .. ".")
		return true
	end,
})
