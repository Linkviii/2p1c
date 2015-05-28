--author: TheOnlyOne

local socket = require("socket")
local sync = require("sync")

return function()
	--create the server
	local server = assert(socket.bind("*", config.port, 1))
	local ip, setport = server:getsockname()
	printOutput("Created server at " .. ip .. " on port " .. setport)

	--make sure we don't block waiting for a client_socket to accept
	server:settimeout(config.accept_timeout)
	--wait for the connection from the client
	printOutput("Awaiting connection.")
	emu.frameadvance()
	emu.frameadvance()
	local err
	client_socket, err = server:accept()

	--end execution if a client does not connect in time
	if (client_socket == nil) then
	  printOutput("Timed out waiting for client to connect.")
	  cleanConnection()
	  server:close()
	  return
	end

	--display the client's information
	local peername, peerport = client_socket:getpeername()
	printOutput("Connected to " .. peername .. " on port " .. peerport)
	emu.frameadvance()
	emu.frameadvance()

	-- make sure we don't block forever waiting for input
	client_socket:settimeout(config.input_timeout)

	--when the script finishes, make sure to close the connection
	local function close_connection()
	  client_socket:close()
	  server:close()
	  printOutput("Connection closed.")
	  cleanConnection()
	end

	event.onexit(function () close_connection(); forms.destroy(form1) end)

	--furthermore, override error with a function that closes the connection
	--before the error is actually thrown
	local old_error = error

	error = function(message, level)
	  close_connection()
	  printOutput(message)
	  --old_error(message, 0)
	end

	--sync the gameplay
	sync.initialize()
	sync.syncconfig(client_socket, 1)
	sync.synctoframe1(client_socket)
	sync.resetsync()
	
	syncStatus = "Play"
	return 
end