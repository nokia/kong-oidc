local cjson = require("cjson")
local userservice = require("kong.plugins.oidc.user-service")

local M = {}

local function parseFilters(csvFilters)
  local filters = {}
  if (not (csvFilters == nil)) then
    for pattern in string.gmatch(csvFilters, "[^,]+") do
      table.insert(filters, pattern)
    end
  end
  return filters
end

function M.get_redirect_uri_path(ngx)
  local function drop_query()
    local uri = ngx.var.request_uri
    local x = uri:find("?")
    if x then
      return uri:sub(1, x - 1)
    else
      return uri
    end
  end

  local function tackle_slash(path)
    local args = ngx.req.get_uri_args()
    if args and args.code then
      return path
    elseif path == "/" then
      return "/cb"
    elseif path:sub(-1) == "/" then
      return path:sub(1, -2)
    else
      return path .. "/"
    end
  end

  return tackle_slash(drop_query())
end

function M.get_options(config, ngx)
  return {
    client_id = config.client_id,
    client_secret = config.client_secret,
    discovery = config.discovery,
    introspection_endpoint = config.introspection_endpoint,
    timeout = config.timeout,
    introspection_endpoint_auth_method = config.introspection_endpoint_auth_method,
    bearer_only = config.bearer_only,
    realm = config.realm,
    redirect_uri_path = config.redirect_uri_path or M.get_redirect_uri_path(ngx),
    scope = config.scope,
    response_type = config.response_type,
    ssl_verify = config.ssl_verify,
    token_endpoint_auth_method = config.token_endpoint_auth_method,
    recovery_page_path = config.recovery_page_path,
    filters = parseFilters(config.filters),
    logout_path = config.logout_path,
    redirect_after_logout_uri = config.redirect_after_logout_uri,
    user_service_endpoint = config.user_service_endpoint,
    auth_header_blacklist = config.auth_header_blacklist,
    downstream_claims = config.downstream_claims,
    consumer_id_claim = config.consumer_id_claim,
  }
end

function M.exit(httpStatusCode, message, ngxCode)
  ngx.status = httpStatusCode
  ngx.say(message)
  ngx.exit(ngxCode)
end

function M.injectUser(user, oidcConfig)
  local tmp_user = user
  tmp_user.id = user.sub
  tmp_user.username = user.preferred_username
  ngx.ctx.authenticated_credential = tmp_user
  local userinfo = cjson.encode(user)
  clear_blacklist_headers(oidcConfig.auth_header_blacklist)

  -- Strip out x-user headers for security
  for header_key, header in pairs(ngx.req.get_headers()) do
    if string.find(header_key, 'x%-auth') then
      ngx.req.set_header(header_key, "")
    end
  end

  ngx.req.set_header("X-User-AccessToken", user.access_token)
  -- ngx.req.set_header("X-Userinfo", ngx.encode_base64(userinfo))

  -- Clear consumer ID header
  ngx.req.set_header("X-Consumer-Id", "")
  if oidcConfig.consumer_id_claim ~= nil then
    local consumer_id_claim = split(oidcConfig.consumer_id_claim, '.')
    if consumer_id_claim[2] ~= nil then
      ngx.req.set_header("X-Consumer-Id", user[consumer_id_claim[1]][consumer_id_claim[2]])
    else
      ngx.req.set_header("X-Consumer-Id", user.id_token[consumer_id_claim[1]])
    end
  else
    ngx.req.set_header("X-Consumer-Id", user.id_token.sub)
  end
  ngx.req.set_header("Authorization", "Bearer " .. user.access_token);

  -- Add claims from user section of token
  if(type(oidcConfig.downstream_claims) == "table") then
    for i, claim in pairs(oidcConfig.downstream_claims) do
      local claim = split(claim, '.')
      if claim[2] ~= nil then
        header_name_prefix = string.gsub(" "..claim[1], "%W%l", string.upper):sub(2)
        header_name_suffix = string.gsub(" "..claim[2], "%W%l", string.upper):sub(2)
        ngx.req.set_header("X-Auth-" .. header_name_prefix .. '-' .. header_name_suffix, user[claim[1]][claim[2]])
      end
    end
  end
  if oidcConfig.user_service_endpoint then
    userservice.get_headers(user.id_token.sub, oidcConfig)
  end
end

function split(inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        local t={} ; i=1
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                t[i] = str
                i = i + 1
        end
        return t
end

function clear_blacklist_headers(headers)
  if(type(headers) == "table") then
    for i, header in pairs(headers) do
      ngx.req.set_header(header, "")
    end
  end
end

function M.has_bearer_access_token()
  local header = ngx.req.get_headers()['Authorization']
  if header and header:find(" ") then
    local divider = header:find(' ')
    if string.lower(header:sub(0, divider-1)) == string.lower("Bearer") then
      return true
    end
  end
  return false
end

return M
