local skynet = require "skynet"
local r = require "response"

local roomid = ...

local command = {}
local users = {}
local history = {} -- 历史消息

function command.JOIN(userid, fd)
    print(">> room - user joined->", roomid, userid, fd)
    users[userid] = fd
    for _, data in ipairs(history) do
        r.room(fd, 0, data)
    end
end

function command.QUIT(userid)
    users[userid] = nil
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
    if #history > 60 then
        for _ in 1, 30 do
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
