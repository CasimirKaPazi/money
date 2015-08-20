--[[
	Mod by Kotolegokot and Xiong (2012-2013)
	Rev. kilbith and nerzhul (2015)
]]

money = {}

dofile(minetest.get_modpath("money") .. "/settings.txt") -- Loading settings.
dofile(minetest.get_modpath("money") .. "/hud.lua") -- Account display in HUD.
dofile(minetest.get_modpath("money") .. "/functions.lua") -- Manage accounts and send money.
dofile(minetest.get_modpath("money") .. "/shop.lua") -- Buy and sell nodes.

