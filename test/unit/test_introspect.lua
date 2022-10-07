local ffi = require "ffi"
local ffi_new = ffi.new
local ffi_str = ffi.string
local C = ffi.C
--local setmetatable = setmetatable
--local error = error


local _M = { _VERSION = '0.14' }


ffi.cdef[[
int RAND_bytes(unsigned char *buf, int num);
int RAND_pseudo_bytes(unsigned char *buf, int num);
]]


function _M.bytes(len, strong)
    local buf = ffi_new("char[?]", len)
    if strong then
        if C.RAND_bytes(buf, len) == 0 then
            return nil
        end
    else
        C.RAND_pseudo_bytes(buf,len)
    end

    return ffi_str(buf, len)
end


local lu = require("luaunit")

TestIntrospect = require("test.unit.mockable_case"):extend()


function TestIntrospect:setUp()
  TestIntrospect.super:setUp()
  self.handler = require("kong.plugins.oidc.handler")()
  _M.bytes(1, 1)
end

function TestIntrospect:tearDown()
  TestIntrospect.super:tearDown()
end

function TestIntrospect:test_access_token_exists()
  ngx.req.get_headers = function() return {Authorization = "Bearer xxx"} end
  local dict = {}
  function dict:get(key) return key end
  _G.ngx.shared = {introspection = dict }

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

function TestIntrospect:test_no_authorization_header()
  package.loaded["resty.openidc"].authenticate = function(...) return {}, nil end
  ngx.req.get_headers = function() return {} end

  local headers = {}
  ngx.req.set_header = function(h, v)
    headers[h] = v
  end

  self.handler:access({introspection_endpoint = "x"})
  lu.assertFalse(self:log_contains(self.mocked_ngx.ERR))
  lu.assertEquals(headers['X-Userinfo'], nil)
end


lu.run()
