module.exports = (Promise, request, crypto, fs)->
    class CynnyUploader extends EventEmitter
        _done: null

        _storageUrl: null
        _bucket: null
        _object: null

        _file: null
        _fileSize: null
        _fileMd5: null

        _signedToken: null
        _uploadToken: null

        _uploadQueue: null
        _totalItems: null

        _objectData: null


        constructor: (params = {})->
            super()

            @_done = false

        upload: ()->
            return # TODO: Implement

        _createObject: ()->
            return new Promise (resolve, reject)=>
                requestOptions =
                    url: @_getUrl()
                    body: # TODO: Change
                        md5Encode: ""
                        name: ""
                        size: 0
                    json: true
                    headers:
                        'x-cyn-signedtoken': @_signedToken

                request.post requestOptions, (err, response, body)=>
                    if err || response.statusCode != 200
                        return reject()

                    try
                      @_objectData = JSON.parse(body)
                      resolve()
                    catch error
                        return reject(error)

        _finalizeObject: ()->
            return new Promise (resolve, reject)=>
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
                        return reject()

                    try
                      resolve(JSON.parse(body))
                    catch error
                        return reject(error)

        _getUrl: (patch = false)->
            url = "#{@_storageUrl}/b/#{@_bucket}/o"
            url += "/#{@_object}" if patch
            return url

        _getFileSize: (path)->
            return new Promise (resolve, reject)=>
                fs.stat path, (err, stats)=>
                    return reject(err) if err

                    @_fileSize = stats.size
                    resolve()

        _getFileStream: ()->
            return fs.createReadStream(@_file)

        _getFileHash: ()->
            return new Promise (resolve, reject)=>
                rs = @_getReadStream()
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
                return
