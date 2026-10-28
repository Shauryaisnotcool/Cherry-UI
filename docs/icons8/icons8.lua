--[[
	docs/icons8/icons8.lua
	A ready-to-fill icon pack for Cherry UI using icons8 artwork.

	HOW TO USE
	  1. Download the white PNGs from icons8.com (see README.md in this folder).
	  2. Upload them to Roblox and copy each asset id.
	  3. Replace the placeholder ids below.
	  4. Load this file right after Cherry UI, before CreateWindow:

	        local CherryUI = getgenv().CherryUI
	        CherryUI:SetIcons(loadstring(game:HttpGet("<raw url>/docs/icons8/icons8.lua"))())

	     or copy the table into your own script.

	Leave a value as "" to keep Cherry UI's drawn icon for that name.
	The keys are the public icon names; `CherryUI.Icons.resolve` also maps
	friendly aliases (crosshair, aimbot, esp, gear, spectate, …) onto them.
]]

return {
	-- Tabs -----------------------------------------------------------------
	target = "", -- icons8 "crosshair"
	layers = "", -- icons8 "layers"
	players = "", -- icons8 "conference call"
	settings = "", -- icons8 "settings"
	eye = "", -- icons8 "eye"          (spectate)

	-- Window chrome ---------------------------------------------------------
	search = "", -- icons8 "search"
	close = "", -- icons8 "close"
	chevron = "", -- icons8 "chevron down"
	refresh = "", -- icons8 "refresh"
	copy = "", -- icons8 "copy"
	diamond = "", -- icons8 "diamond"

	-- State & notices -------------------------------------------------------
	check = "", -- icons8 "checkmark"
	info = "", -- icons8 "info"
	warning = "", -- icons8 "error"
	success = "", -- icons8 "checkmark"
	error = "", -- icons8 "cancel"
}
