local str = '{["mct-mp-demo"]={["checkbox_3"]=true,["checkbox_7"]=true,["dropdown_3"]="mp",["checkbox_6"]=true,["dropdown_4"]="mp",["checkbox_8"]=true,["dropdown_2"]="mp",["dropdown_5"]="mp",["checkbox_2"]=true,["checkbox_5"]=true,["checkbox_4"]=true,["dropdown_1"]="mp",["checkbox_1"]=true,["checkbox_9"]=true,["checkbox_10"]=true}}'

print(str)
local max = 100

local ret = {}

local equal_split = {}
if string.len(str) > max then
    local left = str
    local this

    while left ~= "" do
        this = left:sub(1, max)
        equal_split[#equal_split+1] = this
        left = left:sub(this:len() + 1)
    end
end

-- All we really need to do is make sure the string has balanced quotes, so let's go through and see if the number of single or double quotes found in the sub-max-length substring of our full string modulo 2 is greater than 0. If we have an odd number of single or double quotes, let's just drop the last one and toss it into the next string break.


-- We want to grab a chunk of the remaining string that's at the max length, and then
-- cut off either at a ] or a ,
if string.len(str) > max then
    local remaining_chunk = str
    local this_str
    while remaining_chunk ~= "" do
        print("Remaining bit: " .. remaining_chunk)
        -- this_str = remaining_chunk:match("%b{}")
        this_str = remaining_chunk:sub(1, max)

        print("Truncated chunk: ".. tostring(this_str))

        num_double = select(2, this_str:gsub("\"", "\""))

        -- Get rid of the very last double quote.
        if num_double % 2 == 1 then
            print("We have an odd number of double quotes, cutting out the final unmatched one!")
            pos = this_str:find("\"", -1)
            this_str = this_str:sub(1, pos-1)

            print("New truncated chunk: " .. this_str)
        end

        remaining_chunk = remaining_chunk:sub(this_str:len() + 1)
        ret[#ret+1] = this_str

        print("Length of substring: " .. this_str:len())
        print("Length of remaining chunk: " .. remaining_chunk:len())
        print("Total length: " .. str:len())

        print("Remaining chunk: " .. remaining_chunk)

        -- break

        -- str_end = this_str:match("^%[.+[%],]$")
        -- print("Substr: " .. tostring(str_end))
        -- -- if this_str:len() > max then
        -- --     print("Too long!")
        -- --     this_str = this_str:match("%b%[,")

        -- -- end

        -- if type(this_str) == "string" then
        --     remaining_chunk = remaining_chunk:gsub(this_str, "", 1)
        -- end
    end
else
    ret[#ret+1] = str
end

for i = 1, #ret do
    print(ret[i])
end


rejoined_string = table.concat(ret)
print(rejoined_string)

print("=== Equal String Split Test ===")

for i = 1, #equal_split do
    print(equal_split[i])
end

print(table.concat(equal_split))