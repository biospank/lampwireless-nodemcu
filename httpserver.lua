rgbLedTick = tmr.create()
relayTick = tmr.create()
red, green, blue = nil

function turnAlertOn(params, temporary)
  local ledState = gpio.LOW
  local count = 0
  local running, mode = rgbLedTick:state()

  red = params.r
  green = params.g
  blue = params.b

  -- print("Red: " .. red)
  -- print("Green: " .. green)
  -- print("Blue: " .. blue)

  if not running then
    rgbLedTick:alarm(500, tmr.ALARM_AUTO, function()
      if temporary and count > 6 then
        turnAlertOff()
      end

      count = count + 1

      if ledState == gpio.LOW then
        ledState = gpio.HIGH
      else
        ledState = gpio.LOW
      end

      if ledState == gpio.HIGH then
        pwm.setduty(rRgbLedPin, 1023 - red)
        pwm.setduty(gRgbLedPin, 1023 - green)
        pwm.setduty(bRgbLedPin, 1023 - blue)
      else
        pwm.setduty(rRgbLedPin, 1023)
        pwm.setduty(gRgbLedPin, 1023)
        pwm.setduty(bRgbLedPin, 1023)
      end
    end)
  else
    if temporary then
      turnAlertOff()
    end
  end
end

function turnAlertOff()
  running, mode = rgbLedTick:state()

  if running then
    rgbLedTick:stop()
    pwm.setduty(rRgbLedPin, 1023)
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
          turnAlertOn(params, false)
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

    if url == "test" then
      turnRelayOn(vars, false)
    elseif url == "ping" then
    elseif url == "testalert" then
      turnAlertOn(collectQueryStringParams(vars), true)
    elseif url == "notify" then
      turnRelayOn(vars, true)
    elseif url == "alertoff" then
      turnAlertOff()
    else
      conn:send("HTTP/1.1 404 file not found")
      return
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
