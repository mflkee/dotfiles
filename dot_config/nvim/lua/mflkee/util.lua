--- Shared helpers for plugin specs.

--- Turn a "owner/repo" string into a GitHub URL.
---@param repo string
---@return string
local function gh(repo) return 'https://github.com/' .. repo end

return { gh = gh }
