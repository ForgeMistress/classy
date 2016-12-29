
local classlib = arg[1]
local test = arg[2]
local iterations = arg[3] or 500000

local class 
if classlib == 'classy' then
	class = require("classy")

elseif classlib == 'middleclass' then
	class = require("middleclass")

end
local ProFi = require("ProFi")

local note = classlib..' '..test
local file = 'Profiler/'..classlib..'-'..test..'-result.txt'

print(string.format("Profiling %s Class %s: %d iterations", classlib, test, iterations))

local BaseClass 
local Subclass
local DoubleSubclass

if classlib == 'classy' then
	if test == 'classes' then
		ProFi:start(nil)
	end
	BaseClass = class("BaseClass", {
		Bar        = 0;
		Baz        = 0;
		Foo        = 0;
	})
	function BaseClass:__init__(foo,bar,baz)
		self.Foo = foo
		self.Bar = bar
		self.Baz = baz
	end

	function BaseClass:func()
		self.Bar = self.Bar + 1
	end

	BaseClass = BaseClass:finalize()
	
	Subclass = BaseClass:subclass("Subclass", {
		NewTable = 0;
		NewBoolean = false;
	})
	function Subclass:__init__(foo, bar, baz, bool)
		BaseClass.__init__(self, foo, bar, baz)
		self.NewTable = {"Test Table"}
		self.NewBoolean = bool
	end
	Subclass = Subclass:finalize()
	
	DoubleSubclass = Subclass:subclass("DoubleSubclass", {
		AnotherNewTable = 0;
	})
	function DoubleSubclass:__init__(bar)
		Subclass.__init__(self, 2, bar, "String value!", false)
		self.AnotherNewTable = {}
	end
	DoubleSubclass = DoubleSubclass:finalize()
	
	if test == 'classes' then
		ProFi:checkMemory(0, "BaseClass/Subclass/DoubleSubclass "..classlib)
		ProFi:stop()
		ProFi:writeReport("Profiler/"..classlib.."-"..test.."-memory-result.txt")
	end
elseif classlib == 'middleclass' then
	if test == 'classes' then
		ProFi:start(nil)
	end
	BaseClass = class("BaseClass")
	function BaseClass:initialize(foo,bar,baz)
		self.Foo = foo
		self.Bar = bar
		self.Baz = baz
	end

	function BaseClass:func()
		self.Bar = self.Bar + 1
	end
	
	Subclass = BaseClass:subclass("Subclass")
	function Subclass:initialize(foo, bar, baz, bool)
		BaseClass.initialize(self, foo, bar, baz)
		self.NewTable = {"Test Table"}
		self.NewBoolean = bool
	end
	
	DoubleSubclass = Subclass:subclass("DoubleSubclass")
	function DoubleSubclass:initialize(bar)
		Subclass.initialize(self, 2, bar, "String value!", false)
		self.AnotherNewTable = {}
	end
	if test == 'classes' then
		ProFi:checkMemory(0, "BaseClass/Subclass/DoubleSubclass "..classlib)
		ProFi:stop()
		ProFi:writeReport("Profiler/"..classlib.."-"..test.."-memory-result.txt")
	end
end

if test == 'allocation' then
	print("Preallocating insertion table...")
	local t = {}
	for i=1, iterations do
		t[i] = true
	end
	collectgarbage()
	print("done!")

	local i

	local tbl_insert = table.insert
	
	ProFi:start(nil)
	for i=1, iterations do
		t[i] = BaseClass:new(2, 3, "String value!")
	end
	collectgarbage()
	ProFi:checkMemory(0, note.." Iteration "..iterations)
	ProFi:stop()
	ProFi:writeReport(file)
	
elseif test == 'methods' then
	local bar = 3
	local instance = BaseClass:new(2, bar, "String value!")
	
	ProFi:start(nil)
	for i=1, iterations do
		instance:func()
	end
	collectgarbage()
	ProFi:checkMemory(0, note.." Iteration "..iterations)
	ProFi:stop()
	ProFi:writeReport(file)
	
	assert(instance.Bar == bar + iterations, "Result expected from function calls was wrong. Expected: "..bar + iterations.." Got: "..instance.Bar)

elseif test == 'inheritance-allocation' then
	print("Preallocating insertion table...")
	local t = {}
	for i=1, iterations do
		t[i] = true
	end
	collectgarbage()
	print("done!")

	local i

	local tbl_insert = table.insert
	
	ProFi:start(nil)
	for i=1, iterations do
		t[i] = DoubleSubclass:new(3)
	end
	collectgarbage()
	ProFi:checkMemory(0, note.." Iteration "..iterations)
	ProFi:stop()
	ProFi:writeReport(file)
	
elseif test == 'inheritance-methods' then
	local bar = 3
	local instance = DoubleSubclass:new(bar)
	
	ProFi:start(nil)
	for i=1, iterations do
		instance:func()
	end
	collectgarbage()
	ProFi:checkMemory(0, note.." Iteration "..iterations)
	ProFi:stop()
	ProFi:writeReport(file)
	assert(instance.Bar == bar + iterations, "Result expected from function calls was wrong. Expected: "..bar + iterations.." Got: "..instance.Bar)
end
