-- wpssetup.lua

local wpsConnTick = tmr.create()

function activateWpsLed(active)
  if active then
    pwm.setduty(rRgbLedPin, 1023)
    pwm.setduty(gRgbLedPin, 1023)
    pwm.setduty(bRgbLedPin, 0)
  else
    pwm.setduty(rRgbLedPin, 1023)
    pwm.setduty(gRgbLedPin, 1023)
    pwm.setduty(bRgbLedPin, 1023)
  end
end

wifi.setmode(wifi.STATION)
bootLedTick:stop()
activateWpsLed(true)
wps.enable()

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
          wpsConnTick:unregister()

          -- print("WPS: Entering wifi setup...")
          print("wpssetup wifi: ", node.heap())
          dofile("wifisetup.lc")

        end
      else
        -- print("WPS: Connection successful: " .. wifi.sta.getip())
        wpsConnTick:stop()
        wpsConnTick:unregister()

        gpio.write(greenLedPin, gpio.LOW)

        print("wpssetup mdn: ", node.heap())
        dofile("mdnclient.lc") -- start mdns discovery

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

  -- print("WPS: Entering wifi setup...")
  dofile("wifisetup.lc")
end)
