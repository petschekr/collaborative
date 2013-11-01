window.onload = ->
	AUTHED = no
	# Functions
	window.cookieParser = (cookieName = "id") ->
		regex = new RegExp cookieName + "=([^;]*)", "g"
		result = regex.exec document.cookie
		return (
			try
				result[1]
			catch
				undefined
		)
	window.statusAlert = (message) ->
		messageBox = document.getElementById "status"
		messageBox.textContent = message
		messageBox.style.opacity = "1"
		setTimeout ->
			document.getElementById("status").style.opacity = "0"
		, 2000
		return

	LoadFile = ->
		# Load the selected file
		file = document.querySelector ".files-item.selected"
		path = file.attributes["data-path"].value
		toSend =
			"Action": "info"
			"File": path
		toSend = JSON.stringify toSend
		window.SOCKET.send toSend

	host = window.location.host
	window.SOCKET = new WebSocket "ws://#{host}"
	window.SOCKET.onopen = ->
		console.log "Connection has been made to the WS server"
		messageBox = document.getElementById "status"
		messageBox.textContent = "Connected"
		setTimeout ->
			messageBox.style.opacity = "0"
		, 500
		# Send auth message
		toSend =
			"Action": "auth"
			"ID": cookieParser()
		toSend = JSON.stringify toSend
		window.SOCKET.send toSend
	window.SOCKET.onmessage = (message) ->
		try
			message = JSON.parse message.data
		catch e
			return console.warn "The server sent invalid JSON"
		if not AUTHED and message.Response is "auth" and message.Authed is true
			AUTHED = yes
			LoadFile()
			return

		switch message.Response
			when "info"
				undefined
			else
				console.warn "Server responded with unknown response of type '#{message.Response}'"

	window.SOCKET.onclose = ->
		console.error "The server closed the connection, this may mean that authentication failed"