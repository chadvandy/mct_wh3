--- TODO a visual layout within MCT, so you can do stuff like "3 equal columns" or "a double-wide column on the left and an image on the right" or whatever, inserting spots for options or text or wiki or whatever you want
--- TODO this should be an object which holds sections or different data in it, ie. a "description" layout might have description text, optional patch note / author / workshop link details, optional image, etc.

---@class MCT.Layout : Class
local defaults = {
    
}

---@class MCT.Layout : Class
---@field __new fun():MCT.Layout
local Layout = VLib.NewClass("Layout", defaults)

function Layout:new()
    local o = self:__new()
    o:init()

    return o
end

function Layout:init()

end



return Layout