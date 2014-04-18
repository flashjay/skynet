local skynet = require "skynet"
local jsonpack = require "jsonpack"
local json_safe = require "cjson.safe"
local md5 = require "md5"
local r = require "response"

local _gate
local _reg = false
local client_fd
local CMD = {}
local rooms = {}
local user = {}

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function (msg, sz)
		return jsonpack.unpack(skynet.tostring(msg,sz))
	end,
	dispatch = function (_, _, session, args)
        local _args = json_safe.encode(args)
        print(">> args", _args)

        if not args or #args ~= 3 then
            r.error(client_fd, r.ERROR.INVALID_ARGS)
            return
        end

        local h = args[3] -- hash

        if args[1] == "AUTH" then
            local data = args[2]

            local userid = tonumber(data["userid"])
            -- 同一个连接禁止同时登录多个账号，但是可以进入多个房间
            if user.id and user.id ~= userid then
                r.error(client_fd, r.ERROR.MULTI_USER)
                return
            end
            user.id = userid
            user.name = data["username"]
            roomid = data["roomid"]
            token = data["token"]

            if not roomid or string.len(roomid) > 32 then
                r.error(client_fd, r.ERROR.INVALID_ROOMID)
                return
            end
            if rooms[roomid] then
                r.error(client_fd, r.ERROR.DUPLICATE_AUTH)
                return
            end

            -- 认证检查
            local a = skynet.call("MONGO_PROXY", "lua", "AUTH", user.id, token)
            r.auth(client_fd, session, {roomid=roomid, ret=a})
            if a ~=1 then return end

            -- 单点登录
            if not _reg then
                local ok,reg= pcall(skynet.call, "ROOM_MGR", "lua", "REG", user.id)
                if not reg then
                    r.error(client_fd, r.ERROR.DUPLICATE_LOGIN)
                    return
                end
                _reg = true
            end

            room = skynet.call("ROOM_MGR", "lua", "GETROOM", roomid)
            rooms[roomid] = room
            skynet.call(room, "lua", "JOIN", user.id, client_fd)

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
            room = rooms[roomid]
            local ok, result = pcall(skynet.call, room, "lua", "SEND", msg, user)
            if ok then
                r.room(client_fd, session, {type="ret", roomid=roomid, ret=result})
            else
                r.error(client_fd, r.ERROR.ROOM_ERROR)
            end
        elseif args[1] == "HB" then
            r.heartbeat(client_fd, session)
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
        if _reg and user.id then
            skynet.call("ROOM_MGR", "lua", "UNREG", user.id)
        end
    end)
end

function CMD.exit()
    for roomid, room in pairs(rooms) do
        if user.id then
            skynet.call(room, "lua", "QUIT", user.id)
        end
    end
    if _reg and user.id then
        skynet.call("ROOM_MGR", "lua", "UNREG", user.id)
    end
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
end)
