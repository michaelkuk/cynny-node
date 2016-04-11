module.exports = (Promise, crypto)->
    class CynnyStreamWriter

        _finalized: null

        _file: null

        _ws: null

        _hashType: null
        _hash: null
        _hashValue: null

        constructor: (@_ws, @_hashType=false)->
            @_hash = if @_hashType then crypto.createHash(@_hashType) else false

            @_finalized = false

        write: (data)->
            @_ws.write(data)
            return true

        getChecksum: ()->
            throw new Error("Writestream has not been finalized yet") unless @_finalized
            throw new Error("Hashing disabled") unless @_hash

            return @_hashValue

        finalize: ()->
            return @_closeStream().then(@_finishHash.bind(@)).then(@_moveFile.bind(@))

        _closeStream: ()->
            @_ws.end()
            return true

        _finishHash: ()->
            @_hashValue = @_hash.digest('hex') if @_hash
            @_finalized = true
            return true

        _moveFile: ()->
            return true
