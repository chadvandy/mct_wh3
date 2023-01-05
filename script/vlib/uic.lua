---@alias UIComponent UIC
--- Helpers and extended functionality for using UIComponents, to prevent bugs and crashes and shit, or to make some stuff easier to do.

local log,logf,errlog,errlogf = get_vlog("[helpers]")

--- TODO allow any component command below take a table of UIC's?

--- bloopy
---@param root UIComponent
---@return UIComponent
local function create_dummy(root)
	local name = "VandyDummy"
	local path = "ui/campaign ui/script_dummy"

	local dummy = core:get_or_create_component(name, path, root)

	return dummy
end

--- Delete one or many components!
---@param component UIComponent|UIComponent[]
function delete_component(component)
	local dummy = create_dummy(core:get_ui_root())

	if is_table(component) then
		for i = 1, #component do
			if is_uicomponent(component[i]) then
                dummy:Adopt(component[i]:Address())
			end
		end

        dummy:DestroyChildren()
	elseif is_uicomponent(component) then
		component:Destroy()
	end
end

--- Used to set a text component to its proper size, because of some finicky stuff with text components that I don't fully understand.
---@param text_component UIComponent The text component being resized.
---@param text string The state text you want to be displayed on this text.
---@param w number Width of the text.
---@param h number Height.
function resize_text(text_component, text, w, h)
    _SetCanResize(text_component, true)
    if not w then
        w,h = text_component:Dimensions()
    else
        text_component:Resize(w, h)
    end

    _SetStateText(text_component, text)

    text_component:ResizeTextResizingComponentToInitialSize(w, h)
    local nw,nh,lines = text_component:TextDimensionsForText(text)

    text_component:ResizeTextResizingComponentToInitialSize(nw, nh)
    text_component:Resize(nw, nh)

    _SetCanResize(text_component, false)
end


function _SetCanResize(uic,b)
    if not is_uicomponent(uic) then return end
    if not is_boolean(b) then b = true end

    _SetCanResizeHeight(uic, b)
    _SetCanResizeWidth(uic, b)
end
--- Sets the state of the uicomponent to the specified state name.
---@param uic UIComponent
---@param state string
function _SetState(uic, state)
    if not is_uicomponent(uic) then return end
    if not is_string(state) then return end

    uic:SetState(state)
end

---@param uic UIComponent
---@param x number
---@param y number
function _MoveTo(uic, x, y)
    if not is_uicomponent(uic) then return end
    if not is_number(x) then return end
    if not is_number(y) then return end

    uic:MoveTo(x, y)
end

---@param uic UIComponent
---@param b boolean
function _SetMoveable(uic, b)
    if not is_uicomponent(uic) then return end
    if not is_boolean(b) then return end

    uic:SetMoveable(b)
end

--- TODO dis causes crash?
---@param uic UIComponent
---@param w number
---@param h number
---@param b boolean
function _Resize(uic, w, h, b)
    if not is_uicomponent(uic) then return end
    if not is_number(w) then return end
    if not is_number(h) then return end
    if not is_nil(b) and not is_boolean(b) then return end

    uic:Resize(w, h, b)
end

---@param uic UIComponent
---@param b boolean
function _SetCanResizeHeight(uic, b)
    if not is_uicomponent(uic) then return end
    if not is_nil(b) and not is_boolean(b) then return end

    uic:SetCanResizeHeight(b)
end

---@param uic UIComponent
---@param b boolean
function _SetCanResizeWidth(uic, b)
    if not is_uicomponent(uic) then return end
    if not is_nil(b) and not is_boolean(b) then return end

    uic:SetCanResizeWidth(b)
end

---@param uic UIComponent
---@param w number
---@param h number
function _ResizeTextResizingComponentToInitialSize(uic, w, h)
    if not is_uicomponent(uic) then return end
    if not is_number(w) then return end
    if not is_number(h) then return end

    uic:ResizeTextResizingComponentToInitialSize(w, h)
end

---@param uic UIComponent
---@param dock_point number
function _SetDockingPoint(uic, dock_point)
    if not is_uicomponent(uic) then return end
    if not is_number(dock_point) then return end

    uic:SetDockingPoint(dock_point)
end


---@param uic UIComponent
---@param x number
---@param y number
function _SetDockOffset(uic, x, y)
    if not is_uicomponent(uic) then return end
    if not is_number(x) then return end
    if not is_number(y) then return end

    uic:SetDockOffset(x, y)
end

---@param uic UIComponent
---@param text string
function _SetStateText(uic, text)
    if not is_uicomponent(uic) then return end
    if not is_string(text) then return end

    uic:SetStateText(text)
end

---@param uic UIComponent
---@param text string
---@param b boolean
function _SetTooltipText(uic, text, b)
    if not is_uicomponent(uic) then return end
    if not is_string(text) then return end
    if not is_boolean(b) then return end
    
    uic:SetTooltipText(text, b)
end

---@param uic UIComponent
---@param img_path string
---@param index number
function _SetImagePath(uic, img_path, index)
    if not is_uicomponent(uic) then return end
    if not is_string(img_path) then return end
    if not is_nil(index) and not is_number(index) then return end

    return uic:SetImagePath(img_path, index)
end

function _PropagatePriority(uic, priority)
    if not is_uicomponent(uic) then return end
    if not is_number(priority) then return end

    return uic:PropagatePriority(priority)
end

---@param uic UIComponent
---@param b boolean
function _SetVisible(uic, b)
    if not is_uicomponent(uic) then return end
    if not is_boolean(b) then return end

    uic:SetVisible(b)
end

---@param uic UIComponent
---@param b boolean
function _SetInteractive(uic, b)
    if not is_uicomponent(uic) then return end
    if not is_boolean(b) then return end

    uic:SetInteractive(b)
end

---@param uic UIComponent
---@param b boolean
function _SetDisabled(uic, b)
    if not is_uicomponent(uic) then return end
    if not is_boolean(b) then return end

    uic:SetDisabled(b)
end

---@param uic UIComponent
---@param k string
---@param v any
function _SetProperty(uic, k, v)
    if not is_uicomponent(uic) then return end
    if not is_string(k) then return end
    if is_nil(v) then return end

    uic:SetProperty(k, v)
end

--- EDIT SO I CAN FRICKIN UPDATE THE MOD TO 1.3