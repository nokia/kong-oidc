local cjson = require("cjson")
local responses = require "kong.tools.responses"
local http = require"socket.http"
local ltn12 = require"ltn12"
local JSON = require "kong.plugins.oidc.json"
local UserService = {}

function UserService.get_userdata(user_id, config)
    payload_body = {}
    payload_body["user_id"] = user_id
    payload = UserService.compose_payload(payload_body)
    local response_body = { }
    local res, code, response_headers, status = http.request
    {
      url = config.user_service_endpoint,
      method = "GET",
      source = ltn12.source.string(payload),
      headers = UserService.compose_headers(payload:len()),
      sink = ltn12.sink.table(response_body)
    }

    if code ~= 200 then
      ngx.req.set_header("X-Error", 'No userdata')
      print(code)
      print(response_headers)
      print(status)
      print(table.concat(response_body))
      return {}
    end
    return cjson.decode(table.concat(response_body))
end

function UserService.get_headers(user_id, config)
    local user_data = UserService.get_userdata(user_id, config)

    for header_name, header_value in pairs(user_data) do
        header_name_converted = "X-" .. string.gsub("_"..header_name, "%W%l", string.upper):sub(2)
        header_name_converted = header_name_converted:gsub("_+", "-")
        ngx.req.set_header(header_name_converted, header_value)
    end
end

function UserService.compose_payload(body)
    local headers = {}
    local uri_args = {}
    local body_data = body

    local raw_json_headers    = JSON:encode(headers)
    local raw_json_uri_args    = JSON:encode(uri_args)
    local raw_json_body_data    = JSON:encode(body_data)

    return [[ {"headers":]] .. raw_json_headers .. [[,"uri_args":]] .. raw_json_uri_args.. [[,"body_data":]] .. raw_json_body_data .. [[} ]]
end

function UserService.compose_headers(len)
    return {
      ["Content-Type"] = "application/json",
      ["Content-Length"] = len
    }
end

return UserService