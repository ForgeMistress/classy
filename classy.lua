------------------------------------------------------------------------------------------------------------------------
--  
--  classy.lua
--
--  Class implementation for lua. Not as small as middleclass, but a whole hell of a lot faster.
--
------------------------------------------------------------------------------------------------------------------------
local __classtag = {}

-- UTILITIES --
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

function tbl_to_str( tbl )
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

-- Merge the right table with the left and return the left. Asserts on duplicate keys.
local function _mergeTables(className, left, right)
	if right == nil then return left end
	
	for k, v in pairs(right) do
		assert(left[k] == nil, "Duplicate key detected: Key = "..k.." Class = "..className)
		left[k] = v
	end
	return left
end
-- END UTILITIES --

local classy = {}

local function __makeAllocatorFunction(className, classTemplate, super)
	local final
	if super then
		final = _mergeTables(className, classTemplate, super.allocator(super))
	else
		final = classTemplate
	end
	local classTemplateStr = private.tbl_to_str(final)
	if not super then
		classTemplateStr = "{class=0,"..classTemplateStr:sub(2, classTemplateStr:len())
	end
	return assert(loadstring("return "..classTemplateStr, className))
end

local __maxClassID = 0
local function __makeClassID(klass)
	local id = __maxClassID + 1
	__maxClassID = id
	return id
end

local function _classFinalize(klass)
	if klass.__m_instanceMT then
		error("AssertNotFinalized: Class "..klass.name.." has already been finalized.", 2)
	end

	if klass.super then
		setmetatable(klass.methods, { __index=klass.super.methods })
		setmetatable(klass.static, { __index=klass.super.static })
	end
	
	klass.__m_instanceMT = {
		__index = klass.methods;
		__tostring = ("instance of "..klass.name);
	}
	
	return klass
end

local function _classNew(klass, ...)
	if not klass.__m_instanceMT then
		error("AssertFinalized: Class "..klass.name.." has not been finalized.", 2)
	end
	
	local instance = klass.allocator()
	instance.class = klass
	
	instance = setmetatable(instance, klass.__m_instanceMT)
	
	if instance.__init__ then
		instance.__init__(instance, ...)
	end
	
	for mixin in pairs(klass.mixins) do
		if mixin.__init__ then
			mixin.__init__(instance)
		end
	end

	return instance
end

local function _classSubclass(klass, name, subclassTemplate)
	if not klass.__m_instanceMT then
		error("AssertFinalized: Class "..klass.name.." has not been finalized.", 2)
	end
	return classy._defineClassImpl(name, subclassTemplate, klass)
end

local function _classInclude(klass, mixin)
	if klass.__m_instanceMT then
		error("AssertNotFinalized: Class "..klass.name.." has already been finalized.", 2)
	end
	assert(not klass.mixins[mixin], "Mixin already included.")
	
	klass.methods = _mergeTables(klass.name, klass.methods, mixin.methods)
	klass.static = _mergeTables(klass.name, klass.static, mixin.static)

	klass.mixins[mixin] = true
end

local __classMT = {
	__index = function(klass, key)
		return klass.static[key] or klass.methods[key]
	end;
	
	__tostring = function(klass)
		return "class "..klass.name
	end;
	
	__newindex = function(klass, key, value)
		if klass.__m_instanceMT then
			error("AssertNotFinalized: Class "..klass.name.." has already been finalized.", 2)
		end
		
		if type(value) == 'function' then
			klass.methods[key] = value
			return
		end
	end;
}

local function _instanceIsInstanceOf(instance, klass)
	return instance.class:IsSubclassOf(klass)
end

local function _classIsSubclassOf(klass, otherKlass)
	if klass.id == otherKlass.id then 
		return true 
	end
	
	if klass.super then
		return klass.super:IsSubclassOf(otherKlass)
	end
	
	return false
end

-- Process for making a class:
--    Call class() or Class:subclass() while passing it in a template table.
function classy._defineClassImpl(name, classTemplate, superclass)
	classTemplate = classTemplate or {}
	for k, v in pairs(classTemplate) do
		assert(type(v) ~= 'function', string.format("Functions are not allowed in class templates. Class: %s, Key: %s", name, k))
		assert(k ~= "class", "Can't use the key 'class' in your definition.")
		assert(k ~= "super", "Can't use the key 'super' in your definition.")
	end

	local classtbl = {
		name=name;
		super=superclass;

		allocator = __makeAllocatorFunction(name, classTemplate, superclass);

		methods = {
			IsInstanceOf = _instanceIsInstanceOf;
		};
		
		static = {
			IsSubclassOf = _classIsSubclassOf;
		};
		mixins = {};
		
		id     = __makeClassID();

		new      = _classNew;
		subclass = _classSubclass;
		finalize = _classFinalize;
		include  = _classInclude;

		__m_instanceMT = false;

		__CLASSTAG__ = __classtag;
	}
	classtbl = setmetatable(classtbl, __classMT)
	
	return classtbl
end

function classy.isclass(klass)
	return klass.__CLASSTAG__ == __classtag
end

function classy.isinstance(input)
	return input.class and input.class.__CLASSTAG__ == __classtag
end

return setmetatable(classy, {__call = function(_, ...) return classy._defineClassImpl(...) end })