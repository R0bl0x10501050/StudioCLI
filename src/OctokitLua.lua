local HTTP = game:GetService("HttpService")
local BaseURL = script:GetAttribute("BaseURL")

local OctokitLua = {}
OctokitLua.__index = OctokitLua

function OctokitLua.new(token)
	local self = setmetatable({
		request = function(str, tbl, body)
			local method = str:split(" ")[1]
			local url = BaseURL..str:split(" ")[2]
			
			for k in string.gmatch(url, "{[%w|_]*}") do
				url = url:gsub(k, tbl[k:gsub("{", ""):gsub("}", "")])
			end
			
			if method:upper() == "GET" then
				local response = HTTP:RequestAsync({
					Url = url,
					Method = method:upper(),
					Headers = {
						Authorization = "token "..token
					}
				})
				return HTTP:JSONDecode(response.Body), response.Success, {statusCode = response.StatusCode, statusMessage = response.StatusMessage, headers = response.Headers}
			elseif method then
				local response = HTTP:RequestAsync({
					Url = url,
					Method = method:upper(),
					Headers = {
						Authorization = "token "..token
					},
					Body = HTTP:JSONEncode(body or {})
				})
				return HTTP:JSONDecode(response.Body), response.Success, {statusCode = response.StatusCode, statusMessage = response.StatusMessage, headers = response.Headers}
			else
				return nil, false, {statusCode = 400, statusMessage = "Incorrect method type. Use a valid HTTP method instead."}
			end
		end
	}, OctokitLua)
	return self
end

return OctokitLua
