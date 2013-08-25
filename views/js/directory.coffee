host = window.location.host
window.SOCKET = new WebSocket "ws://#{host}"
window.SOCKET.onopen = ->
	console.log "Connection has been made to the WS server"
window.SOCKET.onmessage = (message) ->
	try
		message = JSON.parse message.data
	catch e
		return console.warn "The server sent invalid JSON"