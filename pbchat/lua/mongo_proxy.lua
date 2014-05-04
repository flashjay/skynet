local skynet = require "skynet"
local mongo = require "mongo"
local json = require "cjson"

local function getconfig(path , pre)
    assert(path)
    local env = pre or {}
    local f = assert(loadfile(path,"t",env))
    f()
    return env
end

local mongo_conf = skynet.getenv "mongo"
local _cfg = getconfig(mongo_conf)["main"]

local config = {port= _cfg.port, host= _cfg.host, db=_cfg.db}

local db

local command = {}

function command.NEW(userid, sid)
    local col = db:getCollection(_cfg.col)
    col:insert({_id= userid, sid= sid})
end

function command.AUTH(userid, sid) -- sid = token
    local col = db:getCollection(_cfg.col)
    local row = col:findOne({_id=userid})
    if not row then
        return 0
    end
    if not row["sid"] then
        return 0
    end
    if sid ~= row["sid"] then
        return 0
    end
    return 1
end

skynet.start(function()
    local mc = mongo.client(config)
    if _cfg.username and _cfg.password then
        local a = mc:auth(_cfg.username, _cfg.password)
        if not a then
            print("[mongo] auth failed, quit..")
            skynet.exit()
        else
            print("[mongo] auth ok")
        end
    end
    db = mc:getDB(config.db)

    command.NEW(1, "TOKEN_STRING")
	skynet.dispatch("lua", function(_,_, cmd, ...)
		local f = command[cmd]
		skynet.ret(skynet.pack(f(...)))
	end)
	skynet.register "MONGO_PROXY"
end)
