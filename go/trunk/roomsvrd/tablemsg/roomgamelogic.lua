local base = require "base"
local msghelper = require "tablehelper"
local timetool = require "timetool"
local timer = require "timer"
require "enum"
local RoomGameLogic = {}
--[[
ETableState = {
	TABLE_STATE_UNKNOW = 0,
	TABLE_STATE_WAIT_MIN_PLAYER = 1,        --等待最小玩家数
	TABLE_STATE_WAIT_GAME_START = 2,        --等待桌主开始游戏
	TABLE_STATE_WAIT_CLIENT_ACTION = 3,     --等待client操作
	TABLE_STATE_WAIT_ONE_GAME_REAL_END = 4, --等待一局游戏真正结束
	TABLE_STATE_WAIT_GAME_END = 5,     --等待游戏结束
	TABLE_STATE_GAME_START = 6,        --游戏开始状态
	TABLE_STATE_ONE_GAME_START = 7,    --一局游戏开始
	TABLE_STATE_CONTINUE = 8,
	TABLE_STATE_CONTINUE_AND_STANDUP = 9,
	TABLE_STATE_CONTINUE_AND_LEAVE = 10,
	TABLE_STATE_ONE_GAME_END = 11,      --一局游戏结束
	TABLE_STATE_ONE_GAME_REAL_END = 12, --一局游戏真正结束 
	TABLE_STATE_GAME_END = 13,  	   --游戏结束
}
]]
function RoomGameLogic.init(gameobj, tableobj)
	gameobj.tableobj = tableobj
	gameobj.stateevent[ETableState.TABLE_STATE_GAME_START] = RoomGameLogic.gamestart
	gameobj.stateevent[ETableState.TABLE_STATE_ONE_GAME_START] = RoomGameLogic.onegamestart
	gameobj.stateevent[ETableState.TABLE_STATE_ONE_GAME_END] = RoomGameLogic.onegameend
	gameobj.stateevent[ETableState.TABLE_STATE_ONE_GAME_REAL_END] = RoomGameLogic.onegamerealend
	gameobj.stateevent[ETableState.TABLE_STATE_GAME_END] = RoomGameLogic.gameend
	gameobj.stateevent[ETableState.TABLE_STATE_CONTINUE] = RoomGameLogic.continue
	gameobj.stateevent[ETableState.TABLE_STATE_CONTINUE_AND_STANDUP] = RoomGameLogic.continue_and_standup
	gameobj.stateevent[ETableState.TABLE_STATE_CONTINUE_AND_LEAVE] = RoomGameLogic.continue_and_leave		
	return true
end

function RoomGameLogic.run(gameobj)
	local f = nil
	while true do
		if gameobj.tableobj.state == ETableState.TABLE_STATE_WAIT_MIN_PLAYER then
			break
		end

		f = gameobj.stateevent[gameobj.tableobj.state]
		if f == nil then
			break
		end
		f(gameobj)
	end
end

function RoomGameLogic.gamestart(gameobj)
	local tableobj = gameobj.tableobj

	tableobj.state = ETableState.TABLE_STATE_ONE_GAME_START
end

function RoomGameLogic.onegamestart(gameobj)
	local tableobj = gameobj.tableobj
	local pawntype = base.get_random(EPawnType.PAWN_TYPE_BLACK, EPawnType.PAWN_TYPE_WHITE)

	--初始化桌子
	RoomGameLogic.onegamestart_inittable(gameobj)

	for _, seat in ipairs(tableobj.seats) do
		RoomGameLogic.onegamestart_initseat(gameobj, seat)
	end

	local action_seat_index
	local seat = tableobj.seats[1]	
	seat.pawntype = pawntype
	seat = tableobj.seats[2]
	if pawntype == EPawnType.PAWN_TYPE_BLACK then
		seat.pawntype = EPawnType.PAWN_TYPE_WHITE
		tableobj.gogame:InitGoBoard(1, 2)
		action_seat_index = 1
	else
		seat.pawntype = EPawnType.PAWN_TYPE_BLACK
		tableobj.gogame:InitGoBoard(2, 1)
		action_seat_index = 2		
	end

	local gamestartntcmsg = {}
	gamestartntcmsg.gameinfo = {}
	msghelper:copy_table_gameinfo(gamestartntcmsg.gameinfo)
	msghelper:sendmsg_to_alltableplayer("GameStartNtc", gamestartntcmsg)

	tableobj.action_seat_index = action_seat_index
	tableobj.action_to_time = timetool.get_time() + tableobj.conf.action_timeout

	--下发当前玩家操作协议	
	local doactionntcmsg = {
		rid = tableobj.seats[action_seat_index].rid,
		roomsvr_seat_index = action_seat_index,
		action_to_time = tableobj.action_to_time,
	}
	msghelper:sendmsg_to_alltableplayer("DoactionNtc", doactionntcmsg)

	tableobj.timer_id = timer.settimer(tableobj.conf.action_timeout*100, "doaction", doactionntcmsg)

	tableobj.state = ETableState.TABLE_STATE_WAIT_CLIENT_ACTION
end

