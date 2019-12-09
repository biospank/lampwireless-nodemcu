-- mqttsub.lua

local mqttConf = dofile("broker.lc")

local pirTick = tmr.create()
local isMqttAlive = false
local mqttBroker = nil
local deviceId = node.chipid()
local lampChipRequestAttempts = 1
local mqttConnectAttempts = 1

local function mqttBrokerBaseTopic()
  return "lampwireless/" .. lampServerChipId .. "/device/" .. deviceId
end

local function mqttBrokerConfTopic()
  return mqttBrokerBaseTopic() .. "/conf"
end

local function mqttBrokerStatusTopic()
  return mqttBrokerBaseTopic() .. "/status"
end

local function mqttBrokerMessageTopic()
  return mqttBrokerBaseTopic() .. "/message"
end

local function offlineMessage()
  return {["id"] = deviceId, ["serverId"] = lampServerChipId, ["type"] = deviceType, ["status"] = "offline"}
end

local function onlineMessage()
  return {["id"] = deviceId, ["serverId"] = lampServerChipId, ["type"] = deviceType, ["status"] = "online"}
end

local function alertMessage()
  return {["mode"] = (deviceConf.mode or "alarm"), ["client"] = (deviceConf.client or "pir"), ["delay"] = (deviceConf.delay or "5000"), ["alert"] = (deviceConf.alert or "false"), ["r"] = (deviceConf.r or ""), ["g"] = (deviceConf.g or ""), ["b"] = (deviceConf.b or "")}
end

local function setOnlineStatus()
  bootLedTick:stop()
  pwm.setduty(rRgbLedPin, 1023)
  pwm.setduty(gRgbLedPin, 1023)
  pwm.setduty(bRgbLedPin, 1023)
  gpio.write(greenLedPin, gpio.HIGH)
end

local function sendMessage()
  if ((deviceConf.active or "true") == "true") then
    if isMqttAlive == true then
      print("Publishing mqtt message...")
      mqttBroker:publish(mqttBrokerMessageTopic(), sjson.encode(alertMessage()), 1, 1)
    end

    print("Sending http request...")

    local url = "http://"..lampServerIp..":"..lampServerPort.."/notify?mode="..(deviceConf.mode or "alarm").."&client="..(deviceConf.client or "pir").."&delay="..(deviceConf.delay or "5000").."&alert="..(deviceConf.alert or "false").."&r="..(deviceConf.r or "").."&g="..(deviceConf.g or "").."&b="..(deviceConf.b or "")

    print(url)

    http.get(url, nil, function(code, data)
      if (code < 0) then
        print("HTTP request failed")
      else
        print(code, data)
        print("http request sent!")
      end
    end)
  end
end


function listen()
  local bouncingTime = 0

  pirTick:stop()

  pirTick:alarm(500, tmr.ALARM_AUTO, function()
    if gpio.read(PIRpin) == 1 then
      -- print("move detected!")
      -- print(bouncingTime)
      if bouncingTime == 0 then
        bouncingTime = bouncingTime + 1
        sendMessage()
      end
    else
      -- print("no movement...")
      -- print(bouncingTime)
      if bouncingTime > 0 then
        bouncingTime = bouncingTime + 1
      end

      if bouncingTime > 5 then
        bouncingTime = 0
      end
    end
  end)
end

local function conn()
  print("Connecting to broker " .. mqttConf.brokerHost .. ":" .. tostring(mqttConf.brokerPort) .. " with usr: " .. mqttConf.brokerUsr .. " pwd: " .. mqttConf.brokerPwd .. "...")
  -- Set up last will testament
  mqttBroker:lwt(mqttBrokerStatusTopic(), sjson.encode(offlineMessage()), 1, 1)
  -- Connect to broker
  mqttBroker:connect(mqttConf.brokerHost, mqttConf.brokerPort, false, function(client)
    isMqttAlive = true
    mqttConnectAttempts = 1

    print("Publishing online message to topic: " .. mqttBrokerStatusTopic() .. "...")
    client:publish(mqttBrokerStatusTopic(), sjson.encode(onlineMessage()), 1, 1)

    print("Subscribing to topic " .. mqttBrokerConfTopic() .. "...")
    -- subscribe topic with qos = 0
    client:subscribe(mqttBrokerConfTopic(), 0)

    setOnlineStatus()
    listen()

  end,
  function(client, reason)
    print("Failed to connect: " .. reason)
    isMqttAlive = false

    if (mqttConnectAttempts > 3) then
      print("Max connection attempts reached, giving up...")
      mqttConnectAttempts = 1
      setOnlineStatus()
      listen()
    else
      mqttConnectAttempts = mqttConnectAttempts + 1

      print("Attempt to connect in 3 sec...")
      -- tmr.delay(2000)
      tmr.create():alarm(3000, tmr.ALARM_SINGLE, function()
        conn()
      end)
    end
  end)
end

local function getLampChipId()
  print("Retrieve lamp server chip id...")
  print("http://"..lampServerIp..":"..lampServerPort.."/hardware/chipid")

  http.get("http://"..lampServerIp..":"..lampServerPort.."/hardware/chipid", nil, function(code, data)
    if (code < 0) then
      print("HTTP request failed")
      if (lampChipRequestAttempts > 3) then
        setOnlineStatus()
        listen()
      else
        lampChipRequestAttempts = lampChipRequestAttempts + 1
        getLampChipId()
      end
    else
      print("Lamp chip id: " .. data)
      lampServerChipId = data
      conn()
    end
  end)
end

-- Reconnect to MQTT when we receive an "offline" message.
local function reconn()
  print("Disconnected!")
  isMqttAlive = false

  print("Attempt to reconnect in 3 sec...")
  -- tmr.delay(2000)
  tmr.create():alarm(3000, tmr.ALARM_SINGLE, function()
    conn()
  end)
end

local function onMsg(_client, topic, data)
  print(topic .. ":" )
  if data ~= nil then
    print(data)

    deviceConf = sjson.decode(data)

    -- for k,v in pairs(deviceConf) do
    --   print(k, v)
    -- end
  end
end

local function makeConn()
  collectgarbage()

  mqttBroker = mqtt.Client(deviceId, mqttConf.brokerKeepAlive, mqttConf.brokerUsr, mqttConf.brokerPwd)
  -- Set up the event callbacks
  print("Setting up callbacks")
  -- mqttBroker:on("connect", function(device) print ("connected") end)
  mqttBroker:on("offline", reconn)
  -- on publish message receive event
  mqttBroker:on("message", onMsg)
  getLampChipId()
  -- Connect to the Broker
  -- conn()
end

makeConn()
