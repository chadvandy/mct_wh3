
-- local mct = get_mct()

-- local mct_mod = mct:register_mod("mct-demo")

-- local new_page = mct_mod:create_settings_page("New Page", 1)
-- local old_page = mct_mod:get_default_setings_page()

-- mct_mod:set_default_settings_page(new_page)
-- old_page:remove()

-- local test = mct_mod:add_new_option("testing_campaign", 'checkbox')
-- test:set_default_value(true)
-- test:set_text("Campaign Test: Default is True")

-- local slider = mct_mod:add_new_option("test_slider", 'slider')
-- slider:set_text("Testing Slider Lock")
-- slider:set_locked(true, "Testing Lock")

-- for i = 1, 20 do
--     local mctmod = mct:register_mod("mct-demo-"..i)
--     mctmod:set_title("Mod " .. i)
-- end

-- -- create an array control group
-- ---@type MCT.ControlGroup.Array
-- local array_class = mct:get_object_type("control_groups", "array")

-- local checkbox_class = mct:get_mct_option_class_subtype("checkbox")
-- ---@cast checkbox_class MCT.Option.Checkbox

-- local array = array_class:new()
-- array:set_key("array_test")

-- local ck = checkbox_class:new(mct_mod, "test_1")
-- local ck2 = checkbox_class:new(mct_mod, "test_2")

-- array:add_control(ck, 1)
-- array:add_control(ck2, 2)

-- local page = mct_mod:get_default_setings_page()

-- ---@diagnostic disable-next-line: duplicate-set-field
-- function page:OnPopulate(uic)
--     local column = find_uicomponent(uic, "settings_column_1")
--     local box = find_uicomponent(column, "list_clip", "list_box")
--     array:display(box)
-- end

-- local test = mct_mod:add_new_radio_button(
--     "test",
--     "Testing Radio Button",
--     "Testing Tooltip",
--     {
--         {
--             key = "test_1",
--             text = "Test 1",
--         },
--         {
--             key = "test_2",
--             text = "Test 2",
--         },
--         {
--             key = "test_3",
--             text = "Test 3",
--         },
--     },
--     "test_2"
-- )

-- local dummy = mct_mod:add_new_option("dummy", "checkbox")
-- dummy:set_text("Dummy")

-- ---@type MCT.Option.Dropdown
-- local test = mct_mod:add_new_option("test_dropdown", "dropdown")
-- test:add_dropdown_values({
--     {
--         key = "one",
--         text = "mct_ui_mods_header",
--     },
--     {
--         key = "two",
--         text = "mct_ui_settings_title",
--     },
--     {
--         key = "three",
--         text = "mct_button_client_change",
--     },
--     {
--         key = "four",
--         text = "four",
--     },
--     {
--         key = "five",
--         text = "five",
--     },
--     {
--         key = "six",
--         text = "six",
--     },
--     {
--         key = "seven",
--         text = "seven",
--     },
--     {
--         key = "eight",
--         text = "eight",
--     },
--     {
--         key = "nine",
--         text = "nine",
--     },
--     {
--         key = "ten",
--         text = "ten",
--     },
--     {
--         key = "eleven",
--         text = "eleven",
--     },
-- })

-- -- -- local s = mct_mod:add_new_option("testing_slider", "slider"):slider_set_precision(2):set_default_value(50):slider_set_min_max(0, 100):set_text("Testing Slider")

-- -- -- mct_mod:add_new_option("test_b", 'checkbox'):set_text("Testing Checkbox")