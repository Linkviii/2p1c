--This file implements the logic that syncs two player's inputs
--author: TheOnlyOne
local sync = {}



--load configurations
local config = require("config")

local require_status, modify_inputs, display_inputs
--attempt to load the desired input modifier. If it does not exist, load the
--default modifier
require_status, modify_inputs = pcall(function()
  return require(config.input_modifier)
end)
if not require_status then
  console.log("The input modifier specified in config.lua could not be found.")
  console.log("Loading the default input modifier instead.")
  config.input_modifier = "inputmodifier_none"
  modify_inputs = require("inputmodifier_none")
end
--attempt to load the desired input display. If it does not exist, load the
--default display
require_status, display_inputs = pcall(function()
  return require(config.input_display)
end)
if not require_status then
  console.log("The input diplay specified in config.lua could not be found.")
  console.log("Loading the default input diplay instead.")
  config.input_display = "inputdisplay_none"
  display_inputs = require("inputdisplay_none")
end

local messenger = require("messenger")
local savestate_sync = require("savestate_sync")



--makes sure that configurations are consistent between the two players
function sync.syncconfig(client_socket, default_player)
  console.log("Checking that configurations are consistent (this may take a few seconds...)")
  emu.frameadvance()
  emu.frameadvance()

  --construct a value representing the input modifier that is in use
  local sha1 = require("sha1")
  local modifier_text = ""
  for line in io.lines(config.input_modifier .. ".lua") do modifier_text = modifier_text .. line .. "\n" end
  local modifier_hash = sha1.sha1(modifier_text)

  --construct a value representing the sync code that is in use
  local sync_code = ""
  for line in io.lines("sync.lua") do sync_code = sync_code .. line .. "\n" end
  for line in io.lines("controller.lua") do sync_code = sync_code .. line .. "\n" end
  for line in io.lines("messenger.lua") do sync_code = sync_code .. line .. "\n" end
  for line in io.lines("pausing.lua") do sync_code = sync_code .. line .. "\n" end
  local sync_hash = sha1.sha1(sync_code)

  --send the configuration
  messenger.send(client_socket, messenger.CONFIG,
                 config.player, config.latency, modifier_hash, sync_hash)

  --receive their configuration
  local received_message_type, received_data = messenger.receive(client_socket)
  if (received_message_type ~= messenger.CONFIG) then
    error("Unexpected message type received.")
  end
  local their_player = received_data[1]
  local their_latency = received_data[2]
  local their_modifier_hash = received_data[3]
  local their_sync_hash = received_data[4]

  --check consistency of configurations

  --check players
  if (config.player == their_player) then
    console.log("Both players have choosen the same player number.")
    console.log("Setting you to player " .. default_player .. ".")
    config.player = default_player
  elseif (config.player < 1 or config.player > 2) then
    console.log("Your player number is not 1 or 2.")
    console.log("Setting you to player " .. default_player .. ".")
    config.player = default_player
  elseif (their_player < 1 or their_player > 2) then
    console.log("Their player number is not 1 or 2.")
    console.log("Setting you to player " .. default_player .. ".")
    config.player = default_player
  end

  --check latency
  if (config.latency ~= their_latency) then
    console.log("Your latencies do not match!")
    config.latency = math.max(config.latency, their_latency)
    console.log("Setting latency to " .. config.latency .. ".")
  end

  --check input modifiers
  if (modifier_hash ~= their_modifier_hash) then
    console.log("You are not both using the same input modifier.")
    console.log("Make sure your input modifiers are the same and try again.")
    error("Configuration consistency check failed.")
  end

  --check sync code
  if (sync_hash ~= their_sync_hash) then
    console.log("You are not both using the same sync code (perhaps one of you is using an older version?)")
    console.log("Make sure your sync code is the same and try again.")
    error("Configuration consistency check failed.")
  end
end



--loads slot 0, this should be a savestate at frame 0
--such a savestate can be generated by running saveframe0.lua
function sync.synctoframe1(client_socket)
  local status, err = savestate_sync.is_safe_to_loadslot(client_socket, 0)
  if (not status) then
    error(err .. "\nFailed to sync.")
  end
  savestate.loadslot(0)
  console.log("Synced! Let the games begin!")
  emu.frameadvance()
end



