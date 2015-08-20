--[[
	Mod by Kotolegokot and Xiong (2012-2013)
	Rev. kilbith and nerzhul (2015)
]]

money = {}

dofile(minetest.get_modpath("money") .. "/settings.txt") -- Loading settings.
dofile(minetest.get_modpath("money") .. "/hud.lua") -- Account display in HUD.

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

local function has_shop_privilege(meta, player)
	return player:get_player_name() == meta:get_string("owner") or minetest.get_player_privs(player:get_player_name())["money_admin"]
end

minetest.register_node("money:shop", {
	description = "Shop",
	tiles = {"shop.png"},
	groups = {snappy=2,choppy=2,oddly_breakable_by_hand=2},
	sounds = default.node_sound_wood_defaults(),
	paramtype2 = "facedir",
	after_place_node = function(pos, placer)
	local meta = minetest.get_meta(pos)
	meta:set_string("owner", placer:get_player_name())
		meta:set_string("infotext", "Untuned Shop (owned by " .. placer:get_player_name() .. ")")
	end,
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec", "size[6,5]"..
			"field[0.256,0.5;6,1;shopname;Name of your shop;]"..
			"label[-0.025,1.03;Trade Type]"..
			"dropdown[-0.025,1.45;2.5,1;action;Sell,Buy,Buy and Sell;]"..
			"field[2.7,1.7;3.55,1;amount;Trade lot quantity (1-99);]"..
			"field[0.256,2.85;6,1;nodename;Node name to trade (eg. default:mese);]"..
			"field[0.256,4;3,1;costbuy;Buying price (per lot);]"..
			"field[3.25,4;3,1;costsell;Selling price (per lot);]"..
			"button_exit[2,4.5;2,1;button;Tune]")
		meta:set_string("infotext", "Untuned Shop")
		meta:set_string("owner", "")
		local inv = meta:get_inventory()
		inv:set_size("main", 32)
		meta:set_string("form", "yes")
	end,

	can_dig = function(pos, player)
		local meta = minetest.get_meta(pos);
		local inv = meta:get_inventory()
		return inv:is_empty("main") and (meta:get_string("owner") == player:get_player_name() or minetest.get_player_privs(player:get_player_name())["money_admin"])
	end,
	allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		local meta = minetest.get_meta(pos)
		if not has_shop_privilege(meta, player) then
			minetest.log("action", player:get_player_name().." tried to access a shop belonging to "..
			meta:get_string("owner").." at "..
			minetest.pos_to_string(pos))
			return 0
		end
		return count
	end,
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		local meta = minetest.get_meta(pos)
		if not has_shop_privilege(meta, player) then
			minetest.log("action", player:get_player_name().." tried to access a shop belonging to "..
			meta:get_string("owner").." at "..
			minetest.pos_to_string(pos))
			return 0
		end
		return stack:get_count()
	end,
	allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		local meta = minetest.get_meta(pos)
		if not has_shop_privilege(meta, player) then
			minetest.log("action", player:get_player_name()..
					" tried to access a shop belonging to "..
					meta:get_string("owner").." at "..
					minetest.pos_to_string(pos))
			return 0
		end
		return stack:get_count()
	end,
	on_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		minetest.log("action", player:get_player_name().." moves stuff in shop at "..minetest.pos_to_string(pos))
	end,
	on_metadata_inventory_put = function(pos, listname, index, stack, player)
		minetest.log("action", player:get_player_name().." moves stuff to shop at "..minetest.pos_to_string(pos))
	end,
	on_metadata_inventory_take = function(pos, listname, index, count, player)
		minetest.log("action", player:get_player_name().." takes stuff from shop at "..minetest.pos_to_string(pos))
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		local meta = minetest.get_meta(pos)
		if meta:get_string("form") == "yes" then
			if fields.shopname ~= "" and minetest.registered_items[fields.nodename] and tonumber(fields.amount) and tonumber(fields.amount) >= 1 and tonumber(fields.amount) <= 99 and (meta:get_string("owner") == sender:get_player_name() or minetest.get_player_privs(sender:get_player_name())["money_admin"]) then
				if fields.action == "Sell" then
					if not tonumber(fields.costbuy) then
						return
					end
					if not (tonumber(fields.costbuy) >= 0) then
						return
					end
				end
				if fields.action == "Buy" then
					if not tonumber(fields.costsell) then
						return
					end
					if not (tonumber(fields.costsell) >= 0) then
						return
					end
				end
				if fields.action == "Buy and Sell" then
					if not tonumber(fields.costbuy) then
						return
					end
					if not (tonumber(fields.costbuy) >= 0) then
						return
					end
					if not tonumber(fields.costsell) then
						return
					end
					if not (tonumber(fields.costsell) >= 0) then
						return
					end
				end
				local s, ss
				if fields.action == "Sell" then
					s = " sell "
					ss = "button[1,4.5;2,1;buttonsell;Sell("..fields.costbuy..")]"
				elseif fields.action == "Buy" then
					s = " buy "
					ss = "button[1,4.5;2,1;buttonbuy;Buy("..fields.costsell..")]"
				else
					s = " buy and sell "
					ss = "button[1,4.5;2,1;buttonbuy;Buy("..fields.costsell..")]" .. "button[5,4.5;2,1;buttonsell;Sell("..fields.costbuy..")]"
				end
				local meta = minetest.get_meta(pos)
				meta:set_string("formspec", "size[8,9.35;]"..default.gui_bg..default.gui_bg_img..
					"list[context;main;0,0;8,4;]"..
					"label[1.5,4;You can"..s..fields.amount.." "..fields.nodename.."]"..
						ss..
					"list[current_player;main;0,5.5;8,4;]")
				meta:set_string("shopname", fields.shopname)
				meta:set_string("action", fields.action)
				meta:set_string("nodename", fields.nodename)
				meta:set_string("amount", fields.amount)
				meta:set_string("costbuy", fields.costbuy)
				meta:set_string("costsell", fields.costsell)
				meta:set_string("infotext", "Shop \"" .. fields.shopname .. "\" (owned by " .. meta:get_string("owner") .. ")")
				meta:set_string("form", "no")
			end
		elseif fields["buttonbuy"] then
			local sender_name = sender:get_player_name()
			local inv = meta:get_inventory()
			local sender_inv = sender:get_inventory()
			if not inv:contains_item("main", meta:get_string("nodename") .. " " .. meta:get_string("amount")) then
				minetest.chat_send_player(sender_name, "Not enough goods in the shop.")
				return true
			elseif not sender_inv:room_for_item("main", meta:get_string("nodename") .. " " .. meta:get_string("amount")) then
				minetest.chat_send_player(sender_name, "Not enough space in your inventory.")
				return true
			elseif get_money(sender_name) - tonumber(meta:get_string("costsell")) < 0 then
				minetest.chat_send_player(sender_name, "You don't have enough money.")
				return true
			elseif not exist(meta:get_string("owner")) then
				minetest.chat_send_player(sender_name, "The owner's account does not currently exist; try again later.")
				return true
			end
			set_money(sender_name, get_money(sender_name) - meta:get_string("costsell"))
			set_money(meta:get_string("owner"), get_money(meta:get_string("owner")) + meta:get_string("costsell"))
			sender_inv:add_item("main", meta:get_string("nodename") .. " " .. meta:get_string("amount"))
			inv:remove_item("main", meta:get_string("nodename") .. " " .. meta:get_string("amount"))
			minetest.chat_send_player(sender_name, "You bought " .. meta:get_string("amount") .. " " .. meta:get_string("nodename") .. " at a price of " .. CURRENCY_PREFIX .. meta:get_string("costsell") .. CURRENCY_POSTFIX .. ".")
		elseif fields["buttonsell"] then
			local sender_name = sender:get_player_name()
			local inv = meta:get_inventory()
			local sender_inv = sender:get_inventory()
			if not sender_inv:contains_item("main", meta:get_string("nodename") .. " " .. meta:get_string("amount")) then
				minetest.chat_send_player(sender_name, "You do not have enough product.")
				return true
			elseif not inv:room_for_item("main", meta:get_string("nodename") .. " " .. meta:get_string("amount")) then
				minetest.chat_send_player(sender_name, "Not enough space in the shop.")
				return true
			elseif get_money(meta:get_string("owner")) - meta:get_string("costbuy") < 0 then
				minetest.chat_send_player(sender_name, "The buyer is not enough money.")
				return true
			elseif not exist(meta:get_string("owner")) then
				minetest.chat_send_player(sender_name, "The owner's account does not currently exist; try again later.")
				return true
			end
			set_money(sender_name, get_money(sender_name) + meta:get_string("costbuy"))
			set_money(meta:get_string("owner"), get_money(meta:get_string("owner")) - meta:get_string("costbuy"))
			sender_inv:remove_item("main", meta:get_string("nodename") .. " " .. meta:get_string("amount"))
			inv:add_item("main", meta:get_string("nodename") .. " " .. meta:get_string("amount"))
			minetest.chat_send_player(sender_name, "You sold " .. meta:get_string("amount") .. " " .. meta:get_string("nodename") .. " at a price of " .. CURRENCY_PREFIX .. meta:get_string("costbuy") .. CURRENCY_POSTFIX .. ".")
		end
	end,
})

minetest.register_craft({
	output = "money:shop",
	recipe = {
		{"default:wood", "default:wood", "default:wood"},
		{"default:wood", "default:mese", "default:wood"},
		{"default:wood", "default:wood", "default:wood"},
	},
})
