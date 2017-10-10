package.path = package.path .. ";test/lib/?.lua;;" -- kong & co

local lu = require("luaunit")


TestIntrospect = {}

  function TestIntrospect:setUp()
    self.logs = {}
    self.mocked_ngx = {
      DEBUG = "debug",
      ERR = "error",
      ctx = {},
      header = {},
      var = {request_uri = "/"},
      req = {
        get_uri_args = function(...) end,
        set_header = function(...) end,
        get_headers = function(...) return self.ngx_headers end
      },
      log = function(...)
        self.logs[#self.logs+1] = table.concat(arg, " ")
        print("ngx.log: ", unpack(arg))
      end,
      shared = {},
      encode_arge = function(...) return arg end,
      say = function(...) end,
      exit = function(...) end,
      redirect = function(...) end
    }
    self.ngx = _G.ngx
    _G.ngx = self.mocked_ngx

    self.cjson = package.loaded.cjson
    package.loaded.cjson = nil
    package.preload["cjson"] = function()
      return {
        encode = function(...) return "encoded" end,
        decode = function(...) return {sub = "sub"} end
      }
    end

    self.resty = package.loaded.resty
    package.loaded["resty.http"] = nil
    package.preload["resty.http"] = function()
      return {encode = function(...) return "encoded" end}
    end

    self.handler = require("kong.plugins.oidc.handler")()
  end

  function TestIntrospect:tearDown()
    _G.ngx = self.ngx
    package.loaded.cjson = self.cjson
    package.loaded.resty = self.resty
  end

  function TestIntrospect:log_contains(str)
    return table.concat(self.logs, "//"):find(str) and true or false
  end

  function TestIntrospect:test_access_token_exists()
    self.ngx_headers = {Authorization = "Bearer xxx"}
    local dict = {}
    function dict:get(key) return key end
    _G.ngx.shared = {introspection = dict }

    self.handler:access({introspection_endpoint = "x"})
    lu.assertTrue(self:log_contains("introspect succeeded"))
  end

  function TestIntrospect:test_no_authorization_header()
    package.loaded["resty.openidc"].authenticate = function(...) return {}, nil end
    self.ngx_headers = {}

    self.handler:access({introspection_endpoint = "x"})
    lu.assertFalse(self:log_contains(self.mocked_ngx.ERR))
  end


lu.run()
