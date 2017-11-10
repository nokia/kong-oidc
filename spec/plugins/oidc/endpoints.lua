--[[
-- https://mockbin.org/docs#api-endpoints
-- http://www.softwareishard.com/blog/har-12-spec/#response
--]]

local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("json")


local _M = {}

local default_har = {
  status = 200,
  statusText = "OK",
  httpVersion = "HTTP/1.1",
  headers = {{name = "content-type", value = "application/json"}},
  cookies = {{name = "dummy", value = "dont care"}},
  redirectURL = "",
  bodySize = 0,
  headersSize = 0
}

local function merge(t1, t2)
  for k,v in pairs(t2) do t1[k] = v end
  return t1
end

local function get_har(content)
  return merge(default_har,  content)
end

local function create_bin(data)
  local content = {
    content = {
      mimeType = "text/plain",
      text = data,
      size = data:len()
    }
  }
  local har = json.encode(get_har(content))

  local response_body = {}
  local res, code, response_headers, status = http.request{
    url = "http://mockbin.com/bin/create",
    method = "POST",
    headers = {
      ["Cache-Control"] = "no-cache",
      ["Accept"] = "application/json",
      ["Content-Type"] = "application/json",
      ["Content-Length"] = har:len()
    },
    source = ltn12.source.string(har),
    sink = ltn12.sink.table(response_body)
  }
  local bid = response_body[1]:gsub('"', '')
  return bid
end

local function get(id)
  local response_body = { }

  local res, code, response_headers, status = http.request{
    url = "http://mockbin.org/bin/" .. id,
    method = "POST",
    headers = {
      ["Cache-Control"] = "no-cache",
      ["Accept"] = "application/json",
      ["Content-Type"] = "application/json"
    },
    sink = ltn12.sink.table(response_body)
  }
  return response_body
end

local function authorization()
  return 1  -- TODO. not implemented
end

local function token()
  --[[
        token_js = {
            "sub"       : "alice",
            "iss"       : "https://mockbin.org/",
            "aud"       : "afcc3a0a-aaa4-4bac-b86a-a7bd77259dd3",  # client_id
            "nonce"     : "555",
            "auth_time" : int(time()) - 1,
            "acr"       : "c2id.loa.hisec",
            "iat"       : int(time() + 1000000000),
            "exp"       : int(time() + 1000000000),
        }
        encoded = jwt.encode(token_js, 'secret', algorithm='HS256')
        text = json.dumps({
                "id_token": encoded,
                "access_token": "SlAV32hkKG",
                "token_type": "Bearer",
                "expires_in": 3600
            })
   ]]
  return 1  -- TODO. not implemented
end

local function userinfo()
  local text = json.encode({
    sub                     = "alice",
    email                   = "alice@wonderland.net",
    email_verified          = true,
    name                    = "Alice Adams",
    given_name              = "Alice",
    family_name             = "Adams",
    phone_number            = "+359 (99) 100200305",
    profile                 = "https://c2id.com/users/alice"
  })
  return create_bin(text)
end

local function discovery(abid, tbid, ubid)
  local text = json.encode({
    issuer = "https://mockbin.org/",
    token_endpoint = "https://mockbin.org/bin/1/",
    token_endpoint_auth_methods_supported = {"client_secret_post"},
    userinfo_endpoint = "https://mockbin.org/bin/2/",
    authorization_endpoint = "https://mockbin.com/bin/3/"
  })
  return create_bin(text)
end


function _M.create_endpoints()
  return discovery(authorization(), token(), userinfo())
end

-- print(get("42e386e4-40f4-41ab-accd-7b5ca92708bd"))
-- print("discovery bid: " .. _M.create_endpoints())

return _M

