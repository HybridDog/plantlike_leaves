local load_time_start = os.clock()


if not minetest.setting_getbool"plantlike_leaves" then
	return
end

local leaves_wave = minetest.setting_getbool"waving_plants"
local leaves_unsolid = minetest.setting_getbool"plantlike_leaves_unsolid"
local only_default = minetest.setting_getbool"plantlike_default_only"
-- note: using degrotate breaks default leafdecay
local rotated_leaves = minetest.setting_getbool"plantlike_leaves_rotated"

local leaves,n = {},1
for name,def in pairs(minetest.registered_nodes) do
	if def.drawtype == "allfaces_optional" then
		if (name:find"leaves"
			or name:find"needle"
		) and (not only_default
			or name:sub(1, 8) == "default:"
		) then
			leaves[n] = name
			n = n+1
		else
			minetest.log("info", "[plantlike_leaves] skipping "..name)
		end
	end
end

local function test(bool, msg)
	if not bool then
		error("[plantlike_leaves] "..msg)
	end
end

local rt2 = math.sqrt(2)
local change_texture
if not rotated_leaves
and not leaves_wave then
	local tex_sc = (1 - (1 / rt2)) * 100 - 4
	function change_texture(texture)
		--return texture.."^[transform2^[lowpart:"..tex_sc..":plantlike_leaves.png^[transform2^[makealpha:255,126,126"
		return texture.."^[lowpart:"..tex_sc..":plantlike_leaves.png^[makealpha:255,126,126"
	end
end


local data = {
	visual_scale = math.sqrt(rt2),
	--~ visual_scale = rt2,
	drawtype = "plantlike",
}

local leaves_ids, after_place_leaves
if rotated_leaves then
	data.paramtype2 = "degrotate"

	function after_place_leaves(pos)
		local node = minetest.get_node(pos)
		node.param2 = math.random(0,179)
		minetest.set_node(pos, node)
	end

	leaves_ids = {}
	for _,name in pairs(leaves) do
		leaves_ids[minetest.get_content_id(name)] = true
	end
end

if leaves_unsolid then
	data.walkable = false
end

for _,name in pairs(leaves) do
	local def = minetest.registered_nodes[name]
	--test(def, name.." doesn't seem to be a node")
	--test(def.drawtype ~= "plantlike", name.." is already plantlike")
	if rotated_leaves then
		if def.after_place_node then
			local old_after_place = def.after_place_node
			data.after_place_node = function(pos, ...)
				local v = old_after_place(pos, ...)
				after_place_leaves(pos)
				return v
			end
		else
			-- data.after_place_node was the previous one
			data.after_place_node = after_place_leaves
		end
	end

	local texture = def.tiles
	test(texture, name.." doesn't have tiles")

	texture = texture[1]
	test(texture, name.." doesn't have a texture")

	if change_texture then
		data.tiles = {change_texture(texture)}
	end
	data.inventory_image = texture

	minetest.override_item(name, data)
end

data = nil


if rotated_leaves then
	local function log(msg)
		--[[
		msg = "[plantlike_leaves] "..msg
		minetest.chat_send_all(msg)
		minetest.log("info", msg)--]]
		minetest.log("info", "[plantlike_leaves] "..msg)
	end

	minetest.register_on_generated(function(minp, maxp, seed)
		--avoid calculating perlin noises for unneeded places
		if maxp.y <= -6
		or minp.y >= 150 then
			return
		end

		local t1 = tonumber(os.clock())

		local pr = PseudoRandom(seed+53)

		local vm, emin, emax = minetest.get_mapgen_object"voxelmanip"
		local data = vm:get_data()
		local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax} -- TODO: why does this work?

		local param2s

		local heightmap = minetest.get_mapgen_object"heightmap"
		if not heightmap then
			return
		end
		local hmi = 1

		for z = minp.z, maxp.z do
			for x = minp.x, maxp.x do
				local y = heightmap[hmi]
				for p_pos in area:iter(x,y+1,z, x,y+20,z) do
					if leaves_ids[data[p_pos]] then
						if not param2s then
							param2s = vm:get_param2_data()
						end
						param2s[p_pos] = pr:next(0, 179)
					end
				end
				hmi = hmi+1
			end
		end

		if param2s then
			vm:set_param2_data(param2s)
			vm:write_to_map()
			log"leaves found"
		end
		log("done after ca. "..math.floor(tonumber(os.clock()-t1)*100+0.5)/100)
	end)
end


local time = math.floor(tonumber(os.clock()-load_time_start)*100+0.5)/100
local msg = "[plantlike_leaves] loaded after ca. "..time
if time > 0.05 then
	print(msg)
else
	minetest.log("info", msg)
end
