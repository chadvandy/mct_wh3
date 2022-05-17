--- Extend Lua functionality.

--- Create a new table by completely copying an existing one.
---@param tbl table
---@return table
function table.deepcopy(tbl)
	local ret = {}
	for k, v in pairs(tbl) do
		ret[k] = type(v) == 'table' and table.deepcopy(v) or v
	end
	return ret
end

--- Take an existing table, and copy the contents of another into it.
---@param t table The table getting expanded.
---@param o table The table getting copied over.
---@return table t The original table, post-expansion.
function table.copy_add(t, o)
	if not is_table(t) or not is_table(o) then return end

	for k,v in pairs(o) do
		if not t[k] then
			if is_table(v) then
				local new_t = {}
				v = table.copy_add(new_t, v)
			end

			t[k] = v
		end
	end

	return t
end

--- Used to test many items if they're a string: `are_string("test", "Test2", 5, "final test")`
---@vararg any The items passed to test.
---@return boolean are_strings If or if not all objects passed are a string.
function are_strings(...)
	for i = 1, arg.n do
		if not is_string(arg[i]) then
			return false
		end
	end

	return true
end

local types_to_test = {
	["string"] = is_string,
	["number"] = is_number,
	["table"] = is_table,
	["function"] = is_function,
	["nil"] = is_nil
}

--- See if every arg passed is of the type supplied - AND operation, passes until failure.
---@param type any
---@vararg any Objects to test against the type.
---@return boolean
function all_of_type(type, ...)
	if not is_string(type) or not types_to_test[type] then
		-- errmsg
		return false
	end

	local t = types_to_test[type]

	for i = 1, arg.n do
		if not t(arg[i]) then
			return false
		end
	end

	return true
end

--- See if any arg passed is of the type supplied - OR operation.
---@param type any
---@vararg any Objects to test against the type.
---@return boolean
function any_of_type(type, ...)
	if not is_string(type) or not types_to_test[type] then
		-- errmsg
		return false
	end

	local t = types_to_test[type]

	for i = 1, arg.n do
		if t(arg[i]) then
			return true
		end
	end

	return false
end

function table.copy(tbl)
	local ret = {}
	if not type(tbl) == "table" then return ret end
	for k, v in pairs(tbl) do
		ret[k] = v
	end
	return ret
end


-- TODO combine two tables into MegaTable
function table.join(t1, t2)
	local ret = {}
	-- for i,v in ipairs(t1) 
end

--- TODO a function to strip a table of any non-saveable types (number, string, boolean)
function table.strip(t)
	local o = {}
	for k,v in pairs(t) do
		if is_table(v) then
			o[k] = table.strip(v)
		elseif is_number(v) or is_string(v) or is_boolean(v) then 
			o[k] = v
		else
			-- don't add it
		end
	end

	return o
end

---@return string[]
function string.split(str, delim)
	local ret = {}
	if not str then
		return ret
	end
	if not delim or delim == '' then
		for c in string.gmatch(str, '.') do
			table.insert(ret, c)
		end
		return ret
	end
	local n = 1
	while true do
		local i, j = string.find(str, delim, n)
		if not i then break end
		table.insert(ret, string.sub(str, n, i - 1))
		n = j + 1
	end
	table.insert(ret, string.sub(str, n))
	return ret
end

--- Thanks google/Paul Kulchenko! https://stackoverflow.com/questions/35006931/lua-line-breaks-in-strings
--- Takes a string, and cuts it up into various new lines, with a max of X characters per line.
---@param s string The string being cut up.
---@param x number How many characters are valid within each line. Defaults to 100.
---@param indent string? Any indent you want at the front of each line - use \t to tab in.
---@return string String The sanitized string, at the end of the day.
function string.format_with_linebreaks(s, x, indent)
    x = x or 100
    indent = indent or ""
    local t = {""}
    local function cleanse(str) return str:gsub("@x%d%d%d",""):gsub("@r","") end
    for prefix, word, suffix, newline in s:gmatch("([ \t]*)(%S*)([ \t]*)(\n?)") do
        if #(cleanse(t[#t])) + #prefix + #cleanse(word) > x and #t > 0 then
            table.insert(t, word..suffix) -- add new element
        else -- add to the last element
            t[#t] = t[#t]..prefix..word..suffix
        end
        if #newline > 0 then table.insert(t, "") end
    end

    return indent..table.concat(t, "\n"..indent)
end

function string.startswith(str, pattern, plain)
	local start = 1
	return string.find(str, pattern, start, plain) == start
end

function string.endswith(str, pattern, plain)
	local start = #str - #pattern + 1
	return string.find(str, pattern, start, plain) == start
end

--- TODO rewrite as table.print()
table_printer = {
    __tab = 0,
    __linebreak = "\n",
    __tabbreak = "\t",

    __str = "",
    __last = "",
}

--- TODO exempted indices (ie. don't print anything that does or doesn't match a pattern, etc)

function table_printer:newline(tab_i, override)
    self.__tab = self.__tab + tab_i

    if override then self.__tab = tab_i end

    local tab = ""
    for _ = 1, self.__tab do
        tab = tab .. self.__tabbreak
    end

    self:concat(self.__linebreak .. tab)
end

function table_printer:handle_key(key)
    if is_number(key) then
        self:concatf("[%d]", key)
    elseif is_string(key) then
        self:concatf("[%q]", key)
    else
        return false
    end

    return true
end

function table_printer:handle_value(value)
    if is_table(value) then
        self:concatf(" = ")
        self:handle_table(value)
    elseif is_number(value) then
        self:concatf(" = %d,", value)
    elseif is_string(value) then
        self:concatf(" = %q,", value)
    elseif is_boolean(value) then
        self:concatf(" = %s,", value and "true" or "false")
    else
        return false
    end

    return true
end

function table_printer:concatf(str, ...)
    str = string.format(str, ...)
    self:concat(str)
end

function table_printer:remove_last()
    local len = self.__last:len()

    self.__str = self.__str:sub(1, -len-1)
    self.__last = ""
end

function table_printer:concat(str)
    if not is_string(str) then print("Not a string! " .. tostring(str)) end
    self.__str = self.__str .. str

    self.__last = str
end

function table_printer:handle_table(t, is_first)
    if not is_table(t) then return end

    self:concat("{")
    self:newline(1)
    for k,v in pairs(t) do
        --- TODO if invalid value then don't save the key!!!
        if self:handle_key(k) then
            if self:handle_value(v) then
                self:newline(0)
            else
                print("Invalid value!")
                self:remove_last()
            end
        else
            print("Invalid key!")
        end
    end

    -- remove the last new line
    self:remove_last()
    
    if is_first then
        self:newline(0, true)
        self:concat("}")
    else
        self:newline(-1)
        self:concat("},")
    end
end

--- takes a table and returns the formatted text of its entirety
function table_printer:print(t)
    if not is_table(t) then return false end

    self.__str = ""
    self.__last = ""
    self.__tab = 0

    self:handle_table(t, true)

    return self.__str
end