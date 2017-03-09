------------------------------------------------------------------------------------------------------------------------
--
--  footable.lua
--
--  Couldn't think of a name for a library that makes tables using luajit's ffi based on definitions. So sue me!
--
------------------------------------------------------------------------------------------------------------------------
local __s_caches = setmetatable({}, {__mode='v'})

local footableMT = {
	defineffi =   function(params) error("ffi is not available in this lua runner.", 2); end,
	allocateffi = function(params) error("ffi is not available in this lua runner.", 2); end,
	
	definelua =   0,
	allocatelua = 0,
	
	get = 0;
	isdefined = 0;
}
footableMT.__index = footableMT

if jit and require("ffi") then
	local ffi = require("ffi")
	local FFI_STRING_TYPE = ffi.typeof("const char*")
	
	footableMT.defineffi = function(self, params)
		tblMT = tblMT or {}
		local nname = params.name:gsub("%.", "__")
		if not self.__definedTables[params.name] and not __s_ffiTypes[nname] then
			local tbldef = string.format([[
				typedef struct %s 
					%s
				%s;
			]], nname, params.def, nname)
			ffi.cdef(tbldef)
			self.__definedTables[name] = ffi.metatype(ffi.typeof(nname), tblMT)
		else
			return false, "FFI-Based Table "..name.." is already defined (remember, ffi tables can only be globally "..
						  "defined)."
		end
		
		return self.__definedTables[params.name] ~= nil
	end
	
	local __footableFFIMT = {
		__index = function(self, key)
			if ffi.istype(FFI_STRING_TYPE, self.__m_cdata[key]) then
				return ffi.string(self.__m_cdata[key])
			end
			return self.__m_cdata[key]
		end;
	}
	
	footableMT.allocateffi = function(self, name)
		assert(self.__definedTables[name], "Table definition '"..name.."' is undefined.")
		return setmetatable({
			__m_cdata = self.__definedTables[name](params)
		}, footableFFIMT)
	end
end


--[[ PURE LUA ]]--
local private = {}
local function __val_to_str ( v )
	local vType = type( v )
	if vType == 'string' then
		v = string.gsub( v, "\n", "\\n" )
		if string.match( string.gsub(v,"[^'\"]",""), '^"+$' ) then
			return "'" .. v .. "'"
		end
		return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
	elseif vType == 'table' then
		return private.tbl_to_str( v )
	else
		return tostring( v )
	end
end

local function __key_to_str ( k, minify )
	local kType = type( k )
	if kType == 'string' and string.match( k, "^[_%a][_%a%d]*$" ) then
		return k
	else
		return "[" .. __val_to_str( k ) .. "]"
	end
end

local function tbl_to_str( tbl )
	local ind = ind or 0
	local result, done = {}, {}
	for k, v in ipairs( tbl ) do
		table.insert( result, __val_to_str( v ) )
		done[ k ] = true
	end
	for k, v in pairs( tbl ) do
		if not done[ k ] then
			table.insert( result, __key_to_str( k ) .. "=" .. __val_to_str( v ) )
		end
	end
	return "{" .. table.concat( result, "," ) .. "}"
end
private.tbl_to_str = tbl_to_str

footableMT.definelua = function(self, name, tbl)
	if name == nil then
		error("Name is nil.", 2)
	end
	assert(self.__definedTables[name] == nil, "Table definition '"..name.."' already exists.")
	local allocatorString = "return "..private.tbl_to_str(tbl)
	self.__definedTables[name] = assert(loadstring(allocatorString))
	return true
end

footableMT.allocatelua = function(self, name)
	assert(self.__definedTables[name] ~= nil, "Table definition '"..name.."' is undefined.")
	return self.__definedTables[name]()
end

footableMT.get = function(self, name)
	return self.__definedTables[name] or nil
end

footableMT.isdefined = function(self, name)
	return self.__definedTables[name] ~= nil
end

local function _makeNewFootableCache(name)
	if __s_caches[name] then
		return __s_caches[name]
	end
	
	local ftCache = setmetatable({
		__definedTables = {}
	}, footableMT)
	__s_caches[name] = ftCache
	return ftCache
end
return _makeNewFootableCache