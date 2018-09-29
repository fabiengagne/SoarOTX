-- JF F3RES Timing and score keeping, loadable part
-- Timestamp: 2018-09-14
-- Created by Jesper Frickmann
-- Telemetry script for timing and keeping scores for F3RES.

local wt
local ft
local Draw -- Draw() function is defined for specific transmitter

-- Transmitter specific
if tx == TX_X9D then
	function Draw()
		local blnkWt = 0
		local blnkFt = 0
		local txtFt = "Remain"
		
		local fmNbr, fmName = getFlightMode()
		DrawMenu(" " .. fmName .. " ")	

		if skLocals.state == skLocals.STATE_SETWINTMR then
			blnkWt = BLINK + INVERS
		elseif skLocals.state == skLocals.STATE_SETFLTTMR then
			blnkFt = BLINK + INVERS
		end
		
		if skLocals.state <= skLocals.STATE_SETFLTTMR then
			txtFt = "Target"
		elseif skLocals.state > skLocals.STATE_WINDOW then
			txtFt = "Flight"
		end
		
		lcd.drawText(58, 57, " JF F3RES Score Keeper ", SMLSIZE)
		lcd.drawText(10, 20, "Landing", MIDSIZE)

		lcd.drawText(110, 20, "Window", MIDSIZE)
		lcd.drawTimer(162, 16, wt.value, DBLSIZE + blnkWt)

		lcd.drawText(110, 42, txtFt, MIDSIZE)
		lcd.drawTimer(162, 38, ft.value, DBLSIZE + blnkFt)

		if skLocals.state < skLocals.STATE_LANDINGPTS then
			lcd.drawText(93, 16, "--", DBLSIZE + RIGHT)
		elseif skLocals.state == skLocals.STATE_LANDINGPTS then
			lcd.drawNumber(93, 16, skLocals.landingPts, DBLSIZE + RIGHT + BLINK + INVERS)
		else
			lcd.drawNumber(93, 16, skLocals.landingPts, DBLSIZE + RIGHT)
		end
	end  --  Draw()
else -- QX7 or X-lite
	function Draw()
		local blnkWt = 0
		local blnkFt = 0
		local txtFt = "Rem"
		
		local fmNbr, fmName = getFlightMode()
		DrawMenu(fmName)	

		if skLocals.state == skLocals.STATE_SETWINTMR then
			blnkWt = BLINK + INVERS
		elseif skLocals.state == skLocals.STATE_SETFLTTMR then
			blnkFt = BLINK + INVERS
		end
		
		if skLocals.state <= skLocals.STATE_SETFLTTMR then
			txtFt = "Tgt"
		elseif skLocals.state > skLocals.STATE_WINDOW then
			txtFt = "Flt"
		end
		
		lcd.drawText(44, 58, " JF F3RES ", SMLSIZE)
		lcd.drawText(7, 20, "Landing ", SMLSIZE)

		lcd.drawText(68, 20, "Win", SMLSIZE)
		lcd.drawTimer(90, 16, wt.value, MIDSIZE + blnkWt)

		lcd.drawText(68, 42, txtFt, SMLSIZE)
		lcd.drawTimer(90, 38, ft.value, MIDSIZE + blnkFt)

		if skLocals.state < skLocals.STATE_LANDINGPTS then
			lcd.drawText(60, 16, "--", MIDSIZE + RIGHT)
		elseif skLocals.state == skLocals.STATE_LANDINGPTS then
			lcd.drawNumber(60, 16, skLocals.landingPts, MIDSIZE + RIGHT + BLINK + INVERS)
		else
			lcd.drawNumber(60, 16, skLocals.landingPts, MIDSIZE + RIGHT)
		end
	end -- Draw()
end

local function run(event)
	wt = model.getTimer(0)
	ft = model.getTimer(1)

	if skLocals.state == skLocals.STATE_SETWINTMR and event == EVT_ENTER_BREAK then
		skLocals.state = skLocals.STATE_SETFLTTMR
	end
	
	if (skLocals.state > skLocals.STATE_LANDINGPTS and wt.value > 0) or skLocals.state == skLocals.STATE_SETFLTTMR then
		if event == EVT_MENU_BREAK or event == EVT_UP_BREAK then
			-- Go back one step
			skLocals.state  = skLocals.state  - 1
		end
	end
	
	if skLocals.state <= skLocals.STATE_SETFLTTMR  then -- Set flight time before the flight
		local dt = 0
		local tgt
		
		if event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_PLUS_REPT or event == EVT_RIGHT_BREAK then
			dt = 60
		end
		
		if event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT or event == EVT_MINUS_REPT or event == EVT_LEFT_BREAK then
			dt = -60
		end
		
		if skLocals.state == skLocals.STATE_SETWINTMR then
			tgt = wt.start + dt
			if tgt < 60 then
				tgt = 5940
			elseif tgt > 5940 then
				tgt = 60
			end
			model.setTimer(0, {start = tgt, value = tgt})
		else
			tgt = ft.start + dt
			if tgt < 60 then
				tgt = 60
			elseif tgt > wt.start then
				tgt = wt.start
			end
			model.setTimer(1, {start = tgt, value = tgt})
		end
	elseif skLocals.state == skLocals.STATE_LANDINGPTS then -- Landed, input landing points 
		local dpts = 0
		
		if event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_PLUS_REPT or event == EVT_RIGHT_BREAK then
			if skLocals.landingPts >= 90 then
				dpts = 1
			elseif skLocals.landingPts >= 30 then
				dpts = 5
			else
				dpts = 30
			end
		end
		
		if event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT or event == EVT_MINUS_REPT or event == EVT_LEFT_BREAK then
			if skLocals.landingPts > 90 then
				dpts = -1
			elseif skLocals.landingPts > 30 then
				dpts = -5
			else
				dpts = -30
			end
		end
		
		skLocals.landingPts = skLocals.landingPts + dpts
		if skLocals.landingPts < 0 then
			skLocals.landingPts = 100
		elseif skLocals.landingPts  > 100 then
			skLocals.landingPts = 0
		end
		
		if event == EVT_ENTER_BREAK then
			skLocals.state = skLocals.STATE_SAVE
		end
	elseif skLocals.state == skLocals.STATE_SAVE then
		if event == EVT_ENTER_BREAK then -- Record scores if user pressed ENTER
			local logFile = io.open("/LOGS/JF F3RES Scores.csv", "a")
			if logFile then
				local nameStr = model.getInfo().name

				local now = getDateTime()
				local dateStr = string.format("%04d-%02d-%02d", now.year, now.mon, now.day)
				local timeStr = string.format("%02d:%02d", now.hour, now.min)

				io.write(logFile, string.format("%s,%s,%s,%s,", nameStr, dateStr, timeStr, skLocals.landingPts))
				io.write(logFile, string.format("%s,%s,%s,%s\n", wt.start, wt.value, ft.start, ft.value))

				io.close(logFile)
			end
			
			skLocals.state = skLocals.STATE_SETWINTMR
		end

		if event == EVT_EXIT_BREAK then -- Do not record scores if user pressed EXIT
			skLocals.state = skLocals.STATE_SETWINTMR
		end
	end
	
	Draw()

	if skLocals.state == skLocals.STATE_SAVE then
		lcd.drawText(4, LCD_H - 10, "EXIT", SMLSIZE + BLINK)
		lcd.drawText(LCD_W - 3, LCD_H - 10, "SAVE", SMLSIZE + BLINK + RIGHT)
	end
end  --  run()

return {run = run}	