local skynet = require "skynet"

local max_client = 10240

skynet.start(function()
	print("Server start")
	local service = skynet.newservice("service_mgr")
	skynet.monitor "simplemonitor"
	local lualog = skynet.newservice("lualog")
	local console = skynet.newservice("console")
	skynet.newservice("debug_console",8888)
	skynet.newservice("room_mgr")
	skynet.newservice("mongo_proxy")
	local watchdog = skynet.newservice("watchdog")
	skynet.call(watchdog, "lua", "start", {
		port = 8000,
		maxclient = max_client,
	})

	skynet.exit()
end)
