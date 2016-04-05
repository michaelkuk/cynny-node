module.exports = (Promise, request, FormData, fs)->
    class CynnyChunkUploader

        _file: null
        _fileSize: null

        _uploadToken: null
        _signedToken: null

        _bucket: null
        _object: null

        _chunkSize: null
        _chunkIndex: null
        _chunkData: null
        _fd: null

        constructor: (params, index)->
            @_storageUrl = params.storageUrl

            @_file = params.file
            @_fileSize = params.fileSize

            @_uploadToken = params.uploadToken
            @_signedToken = params.signedToken
            @_bucket = params.bucket
            @_object = params.object

            @_chunkSize = params.chunkSize
            @_chunkIndex = index


        upload: ()->
            return @_getFileDescriptor().then(@_readFile.bind(@)).then(@_removeFileDescriptor.bind(@)).then(@_uploadForm.bind(@))

        destroy: ()->
            @_storageUrl = null

            @_file = null
            @_fileSize = null

            @_uploadToken = null
            @_signedToken = null
            @_bucket = null
            @_object = null

            @_chunkSize = null
            @_chunkIndex = null

            @_chunkData = null
            return true


        _uploadForm: ()->
            return new Promise (resolve, reject)=>
                fd =
                    'crc': @_crcAdler32()
                    'chunk': @_chunkData

                requestOptions =
                    url: @_getRequestUrl()
                    headers:
                        'x-cyn-signedtoken': @_signedToken
                        'x-cyn-uploadtoken': @_uploadToken
                    formData: fd

                request.put requestOptions, (err, response)=>
                    if err || response.statusCode > 399
                        err ?= new Error(response.body)
                        return reject(err)
                    resolve() # TODO: Check for errors and statusCodes

        _getFileDescriptor: ()->
            return new Promise (resolve, reject)=>
                fs.open @_file, 'r', (err, fd)=>
                    return reject(err) if err
                    @_fd = fd
                    return resolve()

        _removeFileDescriptor: ()->
            return new Promise (resolve, reject)=>
                fs.close @_fd, (err)=>
                    return reject(err) if err
                    @_fd = null
                    resolve()

        _readFile: ()->
            return new Promise (resolve, reject)=>
                start = @_chunkSize * @_chunkIndex
                end = Math.min(start + @_chunkSize, @_fileSize)
                length = end-start
                buff = new Buffer(length)
                fs.read @_fd, buff, 0, length, start, (err, bytesRead, buffer)=>
                    return reject(err) if err
                    @_chunkData = buffer
                    resolve()

        _getRequestUrl: ()->
            return "#{@_storageUrl}/b/#{@_bucket}/o/#{@_object}/cnk/#{@_chunkIndex}"

        _crcAdler32: ()->
            a = 0
            b = 0

            data = new Uint8Array(@_chunkData)

            for n in data
                a = (a + Number(n)) % 65521
                b = (b + a) % 65521
            return ((b << 16) | a) >>> 0
