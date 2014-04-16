local skynet = require "skynet"
local r = require "response"
local db = {}
local command = {}
local rooms = {}
local users = {}
local history = {} -- 历史消息

function command.REG(userid)
    if not users[userid] then
        users[userid] = 1
    end
end
function command.UNREG(userid)
    if users[userid] then
        users[userid] = nil
    end
end
function command.ISREG(userid)
    if users[userid] then
        return true
    end
    return false
end

function command.JOIN(roomid, userid, fd)
    if not rooms[roomid] then
        rooms[roomid] = {}
        history[roomid] = {}
    end
    rooms[roomid][userid] = fd
    for _, data in ipairs(history[roomid]) do
        data["type"] = "history"
        r.room(fd, 0, data)
    end
end

function command.QUIT(roomid, userid)
    rooms[roomid][userid] = nil
end

function command.SEND(json, user)
    local roomid = json["roomid"]
    local room = rooms[roomid]
    if room then
        local data = {
            type = "msg", 
            msg  = json["msg"], 
            user = user, 
            ts   = os.time()
        }
        for userid, fd in pairs(room) do
            r.room(fd, 0, data)
        end
        table.insert(history[roomid], data)
        if #history[roomid] > 60 then
            for _ in 1, 30 do
                table.remove(history[roomid], 1)
            end
        end
        return 1
    else
        return 0
    end
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...) 
		local f = command[string.upper(cmd)]
		skynet.ret(skynet.pack(f(...)))
	end)
	skynet.register "ROOM"
end)
