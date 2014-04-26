local skynet = require "skynet"

local command = {}
local rooms = {}
local users = {}
local ucount = 0

function command.REG(userid)
    if not users[userid] then
        users[userid] = 1
        ucount = ucount + 1
        print("[room_mgr] users->", ucount)
        return true
    end
    return false
end
function command.UNREG(userid)
    if users[userid] then
        users[userid] = nil
        ucount = ucount - 1
    end
end

function command.GETROOM(roomid)
    if not rooms[roomid] then
        print("[room_mgr] new room->", roomid)
        rooms[roomid] = skynet.newservice("room", roomid)
    end
    return rooms[roomid]
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...) 
		local f = command[string.upper(cmd)]
		skynet.ret(skynet.pack(f(...)))
	end)
	skynet.register "ROOM_MGR"
end)
