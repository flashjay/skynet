local skynet = require "skynet"
local mqueue = require "mqueue"
local snax = require "snax"

skynet.start(function()
	local id = 0
	local pingserver = snax.newservice "pingserver"
	mqueue.register(function(str)
		id = id + 1
		str = string.format("id = %d , %s",id, str)
		return skynet.call(pingserver, "lua", "PING", str)
	end)
end)
