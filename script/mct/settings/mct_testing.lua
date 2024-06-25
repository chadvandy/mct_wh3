local mct = get_mct()

local mct_mod = mct:register_mod("mct-mp-demo")

mct_mod:set_title("MCT MP Testing")
mct_mod:set_author("Groovy")

mct_mod:set_description("Hi thanks for testing!\n\nPlease confirm that this demo branch works by loading up an MP campaign lobby with 2+ players. The host should go through and check all of the checkboxes, and they should set all of the dropdown values to 'The Host Rules'.\nNon-host players, please go through and make sure all of the checkboxes are set to unchecked, and set every dropdown to 'Nasty Rat'.\n\nOnce that is done and the values are confirmed, create a new game and confirm that the checkboxes are all checked and that the dropdowns all say 'The Host Rules'.\nFinal step, save and exit out of that campaign, have everyone change the settings to their default values in the main menu using the default values button, and then reload into the campaign and confirm that all of the values are still what we expect them to be as before.\nThen just let me know that it works, and if not, at what step it didn't work.\nThanks!")

for i = 1, 10 do
    local cb = mct_mod:add_new_option("checkbox_" .. i, 'checkbox')
    cb:set_default_value(false)
    cb:set_text("Host - Set to True")
end

for i = 1, 5 do
    local dd = mct_mod:add_new_option("dropdown_"..i, 'dropdown')
    ---@cast dd MCT.Option.Dropdown
    dd:add_dropdown_value("default", "Default Value", "", true)
    dd:add_dropdown_value("client", "Nasty Rat", "", false)
    dd:add_dropdown_value("mp", "The Host Rules", "", false)
    dd:set_text("Host - Set to 'The Host Rules'")
end

-- mct_mod:add_new_action("test_action", "Test Action", function() out("Test Action!") end)


-- local CGClass = mct:get_control_group_class()
-- local ChbxClass = mct:get_mct_control_class_type("checkbox")
-- ---@cast ChbxClass MCT.Control.Checkbox

-- local test_cg = CGClass:new()
-- test_cg:set_key("test_cg")
-- test_cg:set_mod(mct_mod)

-- ---@type MCT.Control.Checkbox
-- local test_chbx = ChbxClass:new(mct_mod, "test_chbx")

-- local new_tab = mct_mod:add_main_page_tab(
--     "Demo Tab",
--     "Testing Tab",
--     function (uic)
--         test_cg:display(uic)
--     end
-- )

-- local test_checkbox = mct_mod:add_new_option("test_checkbox", "checkbox")
-- test_checkbox:set_text("Testing Box for New Game")

-- local slider = mct_mod:add_new_option("test_slider", "slider")
-- slider:set_text("Testing Slider")
-- slider:set_default_value(50)

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