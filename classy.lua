------------------------------------------------------------------------------------------------------------------------
--  
--  classy.lua
--
--  Class implementation for lua. Not as small as middleclass, but a whole hell of a lot faster.
--
------------------------------------------------------------------------------------------------------------------------
local __ftCache = require(((...):match("(.-)[^%.]+$"))..".footable")("classy")
local __classtag = {}

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

-- Module. Functions are defined towards the bottom of the file.
local classy = {
	class = 0;
	isfinalized = 0;
	isinstanceof = 0;
	isclass = 0;
	isinstance = 0;
	type = 0;
}
local function _makeAllocatorFunction(...)
	local arg = {...}
	local className = arg[1]
	local classTemplate = arg[2]
	local super = arg[3]
	
	local final
	if super then
		final = _mergeTables(className, classTemplate, __ftCache:allocatelua(super.__name__))
	else
		final = classTemplate
	end
	return __ftCache:definelua(className, final)
end

local __maxClassID = 0
local function _makeClassID(klass)
	local id = __maxClassID + 1
	__maxClassID = id
	return id
end

local function _instanceToString(instance)
	return ("instance of "..instance.__class__.__name__)
end

local function _classWrapIndex(klass)
	return function(instance, key)
		return klass.methods[key] or klass.methods.__index__(instance, key)
	end
end
local function _classFinalize(klass)
	if klass.__m_instMT then
		error("AssertNotFinalized: Class "..klass.__name__.." has already been finalized.", 2)
	end
	
	klass.methods.__class__ = klass

    if klass.mixins[1] then
        -- Change the mixin table from a set to an array for faster allocation.
        local newMixinTbl = {}
        for _, mixin in ipairs(klass.mixins) do
            if mixin.__onfinalize__ then
                mixin.__onfinalize__(klass)
            end
        end
    end

	if klass.__super__ then
		klass.methods.super = klass.__super__
		klass.methods.__super__ = klass.__super__
		setmetatable(klass.methods, { __index=klass.__super__.methods })
		-- This might mess some things up. TODO: Test if this messes things up.
		setmetatable(klass.static, { __index=klass.__super__.static })
	end
	
    -- Metatable support right there in the class definition. You're welcome. ;)
	klass.__m_instMT = {
		__index    = ((klass.methods.__index__ and _classWrapIndex(klass)) or klass.methods);
		__tostring =  (klass.methods.__tostring__                          or _instanceToString);
		__eq       =  (klass.methods.__eq__                                or nil);
		__lt       =  (klass.methods.__lt__                                or nil);
		__gt       =  (klass.methods.__gt__                                or nil);
		__call     =  (klass.methods.__call__                              or nil);
	}

	return klass
end

local function _classNew(klass, ...)
	if not klass.__m_instMT then
		error("AssertFinalized: Class "..klass.__name__.." has not been finalized.", 2)
	end
	
	local instance = __ftCache:allocatelua(klass.__name__)

	instance = setmetatable(instance, klass.__m_instMT)
	
	if instance.__init__ then
		instance.__init__(instance, ...)
	end
	
    if klass.mixins[1] then
        for _, mixin in ipairs(klass.mixins) do
            if mixin.__init__ then
                mixin.__init__(instance)
            end
        end
    end

	return instance
end

local function _classSubclass(klass, name, subclassTemplate)
	if classy.type(klass) ~= 'class' then
		error("Subclass must be called as <Object>:subclass ("..classy.type(klass)..").")
	end
	if not klass.__m_instMT then
		error("AssertFinalized: Class "..klass.__name__.." has not been finalized.", 2)
	end
	
	local classImpl = classy.class(name, subclassTemplate, klass)
	if klass.__super__ then
        local superStatic = klass.__super__.static
		if superStatic.__onsubclassed__ then
			superStatic.__onsubclassed__(classImpl)
		end
	end
	return classImpl
end

