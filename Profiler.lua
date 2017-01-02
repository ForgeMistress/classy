------------------------------------------------------------------------------------------------------------------------
--
--  Profiler.lua
--
--  A profiler object.
--
------------------------------------------------------------------------------------------------------------------------
local Profiler = {
	Start = function(self)
		assert(not self.__m_running)
		self.__m_running = true
		self.__m_startTime = os.clock()
		self.__m_startMemory = collectgarbage("count")
	end;
	
	Stop = function(self)
		assert(self.__m_running)
		self.__m_running = false
		self.__m_stopTime = os.clock()
		self.__m_stopMemory = collectgarbage("count")
	end;
	
	GetElapsedTime = function(self)
		return self.__m_stopTime - self.__m_startTime
	end;
	
	GetMemoryUsage = function(self)
		return self.__m_stopMemory - self.__m_startMemory
	end;
	
	GetFormattedReport = function(self)
		local timeElapsedSeconds = self:GetElapsedTime()
		local memoryUsageKb = self:GetMemoryUsage()
		return 
([[
================================================================================
== Profiler: %s
================================================================================
Elapsed time           : %f Seconds
Starting Memory        : %f Kb (%f Mb)
Stopping Memory        : %f Kb (%f Mb)
Change in memory usage : %f Kb (%f Mb)]])
:format(
	self.__m_name,
	self:GetElapsedTime(), 
	self.__m_startMemory, self.__m_startMemory/1024,
	self.__m_stopMemory, self.__m_stopMemory/1024,
	memoryUsageKb, memoryUsageKb/1024)
	end;
	
	__tostring = function(self)
		return ("profiler "..self.__m_name)
	end;
	
	__index = 0;
}
Profiler.__index = Profiler

local __s_profilers = {}

function Profiler.new(name)
	if __s_profilers[name] then
		return __s_profilers[name]
	end
	
	local instance = {
		__m_name = name;
		__m_running = false;
		__m_startTime = 0.0;
		__m_stopTime = 0.0;
		__m_startMemory = 0.0;
		__m_stopMemory = 0.0;
	}
	return setmetatable(instance, Profiler)
end

function Profiler.delete(name)
	__s_profilers[name] = nil
end

return Profiler