--shares the input between two players, making sure that the same input is
--pressed for both players on every frame
function sync.syncallinput(client_socket)

  local controller = require("controller")
  local keymap = require(controller.keymapfilename)
  local pausing = require("pausing")

  local current_frame, future_frame
  local modifier_is_in_effect = true
  local should_break = false

  while 1 do
    current_frame = emu.framecount()
    future_frame = current_frame + config.latency

    --create input queues
    local my_input_queue = {}
    local their_input_queue = {}
    local modifier_state_queue = {}
    local save_queue = {}

    --set the first latency frames to no input
    for i = current_frame, (future_frame - 1) do
      my_input_queue[i] = {}
      their_input_queue[i] = {}
    end

    local current_input, received_input
    local received_message_type, received_data
    local received_frame
    local my_input, their_input, final_input
    local pause_type, unpause_type, unpause_data

    while 1 do
      current_frame = emu.framecount()
      future_frame = current_frame + config.latency

      --get the player input
      current_input = controller.get(keymap)

      --pause if pause was pressed
      if (current_input["PAUSE"] == true) then
        --request the other player to pause
        messenger.send(client_socket, messenger.PAUSE, "request")
        --read input until the request is accepted
        received_message_type = -1
        while 1 do
          received_message_type, received_data = messenger.receive(client_socket)
          if (received_message_type == messenger.INPUT) then
            --we received input
            received_input = received_data[1]
            received_frame = received_data[2]

            --add the input to the queue
            their_input_queue[received_frame] = received_input
          elseif (received_message_type == messenger.PAUSE) then
            if (received_data[1] == "accept") then
              break
            else
              error("The other player did not properly accept the pause.")
            end
          else
            error("Unexpected message type received.")
          end
        end
        --pause the game, and properly deal with the output of the menu
        unpause_type, unpause_data = pausing.pausemenu(client_socket, future_frame)
        if (unpause_type == messenger.UNPAUSE) then
          console.log("Unpaused.")
        elseif (unpause_type == messenger.QUIT) then
          console.log("Quit.")
          return
        elseif (unpause_type == messenger.MODIFIER) then
          modifier_state_queue[unpause_data[2]] = unpause_data[1]
          if (unpause_data[1]) then
            console.log("Input modifier is ON.")
          else
            console.log("Input modifier is OFF.")
          end
        elseif (unpause_type == messenger.LOAD) then
          local slot = unpause_data[1]
          --check if the state can be loaded
          local status, err = savestate_sync.is_safe_to_loadslot(client_socket, slot)
          if (not status) then
            --if not, continue on normally
            console.log(err)
            console.log("Did not load slot " .. slot .. ".")
          else
            --if so, load the state, and reset necessary variables
            savestate.loadslot(slot)
            console.log("Savestate slot " .. slot .. " loaded.")
            break
          end
        elseif (unpause_type == messenger.SAVE) then
          save_queue[unpause_data[2]] = unpause_data[1]
        else
          error("Unexpected message type received.")
        end
        current_input["PAUSE"] = nil
      end

      --add input to the queue
      my_input_queue[future_frame] = current_input

      --send the input to the other player
      messenger.send(client_socket, messenger.INPUT, current_input, future_frame)

      --receive this frame's input from the other player
      while (their_input_queue[current_frame] == nil) do
        received_message_type, received_data = messenger.receive(client_socket)
        if (received_message_type == messenger.INPUT) then
          --we received input
          received_input = received_data[1]
          received_frame = received_data[2]

          --add the input to the queue
          their_input_queue[received_frame] = received_input
        elseif (received_message_type == messenger.PAUSE) then
          pause_type = received_data[1]
          if (pause_type == "request") then
            --the other player pressed pause, aknowledge, and pause
            messenger.send(client_socket, messenger.PAUSE, "accept")
            unpause_type, unpause_data = pausing.pausewait(client_socket)
          else
            console.log("Something weird happened, but it should be okay.")
          end
          if (unpause_type == messenger.UNPAUSE) then
            console.log("Unpaused.")
          elseif (unpause_type == messenger.QUIT) then
            console.log("The other player quit.")
            return
          elseif (unpause_type == messenger.MODIFIER) then
            modifier_state_queue[unpause_data[2]] = unpause_data[1]
            if (unpause_data[1]) then
              console.log("Input modifier is ON.")
            else
              console.log("Input modifier is OFF.")
            end
          elseif (unpause_type == messenger.LOAD) then
            local slot = unpause_data[1]
            --check if the state can be loaded
            local status, err = savestate_sync.is_safe_to_loadslot(client_socket, slot)
            if (not status) then
              --if not, continue on normally
              console.log(err)
              console.log("Did not load slot " .. slot .. ".")
            else
              --if so, load the state, and reset necessary variables
              savestate.loadslot(slot)
              console.log("Savestate slot " .. slot .. " loaded.")
              should_break = true
              break
            end
          elseif (unpause_type == messenger.SAVE) then
            save_queue[unpause_data[2]] = unpause_data[1]
          else
            error("Unexpected message type received.")
          end
        else
          error("Unexpected message type received.")
        end
      end

      if (should_break) then
        should_break = false
        break
      end

      --construct the input for the next frame
      final_input = {}
      my_input = my_input_queue[current_frame]
      their_input = their_input_queue[current_frame]

      --switch effect of modifier if necessary
      if (modifier_state_queue[current_frame] ~= nil) then
        modifier_is_in_effect = modifier_state_queue[current_frame]
      end

      if (modifier_is_in_effect) then
        my_input, their_input = modify_inputs(my_input, their_input, config.player)
      end

      display_inputs(my_input, their_input, config.player)

      for i, b in pairs(controller.buttons) do
        if (my_input[b] == true or their_input[b] == true) then
          final_input[b] = true
        else
          final_input[b] = false
        end
      end

      --set the input
      joypad.set(final_input)

      --clear these entries to keep the queue size from growing
      my_input_queue[current_frame] = nil
      their_input_queue[current_frame] = nil

      --make a save state if requested
      if (save_queue[current_frame] ~= nil) then
        savestate.saveslot(save_queue[current_frame])
        console.log("Saved state to slot " .. save_queue[current_frame] .. ".")
      end

      emu.frameadvance()

      --clear all input so that actual inputs do not interfere
      joypad.set(controller.unset)
    end
  end
end

return sync