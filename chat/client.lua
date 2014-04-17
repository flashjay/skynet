package.cpath = "luaclib/?.so"

local socket = require "clientsocket"
local cjson = require "cjson"

local fd = socket.connect("127.0.0.1", 8000)

local last
local result = {}

local function dispatch()
	while true do
		local status
		status, last = socket.recv(fd, last, result)
		if status == nil then
			error "Server closed"
		end
		if not status then
			break
		end
		for _, v in ipairs(result) do
			local session,t,str = string.match(v, "(%d+)(.)(.*)")
			assert(t == '-' or t == '+')
			session = tonumber(session)
			print("Response:", session, str)
		end
	end
end

local session = 0

local function send_tgw_header()
    local header = "tgw_l7_forward\r\nHost:chat.xxx.twsapp.com:8000\r\n\r\n"
    -- 不加size直接send 
    -- http://wiki.open.qq.com/wiki/TGW%E6%8E%A5%E5%85%A5%E8%AF%B4%E6%98%8E
    socket.rawsend(fd, header)
end

local function send_request(v)
	session = session + 1
	local str = string.format("%d+%s",session, v)
	socket.send(fd, str)
	print("Request:", session)
end

send_tgw_header()

while true do
	dispatch()
	local cmd = socket.readline()
	if cmd then
        send_request(cmd)
	else
		socket.usleep(100)
	end
end
