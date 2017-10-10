package.path = package.path .. ";test/lib/?.lua;;" -- kong & co

local lu = require("luaunit")


TestHandler = {}

  function TestHandler:setUp()
    self.logs = {}
    self.ngx_headers = {}
    self.mocked_ngx = {
      DEBUG = "debug",
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
      say = function(...) end,
      exit = function(...) end,
      redirect = function(...) end
    }
    self.ngx = _G.ngx
    _G.ngx = self.mocked_ngx

    self.resty = package.loaded.resty
    package.loaded["resty.openidc"] = nil
    self.module_resty = {openidc = {
      authenticate = function(...) return {}, nil end }
      }
    package.preload["resty.openidc"] = function()
      return self.module_resty.openidc
    end

    self.cjson = package.loaded.cjson
    package.loaded.cjson = nil
    package.preload["cjson"] = function()
      return {encode = function(...) return "encoded" end}
    end

    self.handler = require("kong.plugins.oidc.handler")()
  end

  function TestHandler:tearDown()
    _G.ngx = self.ngx
    package.loaded.resty = self.resty
    package.loaded.cjson = self.cjson
  end

  function TestHandler:log_contains(str)
    return table.concat(self.logs, "//"):find(str) and true or false
  end

  function TestHandler:test_authenticate_ok_no_userinfo()
    self.module_resty.openidc.authenticate = function(opts)
      return {}, false
    end

    self.handler:access({})
    lu.assertTrue(self:log_contains("calling authenticate"))
  end

  function TestHandler:test_authenticate_ok_with_userinfo()
    self.module_resty.openidc.authenticate = function(opts)
      return {user = {sub = "sub"}}, false
    end

    self.handler:access({})
    lu.assertTrue(self:log_contains("calling authenticate"))
  end

  function TestHandler:test_authenticate_nok_no_recovery()
    self.module_resty.openidc.authenticate = function(opts)
      return {}, true
    end

    self.handler:access({})
    lu.assertTrue(self:log_contains("calling authenticate"))
  end

  function TestHandler:test_authenticate_nok_with_recovery()
    self.module_resty.openidc.authenticate = function(opts)
      return {}, true
    end

    self.handler:access({recovery_page_path = "x"})
    lu.assertTrue(self:log_contains("recovery page"))
  end

  function TestHandler:test_introspect_ok_no_userinfo()
    self.module_resty.openidc.introspect = function(opts)
      return false, false
    end
    self.ngx_headers = {Authorization = "Bearer xxx"}

    self.handler:access({introspection_endpoint = "x"})
    lu.assertTrue(self:log_contains("introspect succeeded"))
  end

  function TestHandler:test_introspect_ok_with_userinfo()
    self.module_resty.openidc.introspect = function(opts)
      return {}, false
    end
    self.ngx_headers = {Authorization = "Bearer xxx"}

    self.handler:access({introspection_endpoint = "x"})
    lu.assertTrue(self:log_contains("introspect succeeded"))
  end


lu.run()


