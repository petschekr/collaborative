http = require "http"
fs = require "fs"
crypto = require "crypto"
path = require "path"
commander = require "commander"
# Command line arguments
commander.version "0.0.1"
commander.option "-p, --port <n>", "The port for the server to listen on", parseInt
commander.parse process.argv
PORT = if commander.port? then commander.port else 8080

readableSize = (size) ->
	origSize = size
	unitSize = 1024
	unitIndex = 0
	units = ["bytes", "KiB", "MiB", "GiB", "TiB", "PiB"]
	while size >= unitSize
		unitIndex++
		size /= unitSize
	if unitIndex >= units.length
		# Exceeded labels
		unitIndex = 0
		size = origSize
	return size.toFixed(2) + " " + units[unitIndex]

express = require "express"
app = express()

app.get "/", (request, response) ->
	response.redirect "/dir/"
app.get "/dir/*", (request, response) ->
	directory = request.params[0]
});

app.listen PORT, ->
	console.log "You can now collaborate on port #{PORT}"