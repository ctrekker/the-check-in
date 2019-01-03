var admin = require('firebase-admin');

var serviceAccount = require('./firebase-admin-key.json');
admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://health-check-4.firebaseio.com"
});

var message = {
    "notification": {
        // "title": "Push notification test from backend server",
        "body": "Here's the notifications bud"
    },
    "android":{
        "priority":"normal"
    },
    token: 'd-euua2F95M:APA91bFbM9lPxnFDmaZr_n2ZDvkYOPbPuPZCxbxTPW_RI8Co3orAojMu44AGGK7zi0ffq0ePUSvipGo68T2Je2zW-GtARiYqOhHRr8zhfGPSt2LbqM6Yi5s7s2OQnlnKi7LnXpH3i7e1'
};

admin.messaging().send(message)
    .then(function(response) {
        console.log(response);
        console.log("Finito completo");
    })
    .catch(function(err) {
        console.log(err);
    });