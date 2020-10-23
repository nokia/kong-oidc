local BasePlugin = require "kong.plugins.base_plugin"
local OidcHandler = BasePlugin:extend()
local utils = require("kong.plugins.oidc.utils")
local filter = require("kong.plugins.oidc.filter")
local session = require("kong.plugins.oidc.session")
local cjson_s = require("cjson.safe")

OidcHandler.PRIORITY = 1000

function OidcHandler:new()
  OidcHandler.super.new(self, "oidc")
end

function OidcHandler:access(config)
  OidcHandler.super.access(self)
  local oidcConfig = utils.get_options(config, ngx)

  if filter.shouldProcessRequest(oidcConfig) then
    session.configure(config)
    if filter.isAuthBootstrapRequest(oidcConfig) then
      auth_bootstrap(oidcConfig)
    else
      handle(oidcConfig)
    end
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
      if (response.user and oidcConfig.inject_user == "yes") then
        utils.injectUser(response.user)
      end
      if (response.access_token and oidcConfig.inject_access_token == "yes") then
        utils.injectAccessToken(response.access_token)
      end
      if (response.id_token and oidcConfig.inject_id_token == "yes") then
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

function auth_bootstrap(oidcConfig)
  ngx.log(ngx.DEBUG, "Authbootstrap flow, requested path: " .. ngx.var.request_uri)
  local tokens_str = ngx.req.get_headers()['tokens']
  local json_tokens = cjson_s.decode(tokens_str)
  if(json_tokens) then
    local res, err = require("resty.openidc").save_as_authenticated(oidcConfig,nil,json_tokens)
  else
    local err = "JSON decode failed"
    ngx.log(ngx.ERR, err)
  end

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
  if utils.has_bearer_access_token() or oidcConfig.bearer_only == "yes" then
    local res, err = require("resty.openidc").introspect(oidcConfig)
    if err then
      if oidcConfig.bearer_only == "yes" then
        ngx.header["WWW-Authenticate"] = 'Bearer realm="' .. oidcConfig.realm .. '",error="' .. err .. '"'
        utils.exit(ngx.HTTP_UNAUTHORIZED, err, ngx.HTTP_UNAUTHORIZED)
      end
      return nil
    end
    ngx.log(ngx.DEBUG, "OidcHandler introspect succeeded, requested path: " .. ngx.var.request_uri)
    return res
  end
  return nil
end


return OidcHandler
