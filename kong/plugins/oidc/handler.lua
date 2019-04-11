local BasePlugin = require "kong.plugins.base_plugin"
local OidcHandler = BasePlugin:extend()
local utils = require("kong.plugins.oidc.utils")
local filter = require("kong.plugins.oidc.filter")
local session = require("kong.plugins.oidc.session")

OidcHandler.PRIORITY = 1000

local anonymousResponse = {
  azp = "anonymous",
    iat = 1554936123,
    iss = "https://login.anonymous.com/auth/realms/anonymous",
    email = "anonymous@anonymous.com",
    family_name = "anonymous",
    sub = "anonymous",
    id = "anonymous",
    auth_time = 1554935312,
    active = true,
    username = "anonymous",
    nbf = 0,
    email_verified = false,
    scope = "openid profile email",
    aud = "account",
    session_state = "10443ff5-a5a3-43d9-b383-2ed3bba4706f",
    acr = "0",
    client_id = "anonymous",
    given_name = "anonymous",
    exp = 4554936423,
    preferred_username = "anonymous",
    jti = "abccd87b-bcb0-4286-9e2e-7aeb7501c1cb",
    name = "Anonymous Anonymous",
    typ = "Bearer"
}

function OidcHandler:new()
  OidcHandler.super.new(self, "oidc")
end

function OidcHandler:access(config)
  OidcHandler.super.access(self)
  local oidcConfig = utils.get_options(config, ngx)

  if filter.shouldProcessRequest(oidcConfig) then
    session.configure(config)
    handle(oidcConfig)
  else
    ngx.log(ngx.DEBUG, "OidcHandler ignoring request, path: " .. ngx.var.request_uri)
  end

  ngx.log(ngx.DEBUG, "OidcHandler done")
end

function handle(oidcConfig)
  local response
  if oidcConfig.introspection_endpoint then
    response = introspect(oidcConfig)
    if response then
      utils.injectUser(response)
    end
  end

  if response == nil then
    response = make_oidc(oidcConfig)
    if response then
      if (response.user) then
        utils.injectUser(response.user)
      end
      if (response.access_token) then
        utils.injectAccessToken(response.access_token)
      end
      if (response.id_token) then
        utils.injectIDToken(response.id_token)
      end
    end
  end
end

function make_oidc(oidcConfig)
  ngx.log(ngx.DEBUG, "OidcHandler calling authenticate, requested path: " .. ngx.var.request_uri)
  local res, err = require("resty.openidc").authenticate(oidcConfig)
  if err then
    if oidcConfig.recovery_page_path then
      ngx.log(ngx.DEBUG, "Entering recovery page: " .. oidcConfig.recovery_page_path)
      ngx.redirect(oidcConfig.recovery_page_path)
    end
    utils.exit(500, err, ngx.HTTP_INTERNAL_SERVER_ERROR)
  end
  return res
end

function introspect(oidcConfig)
  if oidcConfig.pass_as_anonymous == "yes" or utils.has_bearer_access_token() or oidcConfig.bearer_only == "yes"  then
    local res, err = require("resty.openidc").introspect(oidcConfig)
    if err then

      if oidcConfig.pass_as_anonymous == "no" then
        if oidcConfig.bearer_only == "yes" then
          ngx.header["WWW-Authenticate"] = 'Bearer realm="' .. oidcConfig.realm .. '",error="' .. err .. '"'
          utils.exit(ngx.HTTP_UNAUTHORIZED, err, ngx.HTTP_UNAUTHORIZED)
        end
        return nil
      else
      --  lets send anonymous user info upstream
        ngx.log(ngx.DEBUG, "anonymous response returned because pass_as_anonymous == \"yes\"" )
        return anonymousResponse
      end
    end
    ngx.log(ngx.DEBUG, "OidcHandler introspect succeeded, requested path: " .. ngx.var.request_uri)
    return res
  end
  return nil
end


return OidcHandler
