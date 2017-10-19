---------------------------------------------------------------------------
-- RollingFileAppender is a FileAppender that rolls over the logfile
-- once it has reached a certain size limit. It also mantains a
-- maximum number of log files.
--
-- @author Tiago Cesar Katcipis (tiagokatcipis@gmail.com)
--
-- @copyright 2004-2013 Kepler Project
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- TODO:
-- 1: log func trace back level
-- 2: multiple file
---------------------------------------------------------------------------
local logging = require"logging"


local function openFile(self)
	self.file = io.open(self.filename, "a")
	if not self.file then
		return nil, string.format("file `%s' could not be opened for writing", self.filename)
	end
	self.file:setvbuf ("line")
	return self.file
end

local rollOver = function (self)
	for i = self.maxIndex - 1, 1, -1 do
		-- files may not exist yet, lets ignore the possible errors.
		os.rename(self.filename.."."..i, self.filename.."."..i+1)
	end

	self.file:close()
	self.file = nil

	local _, msg = os.rename(self.filename, self.filename..".".."1")

	if msg then
		return nil, string.format("error %s on log rollover", msg)
	end

	return openFile(self)
end


local openRollingFileLogger = function (self)
	if not self.file then
		return openFile(self)
	end

	local filesize = self.file:seek("end", 0)

	if (filesize < self.maxSize) then
		return self.file
	end

	return rollOver(self)
end


function logging.rolling_file(filename, maxFileSize, maxBackupIndex, logPattern)
	if type(filename) ~= "string" then
		filename = "lualogging.log"
	end


	local OBJ = {
		file = nil,
		base_name = filename,
		maxSize  = maxFileSize,
		maxIndex = maxBackupIndex or 1,
		date = os.time()
	}

	function OBJ:new(o)
		o = o or {}
		setmetatable(o, self)
		self.__index = self
		return o
	end


	local logs = {}

	local function is_change_day(tbl)
		local cu_day = os.date("*t", os.time()).day
		local last_day = os.date("*t", tbl.date).day
		return cu_day ~= last_day
	end

	local function format_filename(obj, level)
		-- file name format: yyyy-mm-dd-basename-LEVEL.log
		return os.date("%Y-%m-%d", obj.date) .. "-" .. obj.base_name .. "-" .. level .. ".log"
	end

	return logging.new( function(self, level, message)
		if logs[level] == nil then
			logs[level] = OBJ:new()
			local log_info = logs[level]

			log_info.filename = format_filename(log_info, level)
		end

		-- should write to new file when over 1 day
		if is_change_day(logs[level]) then
			local log_info = logs[level]
			log_info.date = os.time()
			log_info.file = nil
			log_info.filename = format_filename(log_info, level)
		end

		local f, msg = openRollingFileLogger(logs[level])
		if not f then
			return nil, msg
		end
		local s = logging.prepareLogMsg(logPattern, os.date("%Y/%m/%d %H:%M:%S"), level, message)
		f:write(s)
		return true
	end)
end

return logging.rolling_file

