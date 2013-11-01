http = require "http"
fs = require "fs"
crypto = require "crypto"
path = require "path"
commander = require "commander"

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
	dateString = ""
	dateString += (date.getMonth() + 1)
	dateString += "/"
	dateString += date.getDate()
	dateString += "/"
	dateString += (date.getYear() % 100)
	dateString += " "
	dateString += (date.getHours() % 12)
	dateString += ":"
	if date.getMinutes() < 10
		dateString += "0"
	dateString += date.getMinutes()
	dateString += ":"
	if date.getSeconds() < 10
		dateString += "0"
	dateString += date.getSeconds()
	dateString += " "
	if date.getHours() < 12
		dateString += "AM"
	else
		dateString += "PM"
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
		if stats.isDirectory()
			dirList.push entry
		else if stats.isFile()
			fileList.push entry
			size = readableSize stats.size
			date = buildDate stats.ctime
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
				undefined
			when "file"
				# Load a file into the view
				undefined
			when "edit"
				# Person made a change to the open file
				undefined
			when "rename"
				# Person renamed file
				undefined
			else
				console.warn "#{ip} sent invalid action: #{message.Action}"
	ws.on "close", ->
		console.log "#{ip} disconnected"
