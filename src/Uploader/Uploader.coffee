module.exports = ()->
    class CynnyUploader extends EventEmitter
        _done: null

        _totalChunks: null
        _parityChunks: null
        _chunkSize: null

        _bucket: null
        _object: null
        _file: null
        _signedToken: null
        _uploadToken: null

        _chunksUploaded: null
        _parityChunksUploaded: null



        constructor: ()->
            super()

            @_done = false
