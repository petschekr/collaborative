http = require "http"
fs = require "fs"
crypto = require "crypto"
path = require "path"
commander = require "commander"
sugar = require "sugar"
mime = require "mime"

USERDIR = process.env.HOME or process.env.HOMEPATH or process.env.USERPROFILE
USERDIR = path.normalize(USERDIR);
# Command line arguments
commander.version "0.0.1"
commander.option "-p, --port <n>", "The port for the server to listen on", parseInt
commander.option "-d, --directory <path>", "The uppermost accessible directory"
commander.option "-c, --credentials <username:password>", "Make the server only accessible with a username and passoword"
commander.parse process.argv

PORT = if commander.port? then commander.port else 8080
if commander.directory and fs.existsSync(commander.directory)
	BASEPATH = commander.directory
else
	BASEPATH = USERDIR
BASEPATH += "/"
BASEPATH = path.normalize BASEPATH
# Credentials
CREDENTIALS = undefined
if commander.credentials
	creds = commander.credentials.split ":"
	if creds.length != 2
		throw new Error "The format for credentials is username:password"
	username = creds[0]
	password = creds[1]
	if username is "" or password is ""
		throw new Error "Username or password cannot be left blank"
	CREDENTIALS = {username, password}

createNonce = (cb, bytes = 32) ->
	crypto.randomBytes bytes, (err, buffer) ->
		cb buffer.toString "hex"
readableSize = (size) ->
	origSize = size
	unitSize = 1024
	unitIndex = 0
	units = ["bytes", "KB", "MB", "GB", "TB", "PB"]
	while size >= unitSize
		unitIndex++
		size /= unitSize
	if unitIndex >= units.length
		# Exceeded labels
		unitIndex = 0
		size = origSize
	if unitIndex is 0
		return Math.round(size).toString() + " " + units[unitIndex]
	else
		return size.toFixed(2) + " " + units[unitIndex]
buildDate = (date) ->
	dateString = date.format "{MM}/{d}/{yy} {12hr}:{mm}:{ss} {TT}"
	return dateString
checkValidPath = (file) ->
	file = path.normalize file
	return file.match(new RegExp("^" + BASEPATH))

express = require "express"
app = express()

AVAILABLE_IDS = undefined
app.configure ->
	app.use express.compress()
	app.use express.cookieParser()
	if CREDENTIALS?
		app.use express.basicAuth CREDENTIALS.username, CREDENTIALS.password, "Authentication required to collaborate"
		AVAILABLE_IDS = []
		app.use (request, response, next) ->
			# Set a cookie for authed server
			await createNonce defer id
			response.cookie "id", id
			AVAILABLE_IDS.push id
			next()

app.get "/*", (request, response) ->
	directory = request.params[0] + "/" or "/"
	directory = path.normalize directory
	fullDirectory = path.join BASEPATH, (directory)

	unless checkValidPath(fullDirectory)
		# Failed the path check
		response.redirect "/"

	await fs.readdir fullDirectory, defer(err, entries)
	if err
		response.send 404, "That directory doesn't exist"
		return
	dirList = []
	fileList = []
	infoList = []
	for entry in entries
		await fs.stat path.join(fullDirectory, entry), defer(err, stats)
		if err
			response.type "text/plain"
			response.send 500, "An error occured fetching the file listing\n#{err}"
			return
		if stats.isDirectory()
			dirList.push entry
		else if stats.isFile()
			fileList.push entry
			size = readableSize stats.size
			date = buildDate stats.mtime
			infoList.push size + " - " + date

	response.render "directory.jade", {cwd: fullDirectory, cwdSmall: directory, dirList, fileList, infoList}, (err, html) ->
		if err then return response.send err
		response.send html

server = http.createServer(app).listen PORT, ->
	console.log "You can now collaborate on port #{PORT}"
	console.log "Uppermost accessible directory is #{BASEPATH}"
	if CREDENTIALS?
		console.log "Authentication enabled:\n\tUsername: #{CREDENTIALS.username}, Password: #{CREDENTIALS.password}"

