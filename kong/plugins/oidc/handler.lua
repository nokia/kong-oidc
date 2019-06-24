local BasePlugin = require "kong.plugins.base_plugin"
local OidcHandler = BasePlugin:extend()
local utils = require("kong.plugins.oidc.utils")
local filter = require("kong.plugins.oidc.filter")
local session = require("kong.plugins.oidc.session")

local constants = require "kong.constants"

local kong = kong

OidcHandler.PRIORITY = 1002

local function internal_server_error(err)
  kong.log.err(err)
  return kong.response.exit(500, { message = "An unexpected error occurred" })
end

local function set_consumer(consumer, credential, token)
  local set_header = kong.service.request.set_header
  local clear_header = kong.service.request.clear_header

  if consumer and consumer.id then
    set_header(constants.HEADERS.CONSUMER_ID, consumer.id)
  else
    clear_header(constants.HEADERS.CONSUMER_ID)
  end

  if consumer and consumer.custom_id then
    set_header(constants.HEADERS.CONSUMER_CUSTOM_ID, consumer.custom_id)
  else
    clear_header(constants.HEADERS.CONSUMER_CUSTOM_ID)
  end

  if consumer and consumer.username then
    set_header(constants.HEADERS.CONSUMER_USERNAME, consumer.username)
  else
    clear_header(constants.HEADERS.CONSUMER_USERNAME)
  end

  kong.client.authenticate(consumer, credential)

  if credential then
    if token.scope then
      set_header("x-authenticated-scope", token.scope)
    else
      clear_header("x-authenticated-scope")
    end

    if token.authenticated_userid then
      set_header("x-authenticated-userid", token.authenticated_userid)
    else
      clear_header("x-authenticated-userid")
    end

    clear_header(constants.HEADERS.ANONYMOUS) -- in case of auth plugins concatenation

  else
    set_header(constants.HEADERS.ANONYMOUS, true)
    clear_header("x-authenticated-scope")
    clear_header("x-authenticated-userid")
  end

end

function OidcHandler:new()
  OidcHandler.super.new(self, "oidc")
end

function OidcHandler:access(config)
  OidcHandler.super.access(self)

  if config.anonymous and kong.client.get_credential() then
    -- we're already authenticated, and we're configured for using anonymous,
    -- hence we're in a logical OR between auth methods and we're already done.
    return
  end

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
        local tmp_user = response.user
        tmp_user.id = response.user.sub
        tmp_user.username = response.user.preferred_username
        set_consumer(tmp_user, nil, nil)
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
    if oidcConfig.anonymous then
      -- get anonymous user
      local consumer_cache_key = kong.db.consumers:cache_key(oidcConfig.anonymous)
      local consumer, err      = kong.cache:get(consumer_cache_key, nil,
                                                load_consumer_into_memory,
                                                oidcConfig.anonymous, true)
      if err then
        return internal_server_error(err)
      end

      set_consumer(consumer, nil, nil)

    else
      return kong.response.exit(err.status, err.message, err.headers)
    end
  end
  return res
end

function introspect(oidcConfig)
  if utils.has_bearer_access_token() or oidcConfig.bearer_only == "yes" then
    local res, err = require("resty.openidc").introspect(oidcConfig)
    if err then
      if oidcConfig.bearer_only == "yes" then
        ngx.header["WWW-Authenticate"] = 'Bearer realm="' .. oidcConfig.realm .. '",error="' .. err .. '"'
        if oidcConfig.anonymous then
          -- get anonymous user
          local consumer_cache_key = kong.db.consumers:cache_key(oidcConfig.anonymous)
          local consumer, err      = kong.cache:get(consumer_cache_key, nil,
                                                    load_consumer_into_memory,
                                                    oidcConfig.anonymous, true)
          if err then
            return internal_server_error(err)
          end
    
          set_consumer(consumer, nil, nil)
    
        else
          return kong.response.exit(err.status, err.message, err.headers)
        end
        
      end
      return nil
    end
    ngx.log(ngx.DEBUG, "OidcHandler introspect succeeded, requested path: " .. ngx.var.request_uri)
    return res
  end
  return nil
end

-- TESTING


return OidcHandler
