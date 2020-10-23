local M = {}

local function shouldIgnoreRequest(patterns)
  if (patterns) then
    for _, pattern in ipairs(patterns) do
      local isMatching = not (string.find(ngx.var.uri, pattern) == nil)
      if (isMatching) then return true end
    end
  end
  return false
end

function M.shouldProcessRequest(config)
  return not shouldIgnoreRequest(config.filters)
end

function M.isAuthBootstrapRequest(config)
  if (config.auth_bootstrap_path) then
    return string.find(ngx.var.uri, config.auth_bootstrap_path) == 1
  else
    return false
  end
end

return M
