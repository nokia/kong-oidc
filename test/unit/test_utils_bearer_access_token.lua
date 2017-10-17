local utils = require("kong.plugins.oidc.utils")
local lu = require("luaunit")

TestToken = require("test.unit.mockable_case"):extend()

function TestToken:setUp()
  TestToken.super:setUp()
end

function TestToken:tearDown()
  TestToken.super:tearDown()
end

function TestToken:test_access_token_authorization_missing()
  _G.ngx = {req = {
    get_headers = function() return {} end }
  }
  lu.assertFalse(utils.has_bearer_access_token())
end

function TestToken:test_access_token_bearer_missing()
  _G.ngx = {req = {
    get_headers = function() return {"Authorization"} end }
  }
  lu.assertFalse(utils.has_bearer_access_token())
end

function TestToken:test_access_token_bearer_exists()
  _G.ngx = {req = {
    get_headers = function() return {Authorization = "Bearer xxx"} end }
  }
  lu.assertTrue(utils.has_bearer_access_token())
end


lu.run()
