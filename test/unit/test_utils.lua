local utils = require("kong.plugins.oidc.utils")
local lu = require("luaunit")


TestUtils = {}

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
    lu.assertEquals(utils.get_redirect_uri_path(ngx), "/path/")

    ngx.var.request_uri = "/long/path/"
    lu.assertEquals(utils.get_redirect_uri_path(ngx), "/long/path")

    ngx.req.get_uri_args = function() return {code = 1}end
    lu.assertEquals(utils.get_redirect_uri_path(ngx), "/long/path/")
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
      filters = "pattern1,pattern2,pattern3"

    }, {var = {request_uri = "/path"},
      req = {get_uri_args = function() return nil end}})

    lu.assertEquals(opts.client_id, 1)
    lu.assertEquals(opts.client_secret, 2)
    lu.assertEquals(opts.discovery, "d")
    lu.assertEquals(opts.scope, "openid")
    lu.assertEquals(opts.response_type, "code")
    lu.assertEquals(opts.ssl_verify, "no")
    lu.assertEquals(opts.token_endpoint_auth_method, "client_secret_post")
    lu.assertEquals(opts.redirect_uri_path, "/path/")

    local expectedFilters = {
      "pattern1",
      "pattern2",
      "pattern3"
    }

    lu.assertItemsEquals(expectedFilters, opts.filters)

  end


lu.run()
