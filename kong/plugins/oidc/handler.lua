local BasePlugin = require "kong.plugins.base_plugin"
local OidcHandler = BasePlugin:extend()
local utils = require("kong.plugins.oidc.utils")
local filter = require("kong.plugins.oidc.filter")
local session = require("kong.plugins.oidc.session")

OidcHandler.PRIORITY = 1000


function OidcHandler:new()
  OidcHandler.super.new(self, "oidc")
end

function OidcHandler:access(config)
  OidcHandler.super.access(self)
  local oidcConfig = utils.get_options(config, ngx)

  if filter.shouldProcessRequest(oidcConfig) then
    ngx.log(ngx.DEBUG, "In plugin OidcHandler:access calling authenticate, requested path: " .. ngx.var.request_uri)

    session.configure(config)
    doAuthentication(oidcConfig)
  else
    ngx.log(ngx.DEBUG, "In plugin OidcHandler:access NOT calling authenticate, requested path: " .. ngx.var.request_uri)
  end

  ngx.log(ngx.DEBUG, "In plugin OidcHandler:access Done")
end

function doAuthentication(oidcConfig)
  res = tryIntrospect(oidcConfig)

  if res then
    ngx.log(ngx.DEBUG, "In plugin OidcHandler:Valid access token detected, passing connection, requested path: " .. ngx.var.request_uri)
    utils.injectUser({sub = res.sub})
    
  else
    local res, err = require("resty.openidc").authenticate(oidcConfig)
    if err then
      if oidcConfig.recovery_page_path then
        ngx.log(ngx.DEBUG, "Entering recovery page: " .. oidcConfig.recovery_page_path)
        ngx.redirect(oidcConfig.recovery_page_path)
      end
      utils.exit(500, err, ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    if res and res.user then
      utils.injectUser(res.user)
      ngx.req.set_header("X-Userinfo", require("cjson").encode(res.user))
    end
  end
end

function tryIntrospect(oidcConfig)
  if not oidcConfig.introspection_endpoint then
    return nil
  end
  
  local res, err = require("resty.openidc").introspect(oidcConfig)
  if err then
    return nil
  end

  return res
end


return CustomHandler
