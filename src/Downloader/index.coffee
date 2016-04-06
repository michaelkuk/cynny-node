Promise         = require('bluebird')
EventEmitter    = require('events')
request         = require('request')
crypto          = require('crypto')
async           = require('async')
fs              = require('fs')
path            = require('path')

CynnyFileWriter = require('./FileWriter')(Promise, fs, path, crypto)

module.exports  = require('./Downloader')(Promise, EventEmitter, request, async, CynnyFileWriter)
