module.exports = (Promise, request, FormData, fs)->
    class CynnyChunkUploader

        _file: null

        _uploadToken: null
        _signedToken: null

        _bucket: null
        _object: null

        _chunkSize: null
        _chunkIndex: null

        _isParity: null

        constructor: (params, isParity=false)->
            @_storageUrl = params.storageUrl

            @_file = params.file
            @_uploadToken = params.uploadToken
            @_signedToken = params.signedToken
            @_bucket = params.bucket
            @_object = params.object

            @_chunkSize = params.chunkSize
            @_chunkIndex = params.chunkIndex

            @_isParity = isParity


        upload: ()->
            return @_crcStreamAdler32(@_getReadStream()).then(@_uploadForm.bind(@))

        _uploadForm: (crc)->
            return new Promise (resolve, reject)=>

                fd = new FormData()

                fd.append('crc', crc)
                fd.append('chunk', @_getReadStream())

                requestOptions =
                    url: @_getRequestUrl()
                    headers:
                        'x-cyn-signedtoken': @_signedToken
                        'x-cyn-uploadtoken': @_uploadToken
                    formData: fd
                request.put requestOptions, (err, response)=>
                    resolve() # TODO: Check for errors and statusCodes

        _getReadStream: ()->
            return fs.createReadStream(file, {start: @_chunkIndex * @_chunkSize, end: @_chunkIndex * @_chunkSize + @_chunkSize})

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
