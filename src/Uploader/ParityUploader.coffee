module.exports = (Promise, request, FormData, fs, async)->
    class CynnyParityUploader

        _storageUrl: null

        _file: null
        _fileSize: null

        _object: null
        _bucket: null

        _signedToken: null
        _uploadToken: null

        _index: null
        _chunkSize: null
        _chunks: null

        _parityStep: null
        _xorData: null

        _fd: null

        _xorIndex: null
        _xorLength: null

        constructor: (params)->
            @_storageUrl = params.storage_url

            @_file = params.file
            @_fileSize = params.file_size

            @_object = params.object
            @_bucket = params.bucket

            @_signedToken = params.signed_token
            @_uploadToken = params.upload_token

            @_chunkSize = params.chunk_size
            @_chunkIndex = params.chunk_index
            @_chunks = params.chunks

            @_parityStep = params.parity_step

            @_xorLength = Math.min((index + 1) * @_parityStep, @_chunks - 1)
            @_xorIndex = @_index * @_parityStep

        upload: ()->
            return @_getFileDescriptor().then(@_calculateParity.bind(@)).then(@_uploadForm.bind(@))

        _calculateParity: ()->
            return new Promise (resolve, reject)=>
                criteria = ()=>
                    return @_xorIndex < @_xorLength

                iterator: (cb)=>
                    start = @_chunkSize * @_xorIndex
                    end = Math.min(start + @_chunkSize, @_fileSize)

                    if start < @_fileSize
                        @_parityIteration(start, end).then ()=>
                            @_xorIndex += 1
                            cb()
                    else
                        @_xorIndex += 1
                        cb()

                callback: (err)=>
                    if err then reject(err) else resolve()

                async.whilst(criteria, iterator, callback)

        _parityIteration: (start, end)->
            return _readFile(start, end).then (buffer)=>
                if @_xorData == null || @_chunks == 1
                    @_xorData = new Uint8Array(buffer)
                else
                    arr = new Uint8Array(buffer)

                    i = 0
                    while i < arr.length
                        @_xorData[i] ^= arr[i]
                        i++

                return true


        _uploadForm: ()->
            return new Promise (resolve, reject)=>

                fd = new FormData()

                fd.append('crc', @_crcAdler32(@_xorData))
                fd.append('chunk', new Buffer(@_xorData))

                requestOptions =
                    url: @_getRequestUrl()
                    headers:
                        'x-cyn-signedtoken': @_signedToken
                        'x-cyn-uploadtoken': @_uploadToken
                    formData: fd

                request.put requestOptions, (err, response)=>
                    resolve() # TODO: Check for errors and statusCodes

        _getFileDescriptor: ()->
            return new Promise (resolve, reject)=>
                fs.open @file, 'r', (err, fd)=>
                    return reject(err) if err
                    @_fd = fd
                    return resolve()

        _readFile: (start, end)->
            return new Promise (resolve, reject)=>
                length = end-start
                buff = new Buffer(length)
                fs.read @_fd, buff, 0, length, start, (err, bytesRead, buffer)=>
                    return reject(err) if err

                    resolve(buffer)

        _getRequestUrl: ()->
            return "#{@_storageUrl}/b/#{@_bucket}/o/#{@_object}/cnk/#{@_chunkIndex}?Parity=1"

        _crcAdler32: (arrayBuffer)->
            a = 0
            b = 0

            data = new Uint8Array(arrayBuffer)

            for n in data
                a = (a + Number(n)) % 65521
                b = (b + a) % 65521
            return ((b << 16) | a) >>> 0
