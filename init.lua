-- enduser_setup,file,gpio,mdns,net,node,tmr,uart,wifi,pwm,WPS,HTTP

--init.lua
rRgbLedPin = 5
gRgbLedPin = 1
bRgbLedPin = 2
greenLedPin = 7
buttonPin = 6
PIRpin = 3

lampServerIp = nil
lampServerPort = nil

gpio.mode(greenLedPin, gpio.OUTPUT)
gpio.mode(PIRpin, gpio.INPUT)
gpio.mode(buttonPin, gpio.INT, gpio.PULLUP)

pwm.setup(rRgbLedPin, 1000, 1023) -- we are using 1000Hz
pwm.setup(gRgbLedPin, 1000, 1023) -- we are using 1000Hz
pwm.setup(bRgbLedPin, 1000, 1023) -- we are using 1000Hz
pwm.start(rRgbLedPin)
pwm.start(gRgbLedPin)
pwm.start(bRgbLedPin)

-- define a callback function
function buttonCb()
  print("Resetting device...")
  wifi.sta.clearconfig()
  node.restart()
end

-- register a button event
-- that means, what's registered here is executed upon button event "up"
gpio.trig(buttonPin, "up", buttonCb)

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

local cnt = 0

connTick:alarm(500, tmr.ALARM_AUTO, function()
  if wifi.sta.getip() == nil then
    cnt = cnt + 1
    print(cnt .. " attempt...") -- waiting for ip
    if cnt == 20 then
      connTick:stop()
      print("Entering wps setup...")
      dofile("wpssetup.lua")
    end
  else
    connTick:stop()
    print("Connected to wifi as: " .. wifi.sta.getip())
    dofile("mdnclient.lua") -- start mdns discovery
  end
end)
