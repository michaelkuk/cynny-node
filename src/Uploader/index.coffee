Promise                 = require('bluebird')
request                 = require('request')
crypto                  = require('crypto')
fs                      = require('fs')
FormData                = require('form-data')
async                   = require('async')
EventEmitter            = require('events')

CynnyChunkUploader      = require('./ChunkUploader')(Promise, request, FormData, fs)
CynnyParityUploader     = require('./ParityUploader')(Promise, request, FormData, fs, async)

module.exports          = require('./Uploader')(Promise, EventEmitter, async, request, crypto, fs, CynnyChunkUploader, CynnyParityUploader)
