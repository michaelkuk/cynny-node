# cynny-node
NodeJS Cynny Onject Storage Client

**Installation:**
```
npm install cynny-node --save
```
## cynny.Upload

Class representing single file upload to Cynny Object Storage.

**Usage**:
```js
var cynny = require('cynny-node');

// Supply the required parameters
var options = {
    storageUrl: 'http://cy0.cynnylanspace.com',
    bucket: 'Welcome',
    object: 'someFile.txt',
    file: '/abs/path/to/a/someFile.txt',
    signedToken: 'cynnySignedToken'
};

// Initialize the uploader
var uploader = new cynny.Upload(options);

// OPTIONAL: Subscribe to progress events
uploader.on('progress', function(progress){
    console.log("Upload progress: " + progress + "%");
});

// Start the upload (returns a promise)
uploader.upload()
    .then(function(fileData){
        console.log("Finished");
        console.log(JSON.stringify(fileData, null, 4));
    })
    .catch(function(err){
        if(!err){
            err = new Error('Error has occurred')
        }
        console.error(err);
    });

```

## cynny.Download

Class representing single file upload to Cynny Object Storage.

**Usage**:
```js
var cynny = require('cynny-node');

// Supply the required parameters
var options = {
    storageUrl: 'http://cy0.cynnylanspace.com',
    bucket: 'Welcome',
    object: 'someFile.txt',
    file: '/abs/path/to/a/someFile.txt', // Can be a writable stream instance 
    signedToken: 'cynnySignedToken'
};

// Initialize the downloader
var downloader = new cynny.Download(options);

// OPTIONAL: Subscribe to progress events
downloader.on('progress', function(progress){
    console.log("Download progress: " + progress + "%");
});

// Start the download (returns a promise)
downloader.download()
    .then(function(){
        console.log("Finished");
    })
    .catch(function(err){
        if(!err){
            err = new Error('Error has occurred')
        }
        console.error(err);
    });

```
