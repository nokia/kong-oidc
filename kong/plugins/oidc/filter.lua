local M = {}

local function startsWith(text, prefix)
  return string.sub(text, 1, string.len(prefix)) == prefix
end

local function shouldIgnoreRequest()
  local ignore_paths = "/auth,/arc"  -- TODO. Need to have a common solution.
  for path in string.gmatch(ignore_paths, "[^,]+") do
    if  ngx.var.uri == path or startsWith(ngx.var.uri, path.."/") then
      return true
    end
  end
  return false
end


function M.shouldProcessRequest()
  return not shouldIgnoreRequest()
end

return M
