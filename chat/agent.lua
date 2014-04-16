local skynet = require "skynet"
local jsonpack = require "jsonpack"
local socket = require "socket"
local cjson = require "cjson"
local md5 = require "md5"
local r = require "response"

local _gate

local CMD = {}

local client_fd

local rooms = {}

local user = {}

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function (msg, sz)
		return jsonpack.unpack(skynet.tostring(msg,sz))
	end,
	dispatch = function (_, _, session, args)
        print(">> args", args)
        args = cjson.decode(args)

        if #args ~= 3 then
            r.error(client_fd, r.ERROR.INVALID_ARGS)
            return
        end

        local h = args[3] -- hash

        if args[1] == "AUTH" then
            local data = args[2]
            roomid = data["roomid"]
            if rooms[roomid] then
                r.error(client_fd, r.ERROR.DUPLICATE_AUTH)
                return
            end
            local userid = data["userid"]
            local ok,reg= pcall(skynet.call, "ROOM", "lua", "ISREG", userid)

            if reg then
                r.error(client_fd, r.ERROR.DUPLICATE_LOGIN)
                return
            end

            r.auth(client_fd, session, {ret=1})
            rooms[roomid] = userid

            skynet.call("ROOM", "lua", "JOIN", roomid, userid, client_fd)
            skynet.call("ROOM", "lua", "REG", userid)

            user.id = userid
            user.name = data["nickname"]

        elseif args[1] == "ROOM" then
            local msg = args[2]
            roomid = msg["roomid"]
            if not roomid then
                r.error(client_fd, r.ERROR.PARAMS_ERROR)
                return
            end
            if not rooms[roomid] then
                r.error(client_fd, r.ERROR.NOT_AUTH)
                return
            end
            local ok, result = pcall(skynet.call, "ROOM", "lua", "SEND", msg, user)
            if ok then
                r.room(client_fd, session, {type="ret", ret=result})
            else
                r.error(client_fd, r.ERROR.ROOM_ERROR)
            end
        else
            r.error(client_fd, r.ERROR.INVALID_COMMAND)
        end
	end
}

function CMD.start(gate , fd)
	client_fd = fd
	skynet.call(gate, "lua", "forward", fd)
    _gate = gate
    skynet.timeout(3000, function() -- 30s
        local login = false
        for r,u in pairs(rooms) do
            login = true
        end
        if not login then
            skynet.call(gate, "lua", "kick", fd)
        end
        if user.id then
            skynet.call("ROOM", "lua", "UNREG", user.id)
        end
    end)
end

function CMD.exit()
    for roomid, userid in pairs(rooms) do
        skynet.call("ROOM", "lua", "QUIT", roomid, userid)
    end
    if user.id then
        skynet.call("ROOM", "lua", "UNREG", user.id)
    end
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
end)
