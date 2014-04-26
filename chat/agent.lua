local skynet = require "skynet"
local jsonpack = require "jsonpack"
local md5 = require "md5"
local r = require "response"

local h = skynet.getenv "h" -- hash token
local _gate
local _reg = false
local client_fd
local CMD = {}
local rooms = {}
local user = {}
local last_session
local last_active = os.time()
local timeout_login = 3000
local timeout_active = 6000 -- 无活动(包括hb)则踢掉

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function (msg, sz)
		return skynet.tostring(msg,sz)
	end,
	dispatch = function (_, _, pack)
        local session, args = jsonpack.unpack(pack)

        if not args or #args ~= 3 then
            r.error(client_fd, r.ERROR.INVALID_ARGS)
            return
        end

        last_active = os.time()

        if h then
            local _pack = string.sub(pack,0,-12) .. "]"
            if not last_session then
                last_session = session
            end
            if last_session ~= session then
                r.error(client_fd, r.ERROR.INVALID_ARGS)
                return
            end
            last_session = last_session + 1
            local sh = string.sub(md5.sumhexa(_pack .. h), -6)
            if args[3] ~= sh then
                r.error(client_fd, r.ERROR.INVALID_ARGS)
                print("[agent] pack->", pack, sh, arg[3])
                return
            end
        end

        if args[1] == "AUTH" then
            local data = args[2]

            local userid = tonumber(data["userid"])
            -- 同一个连接禁止同时登录多个账号，但是可以进入多个房间
            if user.id and user.id ~= userid then
                r.error(client_fd, r.ERROR.MULTI_USER)
                return
            end
            local token = data["token"]

            local roomid = data["roomid"]
            if not roomid or string.len(roomid) > 32 then
                r.error(client_fd, r.ERROR.INVALID_ROOMID)
                return
            end
            roomid = string.gsub(data["roomid"], "%s", "")
            if rooms[roomid] then
                r.error(client_fd, r.ERROR.DUPLICATE_AUTH)
                return
            end

            -- 认证检查
            local a = skynet.call("MONGO_PROXY", "lua", "AUTH", userid, token)
            r.auth(client_fd, session, {roomid=roomid, ret=a})
            if a ~=1 then return end

            -- 单点登录
            if not _reg then
                local ok,reg= pcall(skynet.call, "ROOM_MGR", "lua", "REG", userid)
                if not reg then
                    r.error(client_fd, r.ERROR.DUPLICATE_LOGIN)
                    return
                end
                _reg = true
            end

            user.id = userid
            user.name = data["username"]

            local room = skynet.call("ROOM_MGR", "lua", "GETROOM", roomid)
            rooms[roomid] = room
            skynet.call(room, "lua", "JOIN", user.id, client_fd)

        elseif args[1] == "ROOM" then
            --local msg = args[2]
            local roomid =  args[2]["roomid"]
            if not roomid then
                r.error(client_fd, r.ERROR.PARAMS_ERROR)
                return
            end
            roomid = tostring(roomid)
            if not rooms[roomid] then
                r.error(client_fd, r.ERROR.NOT_AUTH)
                return
            end
            local ok, result = pcall(skynet.call, rooms[roomid], "lua", "SEND",  args[2], user)
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

local function _timeout()
    skynet.timeout(timeout_active, function()
        if os.time() > last_active + timeout_active/100 then
            CMD.exit()
            if client_fd then
                skynet.call(_gate, "lua", "kick", client_fd)
            end
            return
        end
        _timeout()
    end)
end

function CMD.start(gate , fd)
	client_fd = fd
	skynet.call(gate, "lua", "forward", fd)
    _gate = gate
    skynet.timeout(timeout_login, function() -- 30s 未登录踢掉
        if not _reg then
            skynet.call(gate, "lua", "kick", fd)
        end
        _timeout()
    end)
end

function CMD.exit()
    for roomid, room in pairs(rooms) do
        if user.id then
            skynet.call(room, "lua", "QUIT", user.id)
        end
        rooms[roomid] = nil
    end
    rooms = {}
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
