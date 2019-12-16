-- wifisetup.lua

function activateWifiLed(active)
  if active then
    pwm.setduty(rRgbLedPin, 0)
    pwm.setduty(gRgbLedPin, 1023)
    pwm.setduty(bRgbLedPin, 1023)
  else
    pwm.setduty(rRgbLedPin, 1023)
    pwm.setduty(gRgbLedPin, 1023)
    pwm.setduty(bRgbLedPin, 1023)
  end
end

activateWifiLed(true)
bootLedTick:start()

enduser_setup.start(
  function()
    -- print("enduser_setup: Connection successful: " .. wifi.sta.getip())

    print("wifisetup mdn: ", node.heap())
    dofile("mdnclient.lc") -- start mdns discovery

  end,
  function(err, str)
    -- print("enduser_setup: Err #" .. err .. ": " .. str)
  end
);
