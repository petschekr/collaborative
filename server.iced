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
commander.parse process.argv

PORT = if commander.port? then commander.port else 8080
if commander.directory and fs.existsSync(commander.directory)
	BASEPATH = commander.directory
else
	BASEPATH = USERDIR
BASEPATH += "/"
BASEPATH = path.normalize BASEPATH

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

express = require "express"
app = express()

app.get "/", (request, response) ->
	response.redirect "/dir/"
app.get "/dir/*", (request, response) ->
	directory = request.params[0] + "/" or "/"
	fullDirectory = path.join BASEPATH, (directory + "/")

	unless fullDirectory.match(new RegExp("^" + BASEPATH))
		# Failed the path check
		response.redirect "/dir/"

	await fs.readdir fullDirectory, defer(err, entries)
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

app.listen PORT, ->
	console.log "You can now collaborate on port #{PORT}"
	console.log "Uppermost accessible directory is #{BASEPATH}"