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

express = require "express"
app = express()

app.listen PORT, ->
	console.log "You can now collaborate on port #{PORT}"