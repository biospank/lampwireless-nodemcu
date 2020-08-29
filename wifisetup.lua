-- wifisetup.lua

function activateWifiLed(active)
  if active then
    ws2812.write(string.char(0, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    -- pwm.setduty(rRgbLedPin, 0)
    -- pwm.setduty(gRgbLedPin, 1023)
    -- pwm.setduty(bRgbLedPin, 1023)
  else
    ws2812.write(string.char(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    -- pwm.setduty(rRgbLedPin, 1023)
    -- pwm.setduty(gRgbLedPin, 1023)
    -- pwm.setduty(bRgbLedPin, 1023)
  end
end

activateWifiLed(true)
bootLedTick:start()

enduser_setup.start(
  function()
    print("enduser_setup: Connection successful: " .. wifi.sta.getip())
    ssid, pwd, _bssid = wifi.sta.getconfig(false)

    bootLedTick:stop()
    gpio.write(greenLedPin, gpio.LOW)
    activateWifiLed(false)

    print("enduser_setup: Restarting device...")
    tmr.create():alarm(3000, tmr.ALARM_SINGLE, function()
      wifi.setmode(wifi.STATION);
      wifi.sta.config({ssid = ssid, pwd = pwd, save = true});
      node.restart()
    end)
  end,
  function(err, str)
    print("enduser_setup: Err #" .. err .. ": " .. str)
  end,
  print -- Lua print function can serve as the debug callback
);
