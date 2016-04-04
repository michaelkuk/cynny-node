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

        constructor: (params)->
            @_storageUrl = params.storage_url

            @_file = params.file
            @_fileSize = params.file_size

            @_uploadToken = params.upload_token
            @_signedToken = params.signed_token
            @_bucket = params.bucket
            @_object = params.object

            @_chunkSize = params.chunk_size
            @_chunkIndex = params.chunk_index


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
            return fs.createReadStream(@_file, {start: @_chunkIndex * @_chunkSize, end: @_chunkIndex * @_chunkSize + @_chunkSize})

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
