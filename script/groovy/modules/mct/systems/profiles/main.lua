---@module UIProfiles

--- TODO the primary Profiles manager.
--- TODO Profiles can only be accessed in frontend; they can't be swapped in campaign, but they can be read(?) or at least you can see what profile you're currently using
--- TODO resolve how Profiles should be handled with 

local defaults = {}

---@class ProfileSystem
local ProfileSystem = GLib.NewClass("ProfileSystem", defaults)

--- TODO initialize any existing profiles, etc.
--- TODO lock profiles from usage if we're in a campaign, etc.
function ProfileSystem:init()

end

function ProfileSystem:save()

end

function ProfileSystem:load()

end


return ProfileSystem
