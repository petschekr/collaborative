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
		# Load the file into the editor
		toSend =
			"Action": "load"
			"File": window.FileName
		toSend = JSON.stringify toSend
		window.SOCKET.send toSend

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
			when "load"
				loadFile message
			else
				console.warn "Server responded with unknown response of type '#{message.Response}'"

	window.SOCKET.onclose = ->
		console.error "The server closed the connection, this may mean that authentication failed"

	# CodeMirror
	window.FileName = document.getElementById("filename").textContent
	window.MimeType = document.getElementById("mime").textContent
	window.Editor = CodeMirror document.body, {
		mode: window.MimeType
		indentUnit: 4
		indentWithTabs: on
		lineWrapping: on
		autofocus: on
		lineNumbers: on
		theme: "solarized dark"
		# Add ons
		styleActiveLine: on
		matchBrackets: on
		autoCloseBrackets: on
		matchTags: on
		autoCloseTags: on
	}
	window.Editor.on "change", (CodeMirrorInstance, change) ->
		console.log change
		#return if change.origin is undefined # Edit not made locally
		return if change.origin is "setValue" # Ignore file loading

		toSend = {}
		toSend.Action = "edit"
		toSend.File = window.FileName
		toSend.Info = {}
		toSend.Info.from = change.from
		toSend.Info.to = change.to
		toSend.Info.text = change.text.join "\n"
		toSend = JSON.stringify toSend
		window.SOCKET.send toSend
	# Begin loading the file
	loadFile = (message) ->
		if message.Info is "data"
			currentContent = window.Editor.getValue()
			currentContent += message.Chunk
			window.Editor.setValue currentContent
		else
			console.log "#{message.File} loaded successfully"

	panelButton = document.getElementById "back"
	panelButton.onclick = ->
		classes = panelButton.className.split " "
		if classes.length is 2
			# Closed
			document.querySelector(".CodeMirror").style.left = "250px";
			classes.push "forward"
			classes = classes.join " "
			panelButton.className = classes
		else
			# Open
			document.querySelector(".CodeMirror").style.left = "0";
			classes.pop()
			classes = classes.join " "
			panelButton.className = classes
	themeInput = document.getElementById "theme"
	themeInput.onchange = ->
		theme = themeInput.options[themeInput.selectedIndex].value
		window.Editor.setOption "theme", theme