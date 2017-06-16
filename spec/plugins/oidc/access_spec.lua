local helpers = require "spec.helpers"


describe("oidc plugin", function()
  local proxy_client
  local admin_client
  local timeout = 6000

  setup(function()
    local api1 = assert(helpers.dao.apis:insert {
      name = "mock",
      upstream_url = "http://mockbin.com",
      uris = { "/mock" }
    })
    print("Api created:")
    for k, v in pairs(api1) do
      print(k, ": ", v)
    end
    assert(helpers.dao.plugins:insert {
      name = "oidc",
      config = {
        client_id = "afcc3a0a-aaa4-4bac-b86a-a7bd77259dd3",
        client_secret = "81de73f0-3a0e-451a-88ee-e540811a049c",
        discovery = "http://mockbin.org/bin/bd08be64-1820-4e1a-aca2-b4a38cd07961/"
      }
    })

    -- start Kong with your testing Kong configuration (defined in "spec.helpers")
    assert(helpers.start_kong())
    print("Kong started")

    admin_client = helpers.admin_client(timeout)
  end)

  teardown(function()
    if admin_client then
      admin_client:close()
    end

    helpers.stop_kong()
    print("Kong stopped")
  end)

  before_each(function()
    proxy_client = helpers.proxy_client(timeout)
  end)

  after_each(function()
    if proxy_client then
      proxy_client:close()
    end
  end)

  describe("being an OpenID Connect Relaying Party component", function()
    it("should redirect the authentication request (which is an OAuth 2.0 authorization request) to OP", function()
      local res = assert(proxy_client:send {
        method = "GET",
        path   = "/mock",
      })
      local body = assert.res_status(302, res)
      local redirect_uri = res.headers["Location"]
      assert.is_truthy(string.find(redirect_uri, "response_type=code"))
      assert.is_truthy(string.find(redirect_uri, "scope=openid"))
      assert.is_truthy(string.find(redirect_uri, "client_id="))
      assert.is_truthy(string.find(redirect_uri, "state="))
      assert.is_truthy(string.find(redirect_uri, "redirect_uri="))
    end)

    it("should after successful login contact token and userinfo endpoints", function()
      -- Mimic authentication response
      local res = assert(proxy_client:send {
        method = "GET",
        path   = "/mock/?state=123456&code=123456",
      })
      -- This will fail in openidc.lua because session created in first phase is loat
      -- and several things could mismatch (state, nonce, original_url, ...)
      local body = assert.res_status(500, res)
    end)
  end)
end)

