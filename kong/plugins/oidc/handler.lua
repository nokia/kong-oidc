-- Extending the Base Plugin handler is optional, as there is no real
-- concept of interface in Lua, but the Base Plugin handler's methods
-- can be called from your child implementation and will print logs
-- in your `error.log` file (where all logs are printed).
local BasePlugin = require "kong.plugins.base_plugin"
local CustomHandler = BasePlugin:extend()
local utils = require("kong.plugins.oidc.utils")
local filter = require("kong.plugins.oidc.filter")
local session = require("kong.plugins.oidc.session")

CustomHandler.PRIORITY = 1000

-- Your plugin handler's constructor. If you are extending the
-- Base Plugin handler, it's only role is to instanciate itself
-- with a name. The name is your plugin name as it will be printed in the logs.
function CustomHandler:new()
  CustomHandler.super.new(self, "oidc")
end

function CustomHandler:access(config)
  -- Eventually, execute the parent implementation
  -- (will log that your plugin is entering this context)
  CustomHandler.super.access(self)

  local oidcConfig = utils.get_options(config, ngx)

  if filter.shouldProcessRequest(oidcConfig) then
    ngx.log(ngx.DEBUG, "In plugin CustomHandler:access calling authenticate, requested path: " .. ngx.var.request_uri)

    session.configure(config)

    local res, err = require("resty.openidc").authenticate(oidcConfig)

    if err then
      if config.recovery_page_path then
        ngx.log(ngx.DEBUG, "Entering recovery page: " .. config.recovery_page_path)
        return ngx.redirect(config.recovery_page_path)
      end
      utils.exit(500, err, ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    if res and res.user then
      utils.injectUser(res.user)
      ngx.req.set_header("X-Userinfo", require("cjson").encode(res.user))
    end
  else
    ngx.log(ngx.DEBUG, "In plugin CustomHandler:access NOT calling authenticate, requested path: " .. ngx.var.request_uri)
  end

  ngx.log(ngx.DEBUG, "In plugin CustomHandler:access Done")
end

-- This module needs to return the created table, so that Kong
-- can execute those functions.
return CustomHandler
