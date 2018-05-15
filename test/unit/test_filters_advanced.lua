local filter = require("kong.plugins.oidc.filter")
local lu = require("luaunit")

TestFilter = require("test.unit.mockable_case"):extend()

function TestFilter:setUp()
  TestFilter.super:setUp()
  _G.ngx = {
    var = {
      uri = ""
    }
  }
end

function TestFilter:tearDown()
  TestFilter.super:tearDown()
end


local config =  {
  filters = {  "^/auth$","^/auth[^%w_%-%.~]","^/arc$","^/arc[^%w_%-%.~]","^/projects/%d+/zeppelin[^%w_%-%.~]","^/projects/%d+/zeppelin$"}
}

function TestFilter:testIgnoreRequestWhenUriIsAuth()
  ngx.var.uri = "/auth"
  lu.assertFalse(filter.shouldProcessRequest(config))

  ngx.var.uri = "/auth/"
  lu.assertFalse(filter.shouldProcessRequest(config))
end

function TestFilter:testIgnoreRequestWhenUriIsArc()
  ngx.var.uri = "/arc"
  lu.assertFalse(filter.shouldProcessRequest(config))

  ngx.var.uri = "/arc/"
  lu.assertFalse(filter.shouldProcessRequest(config))
end

function TestFilter:testProcessRequestWhichAreAllowed()
  ngx.var.uri = "/not_auth"
  assert(filter.shouldProcessRequest(config) == true)
end

function TestFilter:testIgnoreRequestBeingIdenticalToFilter()
  ngx.var.uri = "/arc"
  lu.assertFalse(filter.shouldProcessRequest(config) )
end

function TestFilter:testIgnoreRequestStartingWithFilterFollowedBySlash()
  ngx.var.uri = "/arc/"
  lu.assertFalse(filter.shouldProcessRequest(config) )
end

function TestFilter:testIgnoreRequestStartingWithFilterFollowedByPaths()
  ngx.var.uri = "/arc/de/triomphe"
  lu.assertFalse(filter.shouldProcessRequest(config) )

end

function TestFilter:testIgnoreRequestStartingWithFilterFollowedByQuestionmark()
  ngx.var.uri = "/arc?"
  lu.assertFalse(filter.shouldProcessRequest(config) )

  ngx.var.uri = "/arc?de=triomphe"
  lu.assertFalse(filter.shouldProcessRequest(config) )

end

function TestFilter:testIgnoreRequestStartingWithFilterFollowedByQuestionmark()
  ngx.var.uri = "/arc?"
  lu.assertFalse(filter.shouldProcessRequest(config) )

  ngx.var.uri = "/arc?de=triomphe"
  lu.assertFalse(filter.shouldProcessRequest(config) )

end

function TestFilter:testPrefixNotAtTheStart()
  ngx.var.uri = "/process_this/arc"
  lu.assertTrue(filter.shouldProcessRequest(config) )

  ngx.var.uri = "/process_this/arc/de/triomphe"
  lu.assertTrue(filter.shouldProcessRequest(config) )

  ngx.var.uri = "/process_this/architecture"
  lu.assertTrue(filter.shouldProcessRequest(config) )

end

function TestFilter:testLowercaseLetterAfterPrefix()
  ngx.var.uri = "/architecture"
  lu.assertTrue(filter.shouldProcessRequest(config) )
end

function TestFilter:testUppercaseLetterLetterAfterPrefix()
  ngx.var.uri = "/archITACTURE"
  lu.assertTrue(filter.shouldProcessRequest(config) )
end

function TestFilter:testDigitAfterPrefix()
  ngx.var.uri = "/arc123"
  lu.assertTrue(filter.shouldProcessRequest(config) )
end

function TestFilter:testHyphenAfterPrefix()
  ngx.var.uri = "/arc-123"
  lu.assertTrue(filter.shouldProcessRequest(config) )
end

function TestFilter:testPeriodAfterPrefix()
  ngx.var.uri = "/arc.123"
  lu.assertTrue(filter.shouldProcessRequest(config) )
end

function TestFilter:testUnderscoreAfterPrefix()
  ngx.var.uri = "/arc_123"
  lu.assertTrue(filter.shouldProcessRequest(config) )
end

function TestFilter:testTildeAfterPrefix()
  ngx.var.uri = "/arc~123"
  lu.assertTrue(filter.shouldProcessRequest(config) )
end

lu.run()
