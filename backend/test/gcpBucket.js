var gcstorage = require('@google-cloud/storage');
var fs = require('fs');

var storage = new gcstorage.Storage({
    projectId: 'health-check-4',
    keyFilename: 'firebase-admin-key.json'
});

var bucket = storage.bucket('the-check-in-cache');

bucket.file('./cache/maps/39.5298,-69.9129983.png').delete();

// // Write to bucket
// fs.createReadStream('Dockerfile')
//     .pipe(bucket.file('Dockerfile').createWriteStream())
//     .on('error', function(err) {
//         console.log(err);
//     })
//     .on('finish', function() {
//         console.log('Finished uploading!');
//     });
//
// // Read from bucket
// bucket.file('Dockerfile').createReadStream()
//     .pipe(fs.createWriteStream('Dockerfile2'))
//     .on('finish', function() {
//         // Delete file
//         bucket.file('Dockerfile').delete();
//
//     });
