return {
    --- One of the default sort-section function.
    -- Sort the sections by their section key - from "!my_section" to "zzz_my_section"
    ---@param self MCT.Mod
    ---@param page MCT.Page.SettingsSuperclass
    ---@return string[]
    key = function(self, page)
        local ret = {}
        local sections = page:get_assigned_sections()

        for i,section in ipairs(sections) do
            table.insert(ret, section:get_key())
        end

        table.sort(ret)

        return ret
    end,

    --- One of the default sort-section functions.
    -- Sort the sections by the order in which they were added in the `mct/settings/?.lua` file.
    ---@param self MCT.Mod
    ---@param page MCT.Page.SettingsSuperclass
    ---@return MCT.Section[]
    index = function(self, page)
        local ret = {}
        local sections = page:get_assigned_sections()

        -- table that has all mct_mod sections listed in the order they were created via mct_mod:add_new_section
        -- array of section_keys!
        local order_by_section_added = self._sections_by_index_order
    
        -- copy the table
        for i,global_section in ipairs(order_by_section_added) do
            for j,internal_section in ipairs(sections) do
                if global_section == internal_section:get_key() then
                    ret[#ret+1] = global_section
                end
            end
        end
    
        return ret
    end,

    ---- One of the default sort-option functions.
    --- Sort the section by their localised text - from "Awesome Options" to "Zoidberg Goes Woop Woop Woop"
    ---@param self MCT.Mod
    ---@param page MCT.Page.SettingsSuperclass
    ---@return MCT.Section[]
    localised_text = function(self, page)
        -- return table, which will be the sorted sections from top to bottom
        local ret = {}

        -- texts is the sorted list of section texts
        local texts = {}

        -- table linking localised text to a table of section keys. If multiple section have the same localised text, it will be `["Localised Text"] = {"section_key_a", "section_key_b"}`
        -- else, it's just `["Localised Text"] = {"section_key"}`
        local text_to_section_key = {}

        -- all sections
        local sections = page:get_assigned_sections()

        for i, section_obj in ipairs(sections) do
            -- grab this section's localised text
            local section_key = section_obj:get_key()
            local localised_text = section_obj:get_localised_text()
            
            -- toss it into the texts table, and link it to the section key
            texts[#texts+1] = localised_text

            -- check if this localised text was already linked to something
            local test = text_to_section_key[localised_text]

            if is_nil(text_to_section_key[localised_text]) then
                -- if not, set it equal to the key
                text_to_section_key[localised_text] = {section_key}
            else
                if is_table(test) then
                    -- this is ugly, I'm sorry.
                    text_to_section_key[localised_text][#text_to_section_key[localised_text]+1] = section_key
                end
            end
        end

        -- sort the texts alphanumerically.
        table.sort(texts)

        -- loop through texts, grab the relevant section key, and then add that section key to ret
        -- if multiple section keys are linked to this text, add them in order added, whatever
        for i = 1, #texts do
            -- grab the localised text at this index
            local text = texts[i]

            -- grab attached sections
            local attached_sections = text_to_section_key[text]

            -- loop through attached section keys (will only be 1 usually) and then add them to the ret table
            for j = 1, #attached_sections do
                local section_key = attached_sections[j]
                ret[#ret+1] = section_key
            end
        end

        return ret
    end
}