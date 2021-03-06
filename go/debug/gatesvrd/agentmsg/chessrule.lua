local rule_level = 
{
	--局数，升1级,升2级,降1级,降2级
	{10,6,8,0,0},     --18-17 
	{10,6,8,7,0},     --17-16
	{10,6,8,7,9},     --16-15
	{12,7,10,8,10},   --15-14
	{12,7,10,8,10},   --14-13
    {12,7,10,8,10},   --13-12
	{14,8,12,10,12},  --12-11
	{14,8,12,10,12},  --11-10
	{14,8,12,10,12},  --10-9
	{16,10,14,11,14},  --9-8
	{16,10,14,11,14},  --8-7
	{16,10,14,11,14},  --7-6
	{16,10,14,11,14},  --6-5
	{18,11,15,12,16},  --5-4
	{18,11,15,12,16},  --4-3
	{18,11,15,12,16},  --3-2
	{19,12,16,13,17},  --2级-1段  
	--段位配置
	{19,12,16,13,17},  --1-2
	{19,12,16,13,17},  --2-3
	{20,13,18,14,18},  --3-4
	{20,13,18,14,18},  --4-5
	{20,14,18,14,18},  --5-6
	{20,14,18,14,18},  --6-7
	{20,14,0,14,18},   --7-8
	{20,0,0,14,18},   --8-9
	
}
require "enum"
-- EWinResult = {
-- 	WIN_RESULT_UNKNOW = 0,
-- 	WIN_RESULT_WIN = 1,
-- 	WIN_RESULT_LOSE = 2,
-- 	WIN_RESULT_DRAW = 3,
-- }
local RULE = 
{
	SET = 1,
	UPGRADE = 2,
	UPGRADE_T = 3,
	DOWNGRADE = 4,
	DOWNGRADE_T = 5,
}

local chessrule = {}

local function getwinlose( playerrecord )
	local win = 0
	local lose = 0
	for i,v in ipairs(playerrecord) do
		if v == EWinResult.WIN_RESULT_WIN then
			win = win + 1
		elseif v == EWinResult.WIN_RESULT_LOSE then
			lose = lose + 1
		end
	end
	return win,lose
end 

function chessrule.upgrdelevel(level,playerrecord)
	local playerlevel=level
	if rule_level[level] ~= nil then
		local rulelevel = rule_level[level]
		if #playerrecord >= rulelevel[RULE.SET] then
			local win,lose = getwinlose(playerrecord)
			if rulelevel[RULE.DOWNGRADE_T] > 0 then  --降2级
				if lose >= rulelevel[RULE.DOWNGRADE_T] then
					playerlevel = playerlevel - 2
				end
			elseif rulelevel[RULE.DOWNGRADE] > 0 then --降1级
				if lose >= rulelevel[RULE.DOWNGRADE] then
					playerlevel = playerlevel - 1
				end
			end

			if rulelevel[RULE.UPGRADE_T] > 0 then  --升2级
				if win >= rulelevel[RULE.UPGRADE_T] then
					playerlevel = playerlevel + 2
				end
			elseif rulelevel[RULE.UPGRADE] > 0 then --升1级
				if win >= rulelevel[RULE.UPGRADE] then
					playerlevel = playerlevel + 1 
				end
			end 		
		end 
	end
	return playerlevel
end

function chessrule.checklevel( level,playerrecord,playerrule )
	if rule_level[level] ~= nil then
		local rulelevel = rule_level[level]

		local win,lose = getwinlose(playerrecord)

		if rulelevel[RULE.DOWNGRADE_T] > 0 then  --降2级
			assert(lose<rulelevel[RULE.DOWNGRADE_T],"chessrule.checklevel RULE.DOWNGRADE_T ")
			playerrule[RULE.DOWNGRADE_T-1] = rulelevel[RULE.DOWNGRADE_T] - lose
		else
			playerrule[RULE.DOWNGRADE_T-1] = 0
		end

		if rulelevel[RULE.DOWNGRADE] > 0 then --降1级
			assert(lose<rulelevel[RULE.DOWNGRADE],"chessrule.checklevel RULE.DOWNGRADE ")
			playerrule[RULE.DOWNGRADE-1] = rulelevel[RULE.DOWNGRADE] - lose
		else
			playerrule[RULE.DOWNGRADE-1] = 0
		end

		if rulelevel[RULE.UPGRADE_T] > 0 then  --升2级
			assert(win<rulelevel[RULE.UPGRADE_T],"chessrule.checklevel RULE.UPGRADE_T ")
			playerrule[RULE.UPGRADE_T-1] = rulelevel[RULE.UPGRADE_T] - win
		else
			playerrule[RULE.UPGRADE_T-1] = 0
		end

		if rulelevel[RULE.UPGRADE] > 0 then  --升2级
			assert(win<rulelevel[RULE.UPGRADE],"chessrule.checklevel RULE.UPGRADE ")
			playerrule[RULE.UPGRADE-1] = rulelevel[RULE.UPGRADE] - win
		else
			playerrule[RULE.UPGRADE-1] = 0
		end
		 
	end
	return playerrule
end

return chessrule