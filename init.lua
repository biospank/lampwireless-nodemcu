-- enduser_setup,file,gpio,mdns,net,node,tmr,uart,wifi

--init.lua
redLedPin = 5
greenLedPin = 7
buttonPin = 3
relayPin = 6

gpio.mode(redLedPin, gpio.OUTPUT)
gpio.mode(greenLedPin, gpio.OUTPUT)
gpio.mode(buttonPin, gpio.INT, gpio.PULLUP)
gpio.mode(relayPin, gpio.OUTPUT)
gpio.write(redLedPin, gpio.LOW)

cnt = 0

-- define a callback function
function buttonCb()
  print("Resetting device...")
  wifi.sta.clearconfig()
  node.restart()
end

-- register a button event
-- that means, what's registered here is executed upon button event "up"
gpio.trig(buttonPin, "up", buttonCb)

print("Starting SmartRx...")
print("Connecting to wifi...")

local connTick = tmr.create()
local ledState = gpio.LOW

bootLedTick = tmr.create()

bootLedTick:alarm(500, tmr.ALARM_AUTO, function()
  if ledState == gpio.LOW then
    ledState = gpio.HIGH
  else
    ledState = gpio.LOW
  end

  gpio.write(greenLedPin, ledState)
end)

connTick:alarm(500, tmr.ALARM_AUTO, function()
  if wifi.sta.getip() == nil then
    cnt = cnt + 1
    print(cnt .. " attempt...") -- waiting for ip
    if cnt == 20 then
      connTick:stop()
      -- bootLedTick:stop()
      -- gpio.write(greenLedPin, gpio.HIGH)
      print("Entering wifi setup...")
      dofile("wifisetup.lua")
    end
  else
    connTick:stop()
    bootLedTick:stop()
    gpio.write(greenLedPin, gpio.LOW)
    print("Connected to wifi as: " .. wifi.sta.getip())
    dofile("mdnservice.lua") -- expose mdn service
    dofile("httpserver.lua") -- start http server
  end
end)
