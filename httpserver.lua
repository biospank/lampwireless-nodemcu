redLedTick = tmr.create()
relayTick = tmr.create()

-- PWM
curDuty = 0 -- low brightness
direction = 1 -- increasing, because we are starting at low

function fadeLED()
  if curDuty >= 1023 then
     direction = 0
  elseif curDuty <= 10 then
     direction = 1
  end

  if direction == 0 then
     curDuty = curDuty - 1
  elseif direction == 1 then
     curDuty = curDuty + 1
  else
     --should never be reached!
     curDuty = 0
  end
  pwm.setduty(redLedPin, curDuty)
end

function turnAlertOn()
  running, mode = redLedTick:state()

  if not running then
    redLedTick:alarm(1, tmr.ALARM_AUTO, fadeLED)
  end
end

function turnAlertOff()
  running, mode = redLedTick:state()

  if running then
    redLedTick:stop()
    pwm.setduty(redLedPin, 0)
    curDuty = 0
    direction = 1
  end
end

function turnRelayOn(vars, alert)
  print("Turning on gpio 2..")

  local params = collectQueryStringParams(vars)
  local times = tonumber((params.delay) or 5000) * 2 / 1000
  local ledState = gpio.LOW
  local running, mode = relayTick:state()
  local cnt = 0

  if not running then
    relayTick:alarm(500, tmr.ALARM_AUTO, function()
      cnt = cnt + 1

      if cnt < times then
        if ledState == gpio.LOW then
          ledState = gpio.HIGH
        else
          ledState = gpio.LOW
        end

        gpio.write(relayPin, ledState)
      else
        print("Turning off gpio 2..")
        relayTick:stop()
        gpio.write(relayPin, gpio.LOW)

        print("alert " .. tostring(alert))

        if alert then
          turnAlertOn()
        end
      end
    end)
  end
end

function collectQueryStringParams(vars)
  local _GET = {}
  if (vars ~= nil) then
    for k, v in string.gmatch(vars, "(%w+)=(%w+)&*") do
      _GET[k] = v
    end
  end

  return _GET
end

srv=net.createServer(net.TCP)
srv:listen(80, function(conn)
  local method=""
  local url=""
  local vars=""

  conn:on("receive", function(conn, payload)
    _, _, method, url, vars = string.find(payload, "([A-Z]+) /([^?]*)%??(.*) HTTP")

    if(url ~= nil) then
      print("url: " .. url)
    end

    if(vars ~= nil) then
      print("vars: " .. vars)
    end

    if url == "favicon.ico" then
      conn:send("HTTP/1.1 404 file not found")
      return
    end

    if url == "test" then
      turnRelayOn(vars, false)
    end

    if url == "notify" then
      turnRelayOn(vars, true)
    end

    if url == "alertoff" then
      turnAlertOff()
    end

    conn:send("HTTP/1.1 200 OK\r\n\r\n")
  end)

  conn:on("sent", function(conn)
    -- conn:send("<!DOCTYPE html><html>ok</html>")
    conn:send("ok")
    conn:close()
    collectgarbage();
  end)
end)
