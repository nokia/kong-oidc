local utils = require("kong.plugins.oidc.utils")
local lu = require("luaunit")

TestUtils = require("test.unit.base_case"):extend()


function TestUtils:testRedirectUriPath()
  local ngx = {
    var = {
      scheme = "http",
      host = "1.2.3.4",
      request_uri = ""
    },
    req = {
      get_uri_args = function() return nil end
    }
  }
  ngx.var.request_uri = "/path?some=stuff"
  lu.assertEquals(utils.get_redirect_uri(ngx), "/path/")

  ngx.var.request_uri = "/long/path/"
  lu.assertEquals(utils.get_redirect_uri(ngx), "/long/path")

  ngx.req.get_uri_args = function() return {code = 1}end
  lu.assertEquals(utils.get_redirect_uri(ngx), "/long/path/")
end

function TestUtils:testOptions()
  local opts = utils.get_options({
    client_id = 1,
    client_secret = 2,
    discovery = "d",
    scope = "openid",
    response_type = "code",
    ssl_verify = "no",
    token_endpoint_auth_method = "client_secret_post",
    introspection_endpoint_auth_method = "client_secret_basic",
    filters = "pattern1,pattern2,pattern3",
    logout_path = "/logout",
    redirect_after_logout_uri = "/login",
    userinfo_header_name = "X-UI",
    id_token_header_name = "X-ID",
    access_token_header_name = "Authorization",
    access_token_as_bearer = "yes",
    disable_userinfo_header = "yes",
    disable_id_token_header = "yes",
    disable_access_token_header = "yes"
  }, {var = {request_uri = "/path"},
    req = {get_uri_args = function() return nil end}})

  lu.assertEquals(opts.client_id, 1)
  lu.assertEquals(opts.client_secret, 2)
  lu.assertEquals(opts.discovery, "d")
  lu.assertEquals(opts.scope, "openid")
  lu.assertEquals(opts.response_type, "code")
  lu.assertEquals(opts.ssl_verify, "no")
  lu.assertEquals(opts.token_endpoint_auth_method, "client_secret_post")
  lu.assertEquals(opts.introspection_endpoint_auth_method, "client_secret_basic")
  lu.assertEquals(opts.redirect_uri, "/path/")
  lu.assertEquals(opts.logout_path, "/logout")
  lu.assertEquals(opts.redirect_after_logout_uri, "/login")
  lu.assertEquals(opts.userinfo_header_name, "X-UI")
  lu.assertEquals(opts.id_token_header_name, "X-ID")
  lu.assertEquals(opts.access_token_header_name, "Authorization")
  lu.assertEquals(opts.access_token_as_bearer, true)
  lu.assertEquals(opts.disable_userinfo_header, true)
  lu.assertEquals(opts.disable_id_token_header, true)
  lu.assertEquals(opts.disable_access_token_header, true)

  local expectedFilters = {
    "pattern1",
    "pattern2",
    "pattern3"
  }

  lu.assertItemsEquals(expectedFilters, opts.filters)

end


lu.run()
