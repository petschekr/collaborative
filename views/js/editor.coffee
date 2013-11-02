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
	LoadFile = ->
		# Load the file into the Ace editor
		undefined

	host = window.location.host
	window.SOCKET = new WebSocket "ws://#{host}"
	window.SOCKET.onopen = ->
		console.log "Connection has been made to the WS server"
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
			when "edit"
				undefined
			else
				console.warn "Server responded with unknown response of type '#{message.Response}'"

	window.SOCKET.onclose = ->
		console.error "The server closed the connection, this may mean that authentication failed"

	# Ace Editor
	window.Editor = ace.edit "editor"
	window.Editor.setTheme "ace/theme/monokai"
	window.Editor.getSession().setMode "ace/mode/javascript"