# WebSocket stuff
WSServer = require("ws").Server
wss = new WSServer {server}
wss.on "connection", (ws) ->
	AUTHED = no
	ip = ws._socket.remoteAddress
	console.log "New connection from IP: #{ip}"
	ws.on "message", (message) ->
		try
			message = JSON.parse message
		catch e
			return console.warn "#{ip} sent invalid JSON"
		switch message.Action
			when "auth"
				if CREDENTIALS?
					id = message.ID
					indexID = AVAILABLE_IDS.indexOf id
					if indexID < 0
						# The person submitted an invalid ID
						console.log "Rejected socket auth attempt: #{ip}"
						return ws.close()
					tmp = []
					tmp.push idToPush for idToPush in AVAILABLE_IDS when idToPush isnt id
					AVAILABLE_IDS = tmp
				AUTHED = yes
				toSend =
					"Response": "auth"
					"Authed": true
				toSend = JSON.stringify toSend
				ws.send toSend
			when "info"
				# Get information regarding a file
				unless AUTHED
					toSend =
						"Response": message.Action
						"Error": "Unauthenticated"
					toSend = JSON.stringify toSend
					ws.send toSend

				file = message.File
				unless checkValidPath file
					toSend =
						"Response": "info"
						"Error": "File not accessible"
					toSend = JSON.stringify toSend
					return ws.send toSend
				await fs.stat file, defer(err, stats)
				if err
					toSend =
						"Response": "info"
						"Error": err
					toSend = JSON.stringify toSend
					return ws.send toSend
				if stats.isFile()
					fileInfo =
						"File": yes
						"Size": readableSize stats.size
						"RawSize": stats.size
						"Path": path.basename file
						"FullPath": path.normalize file
						"MimeType": mime.lookup file
						"Time":
							"Accessed": buildDate stats.atime
							"Modified": buildDate stats.mtime
				else
					fileInfo =
						"File": no
						"Path": path.basename file
						"FullPath": path.normalize file
				toSend =
					"Response": "info"
					"Info": fileInfo
				toSend = JSON.stringify toSend
				ws.send toSend
			when "file"
				# Load a file into the view
				unless AUTHED
					toSend =
						"Response": message.Action
						"Error": "Unauthenticated"
					toSend = JSON.stringify toSend
					ws.send toSend
				undefined
			when "edit"
				# Person made a change to the open file
				unless AUTHED
					toSend =
						"Response": message.Action
						"Error": "Unauthenticated"
					toSend = JSON.stringify toSend
					ws.send toSend
				undefined
			when "rename"
				# Person renamed file
				unless AUTHED
					toSend =
						"Response": message.Action
						"Error": "Unauthenticated"
					toSend = JSON.stringify toSend
					ws.send toSend
				file = message.File
				file = path.normalize file
				unless checkValidPath file
					toSend =
						"Response": "rename"
						"Error": "File not accessible"
					toSend = JSON.stringify toSend
					return ws.send toSend
				newFile = message.NewFile
				newFile = path.dirname(file) + "/" + newFile
				newFile = path.normalize newFile
				unless checkValidPath newFile
					toSend =
						"Response": "rename"
						"Error": "File not accessible"
					toSend = JSON.stringify toSend
					return ws.send toSend
				await fs.rename file, newFile, defer(err)
				if err
					toSend =
						"Response": "rename"
						"Error": err
					toSend = JSON.stringify toSend
					return ws.send toSend
				toSend =
					"Response": "rename"
					"Success": true
				toSend = JSON.stringify toSend
				ws.send toSend
			when "sidebar"
				unless AUTHED
					toSend =
						"Response": message.Action
						"Error": "Unauthenticated"
					toSend = JSON.stringify toSend
					ws.send toSend
				directory = message.Directory
				directory = path.normalize directory
				fullDirectory = path.join BASEPATH, (directory)

				return unless checkValidPath(fullDirectory)

				await fs.readdir fullDirectory, defer(err, entries)
				return if err

				dirList = []
				fileList = []
				infoList = []
				for entry in entries
					await fs.stat path.join(fullDirectory, entry), defer(err, stats)
					return if err

					if stats.isDirectory()
						dirList.push entry
					else if stats.isFile()
						fileList.push entry
						size = readableSize stats.size
						date = buildDate stats.mtime
						infoList.push size + " - " + date

				app.render "sidebar.jade", {cwd: fullDirectory, cwdSmall: directory, dirList, fileList, infoList}, (err, html) ->
					return if err
					toSend =
						"Response": "sidebar"
						"Data": html
					toSend = JSON.stringify toSend
					ws.send toSend
			when "delete"
				unless AUTHED
					toSend =
						"Response": message.Action
						"Error": "Unauthenticated"
					toSend = JSON.stringify toSend
					ws.send toSend
				file = message.File
				file = path.normalize file
				return unless checkValidPath(file)

				await fs.unlink file, defer(err)
				if err
					toSend =
						"Response": "delete"
						"Error": err
					toSend = JSON.stringify toSend
					return ws.send toSend
				toSend =
					"Response": "delete"
					"Success": true
				toSend = JSON.stringify toSend
				ws.send toSend
			else
				console.warn "#{ip} sent invalid action: #{message.Action}"
	ws.on "close", ->
		console.log "#{ip} disconnected"
