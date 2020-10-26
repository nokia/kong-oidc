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

local function headerPresent(header)
  return ngx.req.get_headers()[header] and ngx.req.get_headers()[header] ~= ''
end

local function cookiePresent(header)
  local cookie = ngx.req.get_headers()['Cookie']
  return cookie and cookie ~= '' and string.find(header + "=") >= 1
end

function M.shouldProcessRequest(config)
  return not headerPresent(config.bypass_header) or not cookiePresent(config.bypass_cookie) or not shouldIgnoreRequest(config.filters)
end

function M.isAuthBootstrapRequest(config)
  if (config.auth_bootstrap_path and config.auth_bootstrap_path ~= '') then
    return string.find(ngx.var.uri, config.auth_bootstrap_path,1,true) == 1
  else
    return false
  end
end

return M
