window.onload = ->
	window.statusAlert = (message) ->
		messageBox = document.getElementById "status"
		messageBox.textContent = message
		messageBox.style.opacity = "1"
		setTimeout ->
			document.getElementById("status").style.opacity = "0"
		, 2000
		return
	host = window.location.host
	window.SOCKET = new WebSocket "ws://#{host}"
	window.SOCKET.onopen = ->
		console.log "Connection has been made to the WS server"
		messageBox = document.getElementById "status"
		messageBox.textContent = "Connected"
		setTimeout ->
			messageBox.style.opacity = "0"
		, 500
	window.SOCKET.onmessage = (message) ->
		try
			message = JSON.parse message.data
		catch e
			return console.warn "The server sent invalid JSON"