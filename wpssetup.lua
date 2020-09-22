-- wpssetup.lua

local wpsConnTick = tmr.create()


local function activateWpsLed(active)
  if active then
    ws2812.write(string.char(0, 0, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
  else
    ws2812.write(string.char(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
  end
end

bootLedTick:stop()
gpio.write(greenLedPin, gpio.LOW)
wifi.setmode(wifi.STATION)
activateWpsLed(true)
wps.enable()

-- print("wpssetup start: ", node.heap())

wps.start(function(status)
  if status == wps.SUCCESS then
    wps.disable()
    -- print("WPS: Success, connecting to AP...")
    wifi.sta.connect()

    local cnt = 0

    wpsConnTick:alarm(500, tmr.ALARM_AUTO, function()

      if wifi.sta.getip() == nil then
        cnt = cnt + 1
        -- print("WPS: " .. cnt .. " attempt...") -- waiting for ip
        if cnt == 20 then
          wpsConnTick:stop()

          -- print("WPS: Entering wifi setup...")
          dofile("wifisetup.lc")

        end
      else
        -- print("WPS: Connection successful: " .. wifi.sta.getip())
        wpsConnTick:stop()
        -- ssid, pwd, _bssid_set, _bssid = wifi.sta.getconfig(false)
        local configs = wifi.sta.getconfig(true)

        fileSystem.dumpSettings("config.net", configs)

        bootLedTick:stop()
        gpio.write(greenLedPin, gpio.LOW)
        activateWpsLed(false)

        -- print("WPS: Restarting device...")
        tmr.create():alarm(3000, tmr.ALARM_SINGLE, function()
          wifi.setmode(wifi.STATION);
          wifi.sta.config({ssid = configs.ssid, pwd = configs.pwd, save = true});
          node.restart()
        end)

      end
    end)

    return
  elseif status == wps.FAILED then
    -- print("WPS: Failed")
  elseif status == wps.TIMEOUT then
    -- print("WPS: Timeout")
  elseif status == wps.WEP then
    -- print("WPS: WEP not supported")
  elseif status == wps.SCAN_ERR then
    -- print("WPS: AP not found")
  else
    -- print(status)
  end

  wps.disable()

  print("WPS: Entering wifi setup...")
  dofile("wifisetup.lc")
end)