local function _classInclude(klass, mixin)
	if not mixin then
		error("Mixin added to class "..klass.__name__.." was nil.", 2)
	end
	if klass.__m_instMT then
		error("AssertNotFinalized: Class "..klass.__name__.." has already been finalized.", 2)
    end
    for _, mix in ipairs(klass.mixins) do
        if mix == mixin then
            error("Mixin already included in class "..klass.__name__..".", 2)
        end
    end
    table.insert(klass.mixins, mixin)
	
	klass.methods = _mergeTables(klass.__name__, klass.methods, mixin.methods)
	klass.static = _mergeTables(klass.__name__, klass.static, mixin.static)
	
	if type(mixin.__oninclude__) == 'function' then
		mixin.__oninclude__(klass)
	end

	return klass
end

local function _classIsSubclassOf(klass, otherKlass)
	if klass.__id__ == otherKlass.__id__ then 
		return true 
	end

	if klass.__super__ then
		return _classIsSubclassOf(klass.__super__, otherKlass)
	end

	return false
end

local function _classNewIndex(klass, key, value)
	assert(not klass.__m_instMT, "AssertNotFinalized: Class "..klass.__name__.." has already been finalized.")

	if type(value) == 'function' then
		klass.methods[key] = value
		return
	end

	assert(not klass.static[key], "Class already has key "..key)
	klass.static[key] = value
end

local function _classEq(left, right)
	assert(classy.isclass(left) and classy.isclass(right))
	return left.__id__ == right.__id__
end

local function _classToString(klass) 
	return ("class "..klass.__name__) 
end

local function _checkKeys(name, template)
	for k, v in pairs(template) do
		assert(type(v) ~= 'function', string.format("Functions are not allowed in class templates. Class: %s, Key: %s", name, k))
		assert(k ~= "__class__", "Can't use the key '__class__' in your definition.")
		assert(k ~= "__super__", "Can't use the key '__super__' in your definition.")
	end
end

-- Process for making a class:
--    Call class() or Class:subclass() while passing it in a template table.
function classy.class(name, classTemplate, superclass)
	classTemplate = classTemplate or {}
	_checkKeys(name, classTemplate)
	if _makeAllocatorFunction(name, classTemplate, superclass) then
		local classtbl = {
			__classtag__ = __classtag;
			__name__  = name;
			__super__ = superclass;
			__id__    = _makeClassID();
			methods = {};
			static = {
				IsSubclassOf = _classIsSubclassOf;
				fulfill = _classFulfill;
			};

			mixins = {};

			new      = _classNew;
			subclass = _classSubclass;
			finalize = _classFinalize;
			include  = _classInclude;

			__m_instMT = false;
		}
		
		setmetatable(classtbl.static, { 
			__index = classtbl.methods 
		});
		
		classtbl = setmetatable(classtbl, {
			__index    = classtbl.static;
			__tostring = _classToString;
			__newindex = _classNewIndex;
			__eq       = _classEq;
		})
		
		return classtbl
	end
	return nil, "Failed to define footable."
end

function classy.isfinalized(klass)
	return type(klass.__m_instMT) ~= 'boolean'
end

function classy.isclass(klass)
	if type(klass) ~= 'table' then return false end
	return klass.__classtag__ == __classtag
end

function classy.isinstance(input)
	if type(input) ~= 'table' then return false end
	return input.__class__ and input.__class__.__classtag__ == __classtag
end

function classy.isinstanceof(instance, klass)
	assert(classy.type(instance) == 'instance')
	return _classIsSubclassOf(instance.__class__, klass)
end

----------------------------------------------------------------------------------------------------------------
-- Extension of the native lua type() function. Returns 'instance' if the type is an instance of any class,
-- or 'class' if the item is a class definition. Otherwise it will return the result of type().
-- Returns one of the following:
--    'instance' - An instance of a classy class.
--    'class'    - A classy class definition.
--    'callable' - A table with the __call metamethod defined.
--    type(item) - If none of the above are true, then it will return the result of lua's type() function.
function classy.type(item)
	if classy.isclass(item)    then return 'class'    end
	if classy.isinstance(item) then return 'instance' end

	local it = type(item)
	if it == 'table' and getmetatable(it).__call then return 'callable' end
	return it
end

return setmetatable(classy, {
	__call = function(_, ...) 
		return classy.class(...) 
    end
})