function RoomGameLogic.continue(gameobj)
	local tableobj = gameobj.tableobj
	if tableobj.timer_id >= 0 then
		timer.cleartimer(tableobj.timer_id)
		tableobj.timer_id = -1
	end

	local seat = tableobj.seats[tableobj.action_seat_index]

	--[[
		EActionType = {
			ACTION_TYPE_UNKNOW = 0,
			ACTION_TYPE_STANDUP = 1,
			ACTION_TYPE_LAOZI = 2,
			ACTION_TYPE_TIMEOUT = 3,
		}
	]]

	local noticemsg = {
		rid = seat.rid,
		roomsvr_seat_index = tableobj.action_seat_index,
		action_type = tableobj.action_type,
		action_x = tableobj.action_x,
		action_y = tableobj.action_y,
		raisins = {}
	}
	local is_end_game = false
	if tableobj.action_type == EActionType.ACTION_TYPE_STANDUP then
		--如果玩家站起，那么游戏结束
		is_end_game = true
		RoomGameLogic.set_winorlose(gameobj, nil, tableobj.action_seat_index)
	elseif tableobj.action_type == EActionType.ACTION_TYPE_LAOZI then
		local result = tableobj.gogame:PlayerMove(tableobj.action_seat_index ,tableobj.action_x, tableobj.action_y)
		if result > 0 then
			if tableobj.gogame:GetCaptureList() ~= nil and #tableobj.gogame:GetCaptureList() > 0 then
				noticemsg.raisins = tableobj.gogame:GetCaptureList()
			end
		end

		local loser = tableobj.gogame:CheckWinLose()
		if loser > 0 then
			is_end_game = true
			RoomGameLogic.set_winorlose(gameobj, nil,loser)	
		end

	elseif tableobj.action_type == EActionType.ACTION_TYPE_TIMEOUT then
		seat.timeout_count = seat.timeout_count + 1
		if seat.timeout_count >= tableobj.conf.action_timeout_count then
			is_end_game = true
			RoomGameLogic.set_winorlose(gameobj, nil, tableobj.action_seat_index)			
		end 
	end
	msghelper:sendmsg_to_alltableplayer("DoactionResultNtc", noticemsg)
	--判断是否结束游戏
	if is_end_game then
		tableobj.state = ETableState.TABLE_STATE_ONE_GAME_END
		return
	end
	--通知下一个玩家操作
		--下发当前玩家操作协议	
	if tableobj.action_seat_index == 1 then
		tableobj.action_seat_index = 2
	else
		tableobj.action_seat_index = 1
	end
	tableobj.action_to_time = timetool.get_time() + tableobj.conf.action_timeout
	
	local doactionntcmsg = {
		rid = tableobj.seats[tableobj.action_seat_index].rid,
		roomsvr_seat_index = tableobj.action_seat_index,
		action_to_time = tableobj.action_to_time,
	}
	msghelper:sendmsg_to_alltableplayer("DoactionNtc", doactionntcmsg)

	tableobj.timer_id = timer.settimer(tableobj.conf.action_timeout*100, "doaction", doactionntcmsg)

	tableobj.state = ETableState.TABLE_STATE_WAIT_CLIENT_ACTION
end

function RoomGameLogic.continue_and_standup(gameobj)
	RoomGameLogic.continue(gameobj)
end

function RoomGameLogic.continue_and_leave(gameobj)
	
end


function RoomGameLogic.onegameend(gameobj)
	local noticemsg = {

	}
	msghelper:sendmsg_to_tableplayer(seat, "gameresult", noticemsg)
	msghelper:sendmsg_to_tableplayer(seat, "GameResultNtc", noticemsg)
end

function RoomGameLogic.onegamerealend(gameobj)
	-- body
end

function RoomGameLogic.gameend(gameobj)
	-- body
end

function RoomGameLogic.onsitdowntable(gameobj, seat)
	
end

function RoomGameLogic.is_ingame(gameobj, seat)
	return (seat.state == ESeatState.SEAT_STATE_PLAYING)
end

function RoomGameLogic.onegamestart_initseat(gameobj, seat)
	seat.state = ESeatState.SEAT_STATE_PLAYING
	seat.pawntype = 
	EPawnType.PAWN_TYPE_UNKNOW
	seat.timeout_count = 0
	seat.win = EWinResult.WIN_RESULT_UNKNOW
end

function RoomGameLogic.onegamestart_inittable(gameobj)
	local tableobj = gameobj.tableobj
	tableobj.action_seat_index = 0
	tableobj.action_to_time = 0
	tableobj.action_type = 0
	tableobj.action_x = -1
	tableobj.action_y = -1	
	if tableobj.timer_id >= 0 then
		timer.cleartimer(tableobj.timer_id)
		tableobj.timer_id = -1
	end	
end

function RoomGameLogic.standup_clear_seat(gameobj, seat)
	seat.rid = 0
	seat.state = ESeatState.SEAT_STATE_NO_PLAYER
	seat.gatesvr_id=""
	seat.agent_address = -1
	seat.playerinfo.rolename = ""
	seat.playerinfo.logo=""
	seat.playerinfo.sex=0
	seat.is_tuoguan = EBOOL.FALSE
	seat.is_robot = false
	seat.timeout_count = 0
	seat.win = EWinResult.WIN_RESULT_UNKNOW
end

--设置玩家的胜负
function RoomGameLogic.set_winorlose(gameobj, win_index, lose_index)
	local tableobj = gameobj.tableobj
	local seat
	if win_index ~= nil then
		seat = tableobj.seats[win_index]		
		seat.win = EWinResult.WIN_RESULT_WIN
		if lose_index == nil then
			if win_index == 1 then
				lose_index = 2
			else
				lose_index = 1
			end
			seat = tableobj.seats[lose_index]
			seat.win = EWinResult.WIN_RESULT_LOSE
			return			
		end
	end	

	if lose_index ~= nil then
		seat = tableobj.seats[lose_index]
		seat.win = EWinResult.WIN_RESULT_LOSE
		if win_index == nil then
			if lose_index == 1 then
				win_index = 2
			else
				win_index = 1
			end
			seat = tableobj.seats[win_index]
			seat.win = EWinResult.WIN_RESULT_WIN
		end		
	end
end

return RoomGameLogic