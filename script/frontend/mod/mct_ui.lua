--- UI initalization
core:add_listener(
    "MctButton",
    "ComponentLClickUp",
    function(context)
        return context.string == "button_mct"
    end,
    function(context)
        core:get_tm():real_callback(function()
            get_mct():open_panel()
        end, 5, "mct_button")
    end,
    true
)

core:add_ui_created_callback(function()
    --- delete the existing holder and replace it with our own
    local frame = find_uicomponent("main", "options_frame")
    if is_uicomponent(frame) then out("We found the holder!") else out("We didn't found the holder!") return end
    local holder = find_uicomponent(frame, "holder")
    local my_holder = core:get_or_create_component("holder", "ui/mct/frontend_list")

    local x,y = holder:Position()

    out("My holder is valid: " .. tostring(is_uicomponent(my_holder)))

    local addr = {}
    for i = 0, holder:ChildCount() -1 do
        addr[#addr+1] = holder:Find(i)
    end

    for _,address in ipairs(addr) do 
        my_holder:Adopt(address)
    end

    out("Adopted everything - killing holder!")

    frame:Adopt(my_holder:Address())
    holder:Destroy()

    --- add our button
    -- path from root:	root > main > options_frame > holder > ui_holder > button_ui_big
    --- create the MCT button
    -- local parent = find_uicomponent("main", "options_frame", "holder")
    local copy = find_uicomponent(my_holder, "ui_holder")
    local t = find_uicomponent(my_holder, "mct_holder") if is_uicomponent(t) then return end

    local mct_holder = UIComponent(copy:CopyComponent("mct_holder"))
    mct_holder:DestroyChildren()

    --- TODO localize
    local mct_button = core:get_or_create_component("button_mct", "ui/templates/fe_square_button", mct_holder)
    local text = find_uicomponent(mct_button, "button_txt")

    for i = 0, text:NumStates() -1 do
        text:SetState(text:GetStateByIndex(i))
        text:SetStateText("Mod Configuration Tool")
    end

    text:SetState("active")

    my_holder:MoveTo(x, y)
    my_holder:Layout()
end)