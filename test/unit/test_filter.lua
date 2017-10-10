local filter = require("kong.plugins.oidc.filter")
local lu = require("luaunit")

TestFilter = {}
ngx = {
    var = {
        uri = ""
    }
}

local config =  {
    filters = {  "^/pattern1$","^/pattern2$"}
}
function TestFilter:testIgnoreRequestWhenMatchingPattern1()
    ngx.var.uri = "/pattern1"
    lu.assertFalse(filter.shouldProcessRequest(config))
end


function TestFilter:testIgnoreRequestWhenMatchingPattern2()
    ngx.var.uri = "/pattern2"
    lu.assertFalse(filter.shouldProcessRequest(config))
end


function TestFilter:testProcesseRequestWhenNoMatch()
    ngx.var.uri = "/not_matching"
    lu.assertTrue(filter.shouldProcessRequest(config))
end


function TestFilter:testProcessRequestWhenTheyAreNoFiltersNil()
    ngx.var.uri = "/pattern1"
    config.filters= nil
    lu.assertTrue(filter.shouldProcessRequest(config))
end


function TestFilter:testProcessRequestWhenTheyAreNoFiltersEmpty()
    ngx.var.uri = "/pattern1"
    config.filters= {}
    lu.assertTrue(filter.shouldProcessRequest(config))
end

lu.run()


