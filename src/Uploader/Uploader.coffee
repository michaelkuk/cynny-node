module.exports = (Promise, EventEmitter, async, request, crypto, fs, CynnyChunkUploader, CynnyParityUploader)->
    class CynnyUploader extends EventEmitter

        # Constructor Parametets => Required
        _storageUrl: null
        _bucket: null
        _object: null
        _signedToken: null
        _file: null

        # Calculated Values
        _fileSize: null
        _fileMd5: null

        # Values Retrieved Upon Object Creation
        _uploadToken: null
        _totalChunks: null
        _partityChunks: null
        _parityStep: null
        _chunkSize: null

        # Progress Tracking
        _uploadQueue: null
        _lastProgress: null

        constructor: (params={})->
            super()
            required = ['storageUrl', 'bucket', 'object', 'signedToken', 'file']
            @_processParams(params, required)
            @_uploadQueue = []
            @_lastProgress = 0

        _processParams: (params, required)->
            actual = Object.keys(params)

            for p in required
                throw new Error("Parameter '#{p}' is required but missing") if actual.indexOf(p) == -1
                @["_#{p}"] = params[p]

        upload: ()->
            promise = @_getFileSize()
            .then(@_getFileHash.bind(@))
            .then(@_createObject.bind(@))
            .then(@_createUploadQueue.bind(@))
            .then(@_processUploadQueue.bind(@))
            .then(@_finalizeObject.bind(@))
            return promise

        _createObject: ()->
            return new Promise (resolve, reject)=>

                requestOptions =
                    url: @_getUrl()
                    body:
                        md5Encode: @_fileMd5
                        name: @_object
                        size: @_fileSize
                    json: true
                    headers:
                        'x-cyn-signedtoken': @_signedToken

                request.post requestOptions, (err, response, body)=>
                    if err || response.statusCode != 200
                        err ?= new Error('Error in object creation')
                        return reject(err)

                    try
                        if typeof body == 'string'
                            parsed = JSON.parse(body)
                            @_parseCreateResponse(parsed.data)
                        else @_parseCreateResponse(body.data)

                        resolve()
                    catch error
                        return reject(error)

        _finalizeObject: ()->
            return new Promise (resolve, reject)=>

                return resolve() unless @_lastProgress

                requestOptions =
                    url: @_getUrl(true)
                    body:
                        status: 1
                    json: true
                    headers:
                        'x-cyn-signedtoken': @_signedToken
                        'x-cyn-uploadtoken': @_uploadToken

                request.patch requestOptions, (err, response, body)=>
                    if err || response.statusCode != 200
                        return reject(new Error('Error in object patch'))

                    try
                      if typeof body == 'string' then resolve(JSON.parse(body)) else resolve(body)
                    catch error
                        return reject(error)

        _createUploadQueue: ()->
            return new Promise (resolve, reject)=>
                @_createChunkObject()
                @_createParityObjects()
                resolve()

        _createChunkObject: ()->
            c = 0
            chunkParams =
                storageUrl: @_storageUrl
                file: @_file
                fileSize: @_fileSize
                uploadToken: @_uploadToken
                signedToken: @_signedToken
                bucket: @_bucket
                object: @_object

            while c < @_totalChunks
                @_uploadQueue.push(new CynnyChunkUploader(chunkParams, c))
                c += 1
            return

        _createParityObjects: ()->
            p = 0
            chunkParams =
                storageUrl: @_storageUrl
                file: @_file
                fileSize: @_fileSize
                uploadToken: @_uploadToken
                signedToken: @_signedToken
                bucket: @_bucket
                object: @_object

                parityStep: @_parityStep
                totalChunks: @_totalChunks
            while p < @_partityChunks
                @_uploadQueue.push(new CynnyParityUploader(chunkParams, p))
                p += 1
            return

        _processUploadQueue: ()->
            return new Promise (resolve, reject)=>
                criteria = ()=>
                    return @_uploadQueue.length > 0

                iterator = (cb)=>
                    upItem = @_uploadQueue.shift()
                    prom = upItem.upload()

                    prom.then ()=>
                        upItem.destroy()
                        upItem = null
                        prom = null
                        @_progress()
                        cb()
                    prom.catch (err)=>
                        # TODO: Implement retries in the future
                        err ?= new Error("Chunk #{upItem._chunkIndex} failed to upload")
                        upItem.destroy()
                        upItem = null
                        prom = null
                        cb(err)

                callback = (err)=>
                    reject(err) if err
                    resolve()

                async.whilst(criteria, iterator, callback)
                return

        _progress: ()->
            currentProgress = Math.floor(100 / @_totalChunks * (@_totalChunks - @_uploadQueue.length))
            @emit('progress', currentProgress) if currentProgress != @_lastProgress

            @_lastProgress = currentProgress

        _getUrl: (patch = false)->
            url = "#{@_storageUrl}/b/#{@_bucket}/o"
            url += "/#{@_object}" if patch
            return url

        _getFileSize: ()->
            return new Promise (resolve, reject)=>
                fs.stat @_file, (err, stats)=>
                    return reject(err) if err

                    @_fileSize = stats.size
                    resolve()

        _getFileStream: ()->
            return fs.createReadStream(@_file)

        _getFileHash: ()->
            return new Promise (resolve, reject)=>
                rs = @_getFileStream()
                md5 = crypto.createHash('md5')

                md5.setEncoding('hex')

                rs.on 'end', ()=>
                    md5.end()
                    @_fileMd5 = md5.read()
                    resolve()

                rs.on 'error', (err)=>
                    reject(err)

                md5.on 'error', (err)=>
                    reject(err)

                rs.pipe(md5)
                return

        _parseCreateResponse: (data)->
            @_uploadToken = data.uploadToken
            @_totalChunks = data.emptyChunks
            @_partityChunks = data.emptyParityChunks
            @_parityStep = data.object.parityStep
            @_chunkSize = data.object.chunkSize
            return
