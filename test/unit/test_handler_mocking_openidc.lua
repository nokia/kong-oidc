local lu = require("luaunit")
TestHandler = require("test.unit.mockable_case"):extend()


function TestHandler:setUp()
  TestHandler.super:setUp()

  package.loaded["resty.openidc"] = nil
  self.module_resty = {openidc = {
    authenticate = function(...) return {}, nil end }
  }
  package.preload["resty.openidc"] = function()
    return self.module_resty.openidc
  end

  self.handler = require("kong.plugins.oidc.handler")()
end

function TestHandler:tearDown()
  TestHandler.super:tearDown()
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
  ngx.encode_base64 = function(x)
    return "eyJzdWIiOiJzdWIifQ=="
  end
  
  local headers = {}
  ngx.req.set_header = function(h, v)
    headers[h] = v
  end

  self.handler:access({})
  lu.assertTrue(self:log_contains("calling authenticate"))
  lu.assertEquals(ngx.ctx.authenticated_credential.id, "sub")
  lu.assertEquals(headers['X-Userinfo'], "eyJzdWIiOiJzdWIifQ==")
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
  ngx.req.get_headers = function() return {Authorization = "Bearer xxx"} end

  self.handler:access({introspection_endpoint = "x"})
  lu.assertTrue(self:log_contains("introspect succeeded"))
end

function TestHandler:test_introspect_ok_with_userinfo()
  self.module_resty.openidc.introspect = function(opts)
    return {}, false
  end
  ngx.req.get_headers = function() return {Authorization = "Bearer xxx"} end

  ngx.encode_base64 = function(x)
    return "eyJzdWIiOiJzdWIifQ=="
  end

  local headers = {}
  ngx.req.set_header = function(h, v)
    headers[h] = v
  end

  self.handler:access({introspection_endpoint = "x"})
  lu.assertTrue(self:log_contains("introspect succeeded"))
  lu.assertEquals(headers['X-Userinfo'], "eyJzdWIiOiJzdWIifQ==")
end

function TestHandler:test_bearer_only_with_good_token()
  self.module_resty.openidc.introspect = function(opts)
    return {sub = "sub"}, false
  end
  ngx.req.get_headers = function() return {Authorization = "Bearer xxx"} end

  ngx.encode_base64 = function(x)
    return "eyJzdWIiOiJzdWIifQ=="
  end

  local headers = {}
  ngx.req.set_header = function(h, v)
    headers[h] = v
  end

  self.handler:access({introspection_endpoint = "x", bearer_only = "yes", realm = "kong"})
  lu.assertTrue(self:log_contains("introspect succeeded"))
  lu.assertEquals(headers['X-Userinfo'], "eyJzdWIiOiJzdWIifQ==")
end

function TestHandler:test_bearer_only_with_bad_token()
  self.module_resty.openidc.introspect = function(opts)
    return {}, "validation failed"
  end
  ngx.req.get_headers = function() return {Authorization = "Bearer xxx"} end

  self.handler:access({introspection_endpoint = "x", bearer_only = "yes", realm = "kong"})

  lu.assertEquals(ngx.header["WWW-Authenticate"], 'Bearer realm="kong",error="validation failed"')
  lu.assertEquals(ngx.status, ngx.HTTP_UNAUTHORIZED)
  lu.assertFalse(self:log_contains("introspect succeeded"))
end

lu.run()


