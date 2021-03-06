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

	SidebarLoaded = ->
		console.log "Hi"
		files = document.querySelectorAll(".files-item")
		for file in files
			file.onclick = ->
				document.querySelector(".selected").className = "files-item"
				@.className = "files-item selected"
				LoadFile()
	SidebarLoaded()
	LoadFile = ->
		# Load the selected file
		file = document.querySelector ".files-item.selected"
		unless file
			document.getElementById("info").style.display = "none"
			return
		path = file.attributes["data-path"].value
		toSend =
			"Action": "info"
			"File": path
		toSend = JSON.stringify toSend
		window.SOCKET.send toSend
	document.getElementById("delete").onclick = ->
		fileName = document.querySelector("#info .file").textContent
		areSure = confirm "Are you sure you want to delete \"#{fileName}\"?"
		return unless areSure
		file = document.querySelector ".files-item.selected"
		path = file.attributes["data-path"].value
		toSend =
			"Action": "delete"
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
				# LoadFile() response from server
				fileInfo = message.Info
				return unless fileInfo.File
				###
				"File": yes
				"Size": readableSize stats.size
				"RawSize": stats.size
				"Path": path.basename file
				"FullPath": path.normalize file
				"MimeType": mime.lookup file
				"Time":
					"Accessed": buildDate stats.atime
					"Modified": buildDate stats.mtime
				###
				infoPane = document.getElementById "info"
				infoPane.style.display = "block"

				title = infoPane.querySelector ".file"
				title.textContent = fileInfo.Path
				title.title = fileInfo.FullPath
				title.onclick = ->
					newTitle = window.prompt "New document title:", title.textContent
					return unless newTitle
					newTitle.trim()
					toSend =
						"Action": "rename"
						"File": fileInfo.FullPath
						"NewFile": newTitle
					toSend = JSON.stringify toSend
					window.SOCKET.send toSend
				mainInfo = infoPane.querySelector ".main-info"
				mainInfo.textContent = "#{fileInfo.Size} · #{fileInfo.MimeType}"
				dates = infoPane.querySelector ".dates"
				dates.textContent = fileInfo.Time.Modified
			when "rename"
				if message.Success
					toSend =
						"Action": "sidebar"
						"Directory": document.querySelector(".title").textContent
					toSend = JSON.stringify toSend
					window.SOCKET.send toSend
				else
					# Rename failed
					console.warn message.Error
			when "sidebar"
				sidebar = document.querySelector "#list"
				sidebar.innerHTML = message.Data
				SidebarLoaded()
				LoadFile()
			when "delete"
				if message.Success
					toSend =
						"Action": "sidebar"
						"Directory": document.querySelector(".title").textContent
					toSend = JSON.stringify toSend
					window.SOCKET.send toSend
				else
					# Rename failed
					console.warn message.Error
			else
				console.warn "Server responded with unknown response of type '#{message.Response}'"

	window.SOCKET.onclose = ->
		console.error "The server closed the connection, this may mean that authentication failed"