local BasePlugin = require "kong.plugins.base_plugin"
local OidcHandler = BasePlugin:extend()
local utils = require("kong.plugins.oidc.utils")
local filter = require("kong.plugins.oidc.filter")
local session = require("kong.plugins.oidc.session")

local openidc = require("resty.openidc")
local cjson = require("cjson")

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
    handle(oidcConfig)
  else
    ngx.log(ngx.DEBUG, "In plugin OidcHandler:access NOT calling authenticate, requested path: " .. ngx.var.request_uri)
  end

  ngx.log(ngx.DEBUG, "In plugin OidcHandler:access Done")
end

function handle(oidcConfig)
  local response = nil
  if oidcConfig.introspection_endpoint then
    response = introspect(oidcConfig)
    if response then
      utils.injectUser(response)
    end
  end

  if response == nil then
    response = make_oidc(oidcConfig)
    if response and response.user then
      utils.injectUser(response.user)
      ngx.req.set_header("X-Userinfo", cjson.encode(response.user))
    end
  end
end

function make_oidc(oidcConfig)
  local res, err = openidc.authenticate(oidcConfig)
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
  local res, err = openidc.introspect(oidcConfig)
  if err then
    return nil
  end
  return res
end


return OidcHandler
