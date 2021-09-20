local HTTP = game:GetService("HttpService")

function _send(config, headers)
	for k, v in pairs(headers or {}) do
		if k == "Authorization" then continue end
		config.headers[k] = v
	end
	
	if config['method']:upper() == 'GET' then
		return HTTP:RequestAsync({
			Url = config.url,
			Method = config['method']:upper(),
			Headers = config.headers
		})
	elseif config['method']:upper() == 'POST' then
		return HTTP:RequestAsync({
			Url = config.url,
			Method = config['method']:upper(),
			Headers = config.headers,
			Body = config.body,
		})
	else
		return nil
	end
end

local Request = {}
Request.__index = Request

function Request.new(options)
	local self = setmetatable({
		baseURL = options.baseURL,
		token = options.token
	}, Request)
	return self
end

function Request:get(url, headers)
	local config = {
		method = 'get',
		url = self.baseURL .. url,
		headers = {
			['Authorization'] = 'token ' .. self.token,
			['Content-Type'] = 'application/json'
		}
	}
	
	return _send(config, headers)
end

function Request:post(url, data, headers)
	local config = {
		method = 'get',
		url = self.baseURL .. url,
		headers = {
			['Authorization'] = 'token ' .. self.token,
			['Content-Type'] = 'application/json'
		},
		data = HTTP:JSONEncode(data)
	}
	
	return _send(config, headers)
end

return Request
