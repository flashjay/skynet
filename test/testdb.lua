local skynet = require "skynet"

skynet.start(function()
	local result = skynet.call("SIMPLEDB","lua","SET","foobar","hello")
	print(result)
	result = skynet.call("SIMPLEDB","lua","GET","foobar")
	print(result)
	skynet.exit()
end)
