http = require "http"
fs = require "fs"
crypto = require "crypto"
path = require "path"

express = require "express"
app = express()


PORT = 8080
app.listen PORT, ->
	console.log "You can now collaborate on port #{PORT}"