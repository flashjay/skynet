local skynet = require "skynet"
local r = require "response"

local roomid = ...

local command = {}
local users = {}
local ucount = 0
local history = {} -- 历史消息
local max = 30 -- 最多向客户端发送的历史条数

function command.JOIN(userid, fd)
    users[userid] = fd
    ucount = ucount + 1
    print("[room] user joined->", roomid, userid, fd, "#", ucount)
    local start = 1
    local count = #history
    if count > max then
        start = count - max
    end
    for i = start, count do
        r.room(fd, 0, history[i])
    end
end

function command.QUIT(userid)
    users[userid] = nil
    ucount = ucount - 1
end

-- 广告、敏感词过滤
local function badword(msg)
    return false
end

function command.SEND(json, user)
    if badword(json["msg"]) then
        return 0
    end
    local data = {
        type = "msg",
        roomid = roomid,
        msg  = json["msg"],
        user = user,
        ts   = os.time()
    }
    for userid, fd in pairs(users) do
        r.room(fd, 0, data)
    end
    data["type"] = "history"
    table.insert(history, data)
    if #history >= max*2 then
        for _=1,max do
            table.remove(history, 1)
        end
    end
    return 1
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...) 
		local f = command[string.upper(cmd)]
		skynet.ret(skynet.pack(f(...)))
	end)
end)
