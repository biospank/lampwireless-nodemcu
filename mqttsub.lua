-- mqttsub.lua
local mqttBroker = nil
local mqttBrokerClientId = node.chipid()
local mqttBrokerHost = "192.168.1.23"
local mqttBrokerPort = 1883
local mqttBrokerUsr = "lampwireless"
local mqttBrokerPwd = "biospank9571"

local function mqttBrokerConfTopic()
  return "lampwireless/" .. lampServerChipId .. "/client/" .. mqttBrokerClientId .. "/conf"
end

local function mqttBrokerStatusTopic()
  return "lampwireless/" .. lampServerChipId .. "/client/" .. mqttBrokerClientId .. "/status"
end

local function offlineMessage()
  return {["clientId"] = mqttBrokerClientId, ["status"] = "offline"}
end

local function onlineMessage()
  return {["clientId"] = mqttBrokerClientId, ["status"] = "online"}
end

local function setOnlineStatus()
  bootLedTick:stop()
  pwm.setduty(rRgbLedPin, 1023)
  pwm.setduty(gRgbLedPin, 1023)
  pwm.setduty(bRgbLedPin, 1023)
  gpio.write(greenLedPin, gpio.HIGH)
end

local function conn()
  print("Connecting to broker " .. mqttBrokerHost .. "...")
  -- Set up last will testament
  mqttBroker:lwt(mqttBrokerStatusTopic(), sjson.encode(offlineMessage()), 1, 1)
  -- Connect to broker
  mqttBroker:connect(mqttBrokerHost, mqttBrokerPort, false, function(client)
    print("Publishing online message to topic: " .. mqttBrokerStatusTopic() .. "...")
    client:publish(mqttBrokerStatusTopic(), sjson.encode(onlineMessage()), 1, 0, function(client)
      print("Subscribing to topic " .. mqttBrokerConfTopic() .. "...")
      -- subscribe topic with qos = 0
      client:subscribe(mqttBrokerConfTopic(), 0, function(client)
        setOnlineStatus()
        dofile("pir.lc")
      end)
    end)
  end,
  function(client, reason)
    print("Failed to connect: " .. reason)
    setOnlineStatus()
    dofile("pir.lc")
  end)
end

local lampChipRequestAttempts = 1

local function getLampChipId()
  print("Retrieve lamp server chip id...")
  print("http://"..lampServerIp..":"..lampServerPort.."/hardware/chipid")

  http.get("http://"..lampServerIp..":"..lampServerPort.."/hardware/chipid", nil, function(code, data)
    if (code < 0) then
      print("HTTP request failed")
      if (lampChipRequestAttempts > 3) then
        setOnlineStatus()
        dofile("pir.lc")
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
  print("Disconnected, reconnecting....")
  conn()
end

local function onMsg(_client, topic, data)
  print(topic .. ":" )
  if data ~= nil then
    print(data)

    clientConf = sjson.decode(data)

    -- for k,v in pairs(clientConf) do
    --   print(k, v)
    -- end
  end
end

local function makeConn()
  mqttBroker = mqtt.Client(mqttBrokerClientId, 20, mqttBrokerUsr, mqttBrokerPwd)
  -- Set up the event callbacks
  print("Setting up callbacks")
  -- mqttBroker:on("connect", function(client) print ("connected") end)
  mqttBroker:on("offline", reconn)
  -- on publish message receive event
  mqttBroker:on("message", onMsg)
  getLampChipId()
  -- Connect to the Broker
  -- conn()
end

makeConn()
