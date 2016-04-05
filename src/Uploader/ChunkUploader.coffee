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
            return @_crcStreamAdler32(@_getReadStream()).then(@_uploadForm.bind(@))

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
            return true


        _uploadForm: (crc)->
            return new Promise (resolve, reject)=>

                # fd = new FormData()
                #
                # fd.append('crc', crc)
                # fd.append('chunk', @_getReadStream())

                fd =
                    'crc': crc
                    'chunk': @_getReadStream()

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

        _getReadStream: ()->
            start = @_chunkIndex * @_chunkSize
            end = (Math.min(@_chunkIndex * @_chunkSize + @_chunkSize, @_fileSize)) - 1
            return fs.createReadStream(@_file, {start: start, end: end})

        _getRequestUrl: ()->
            return "#{@_storageUrl}/b/#{@_bucket}/o/#{@_object}/cnk/#{@_chunkIndex}"

        _crcStreamAdler32: (rs)->
            return new Promise (resolve, reject)=>
                a = 0
                b = 0

                rs.on 'end', ()=>
                    return resolve(((b << 16) | a) >>> 0)

                rs.on 'data', (data)=>
                    arr = new Uint8Array(data)

                    for n in arr
                        a = (a + Number(n)) % 65521
            			b = (b + a) % 65521
