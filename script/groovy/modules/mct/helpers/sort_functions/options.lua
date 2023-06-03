---@ignoreFile
return {
    ---@param obj mct_section
    key = function(obj)     
        local ret = {}
        local options = obj:get_options()
    
        for option_key, _ in pairs(options) do
            table.insert(ret, option_key)
        end
    
        table.sort(ret)
    
        return ret 
    end,
    ---@param obj mct_section
    index = function(obj)
        local ret = {}

        local valid_options = obj:get_options()
    
        -- table that has all mct_mod options listed in the order they were created via mct_mod:add_new_option
        -- array of option_keys!
        local order_by_option_added = obj:get_mod()._options_by_index_order
    
        -- loop through this table, check to see if the option iterated is in this section, and if it is, add it to the ret table, next in line
        for i = 1, #order_by_option_added do
            local test = order_by_option_added[i]
    
            if valid_options[test] ~= nil then
                -- set this option key as the next in the ret table
                ret[#ret+1] = test
            end
        end
    
        return ret
    end,
    ---@param obj mct_section
    localised_text = function(obj)
        -- return table, which will be the sorted option keys from top-left to bottom-right
        local ret = {}

        -- texts is the sorted list of option texts
        local texts = {}

        -- table linking localised text to a table of option keys. If multiple options have the same localised text, it will be `["Localised Text"] = {"option_key_a", "option_key_b"}`
        -- else, it's just `["Localised Text"] = {"option_key"}`
        local text_to_option_key = {}

        -- all options
        local options = obj:get_options()

        for option_key, option_obj in pairs(options) do
            -- grab this option's localised text
            local localised_text = option_obj:get_localised_text()
            
            -- toss it into the texts table, and link it to the option key
            texts[#texts+1] = localised_text

            -- check if this localised text was already linked to something
            local test = text_to_option_key[localised_text]

            if is_nil(text_to_option_key[localised_text]) then
                -- if not, set it equal to the key
                text_to_option_key[localised_text] = {option_key}
            else
                if is_table(test) then
                    -- this is ugly, I'm sorry.
                    text_to_option_key[localised_text][#text_to_option_key[localised_text]+1] = option_key
                end
            end
        end

        -- sort the texts alphanumerically.
        table.sort(texts)

        -- loop through texts, grab the relevant option key, and then add that option key to ret
        -- if multiple option keys are linked to this text, add them in order added, whatever
        for i = 1, #texts do
            -- grab the localised text at this index
            local text = texts[i]

            -- grab attached options
            local attached_options = text_to_option_key[text]

            -- loop through attached option keys (will only be 1 usually) and then add them to the ret table
            for j = 1, #attached_options do
                local option_key = attached_options[j]
                ret[#ret+1] = option_key
            end
        end

        return ret
    end
}
