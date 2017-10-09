local lu = require("luaunit")

-- Which luaunit we have? lua5.1.exe in windows has 2.0. Latest is 3.something.
if not pcall(lu.assertTrue) then
  lu.assertTrue = function(x) assert(x) end
  lu.assertFalse = function(x) assert(not x) end
  lu.assertEquals = function(x, y) assert(x == y) end
  lu.assertItemsEquals = function(t1, t2)
    lu.assertEquals(table.concat(t1, ""), table.concat(t2, "")) -- for now...
  end
end

return lu
