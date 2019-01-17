var express = require('express');
var bodyParser = require('body-parser');
var router = express.Router();
var admin = require('firebase-admin');
var responses = require('../response');
var fs = require('fs');
var path = require('path');
var imageDownloader = require('image-downloader');
var md5 = require('md5');
var Twig = require('twig');
var dateFormat = require('dateformat');
var moment = require('moment-timezone');

var serviceAccount = require('../firebase-admin-key.json');
admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://health-check-4.firebaseio.com"
});

router.post('/create', function(req, res) {
    if(req.body.email&&req.body.name&&req.body.password) {
        admin.auth().createUser({
            email: req.body.email,
            emailVerified: false,
            password: req.body.password,
            displayName: req.body.name,
            disabled: false
        }).then(function (userRecord) {
            res.json(responses.get('AUTH_CREATE_SUCCESS', {}, null, userRecord.uid, req));
        }).catch(function (err) {
            res.json(responses.get('GENERIC_ERROR', {code: err.errorInfo.code}, err, null, req));
        });
    }
    else {
        res.json(responses.get('AUTH_MISSING_ARGS', {}, null, null, req));
    }
});
router.post('/device/fcm', function(req, res) {
    if(!req.body.token || !req.body.device_id || !req.body.fcm_token) {
        res.json(responses.get('AUTH_MISSING_ARGS', {}, null, null, req));
        return;
    }
    admin.auth().verifyIdToken(req.body.token).then(function(decodedToken) {
        conn.execute(
            'SELECT COUNT(*) AS device_matches FROM devices WHERE device_id=?',
            [req.body.device_id],
            function(err, results, fields) {
                var device_matches = results[0]['device_matches'];
                if(device_matches < 1) {
                    res.json(responses.get('DEVICE_ID_INVALID', {}, null, decodedToken.uid, req));
                }
                else {
                    conn.execute(
                        'DELETE FROM fcm_tokens WHERE device_id=?',
                        [req.body.device_id],
                        function(err, results, fields) {
                            if(err) {
                                res.json(responses.get('GENERIC_DB_ERROR', {}, err, decodedToken.uid, req));
                            }
                            else {
                                conn.execute(
                                    'INSERT INTO fcm_tokens (device_id, uid, token) VALUES (?, ?, ?)',
                                    [req.body.device_id, decodedToken.uid, req.body.fcm_token],
                                    function (err, results, fields) {
                                        if (err) {
                                            res.json(responses.get('GENERIC_DB_ERROR', {}, err, decodedToken.uid, req));
                                        }
                                        else {
                                            res.json(responses.get('FCM_UPDATE_SUCCESS', {}, null, decodedToken.uid, req));
                                        }
                                    });
                            }
                        });
                }
            });
    }).catch(function(err) {
        res.json(responses.get('AUTH_BAD_TOKEN', {}, err, null, req));
    });
});
router.post('/device/init', function(req, res) {
    if(!req.body.token) {
        res.json(responses.get('AUTH_MISSING_ARGS', {}, null, null, req));
        return;
    }
    admin.auth().verifyIdToken(req.body.token).then(function(decodedToken) {
        conn.execute(
            'SELECT COUNT(*) AS device_count FROM devices WHERE uid=?',
            [decodedToken.uid],
            function(err, results, fields) {
                var device_count = results[0]['device_count'];
                if(device_count >= 100) {
                    res.json(responses.get('DEVICE_COUNT_OVERFLOW', {}, null, decodedToken.uid, req));
                    return;
                }
                var device_id = generateId(32);
                conn.execute(
                    'INSERT INTO devices (device_id, uid) VALUES (?, ?)',
                    [device_id, decodedToken.uid],
                    function(err, results, fields) {
                        res.json(responses.get('DEVICE_INIT_SUCCESS', {device_id: device_id}, null, decodedToken.uid, req));
                    });
            });
    }).catch(function(err) {
        res.json(responses.get('AUTH_BAD_TOKEN', {}, err, null, req));
    });
});
router.post('/details', function(req, res) {
    if(!req.body.token) {
        res.json(responses.get('AUTH_MISSING_ARGS', {}, null, null, req));
        return;
    }
    admin.auth().verifyIdToken(req.body.token).then(function(decodedToken) {
        admin.auth().getUser(decodedToken.uid).then(function(userRecord) {
            var user = userRecord.toJSON();
            res.json(responses.get('AUTH_DETAILS_SUCCESS', {
                uid: user.uid,
                email: user.email,
                emailVerified: user.emailVerified,
                lastLogin: user.metadata.lastSignInTime,
                name: user.displayName,
                photoURL: user.photoURL
            }, null, decodedToken.uid, req));
        }).catch(function(err) {
            res.json(responses.get('AUTH_GETUSER_ERROR', {}, err, decodedToken.uid, req));
        });
    }).catch(function (err) {
        res.json(responses.get('AUTH_BAD_TOKEN', {}, err, null, req));
    });
});

router.post('/attribute/getAll', function(req, res) {
    if(!req.body.token) {
        res.json(responses.get('AUTH_MISSING_ARGS', {}, null, null, req));
        return;
    }
    admin.auth().verifyIdToken(req.body.token).then(function(decodedToken) {
        conn.execute(
            'SELECT (SELECT name FROM attributes WHERE id = user_attributes.attribute) AS attribute,value FROM user_attributes WHERE uid = ?',
            [decodedToken.uid],
            function(err, results, fields) {
                if(err) {
                    res.json(responses.get('GENERIC_DB_ERROR', {}, err, decodedToken.uid, req));
                }
                else {
                    var out = {};
                    for(var i=0; i<results.length; i++) {
                        out[results[i].attribute] = results[i].value;
                    }
                    res.json(out);
                    responses.get('ATTRIBUTE_GET_SUCCESS', {}, null, decodedToken.uid, req);
                }
            });
    }).catch(function(err) {
        res.json(responses.get('AUTH_BAD_TOKEN', {}, err, null, req));
    });
});
router.post('/attribute/:attributeId/get', function(req, res) {
    if(!req.body.token) {
        res.json(responses.get('AUTH_MISSING_ARGS', {}, null, null, req));
        return;
    }
    admin.auth().verifyIdToken(req.body.token).then(function(decodedToken) {
        getAttribute(decodedToken.uid, req.params.attributeId, req, function(err, response) {
            res.json(response);
        });
    }).catch(function(err) {
        res.json(responses.get('AUTH_BAD_TOKEN', {}, err, null, req));
    });
});
router.post('/attribute/:attributeId/set', function(req, res) {
    if(!req.body.token||!req.body.value) {
        res.json(responses.get('AUTH_MISSING_ARGS', {}, null, null, req));
        return;
    }
    admin.auth().verifyIdToken(req.body.token).then(function(decodedToken) {
        var attributeId = req.params.attributeId;
        conn.execute(
            'SELECT COUNT(*) AS attr_num FROM backend.user_attributes WHERE uid = ? AND attribute = (SELECT id FROM attributes WHERE name = ?)',
            [decodedToken.uid, attributeId],
            function(err, results, fields) {
                if(err) {
                    res.json(responses.get('GENERIC_DB_ERROR', {}, err, decodedToken.uid, req));
                }
                var sql = 'UPDATE user_attributes SET value = ? WHERE uid = ? AND attribute = (SELECT id FROM attributes WHERE name = ?)';
                if(parseInt(results[0].attr_num) === 0) {
                    sql = 'INSERT INTO backend.user_attributes (value, uid, attribute) VALUES (?, ?, (SELECT id FROM attributes WHERE name = ?))';
                }
                conn.execute(
                    sql,
                    [req.body.value, decodedToken.uid, attributeId],
                    function(err, results, fields) {
                        if(err) {
                            res.json(responses.get('GENERIC_DB_ERROR', {}, err, decodedToken.uid, req));
                        }
                        else {
                            res.json(responses.get('ATTRIBUTE_SET_SUCCESS', {}, null, decodedToken.uid, req));
                        }
                    });
            });
    }).catch(function(err) {
        res.json(responses.get('AUTH_BAD_TOKEN', {}, err, null, req));
    });
});

router.post('/recipients/getAll', function(req, res) {
    if(!req.body.token) {
        res.json(responses.get('AUTH_MISSING_ARGS', {}, null, null, req));
        return;
    }
    admin.auth().verifyIdToken(req.body.token).then(function(decodedToken) {
        conn.execute(
            'SELECT id,name,uid,email,phone_number FROM recipients WHERE owner = ? AND deleted != TRUE',
            [decodedToken.uid],
            function(err, results, fields) {
                if(err) {
                    res.json(responses.get('GENERIC_DB_ERROR', {}, err, decodedToken.uid, req));
                }
                else {
                    responses.get('RECIPIENT_GET_SUCCESS', {}, null, decodedToken.uid, req);
                    res.json(results);
                }
            });
    }).catch(function(err) {
        res.json(responses.get('AUTH_BAD_TOKEN', {}, err, null, req));
    });
});
router.post('/recipients/add', function(req, res) {
    var info;
    if(!req.body.token||!req.body.info) {
        res.json(responses.get('AUTH_MISSING_ARGS', {}, null, null, req));
        return;
    }
    else {
        try {
            info = JSON.parse(req.body.info);

            info.uid = info.uid || null;
            info.phone_number = info.phone_number || null;
            info.email = info.email || null;
            info.name = info.name || null;

            if(info.uid==null&&info.phone_number==null&&info.email==null) {
                res.json(responses.get('MALFORMED_ARGUMENT', {}, null, null, req));
                return;
            }
        } catch(err) {
            res.json(responses.get('MALFORMED_ARGUMENT', {}, err, null, req));
            return;
        }
    }
    admin.auth().verifyIdToken(req.body.token).then(function(decodedToken) {
        conn.execute(
            'INSERT INTO recipients (owner, uid, phone_number, email, name) VALUES (?, ?, ?, ?, ?)',
            [decodedToken.uid, info.uid, info.phone_number, info.email, info.name],
            function(err, results, fields) {
                if(err) {
                    res.json(responses.get('GENERIC_DB_ERROR', {}, err, decodedToken.uid, req));
                }
                else {
                    res.json(responses.get('RECIPIENT_ADD_SUCCESS', {}, null, decodedToken.uid, req));
                }
            });
    }).catch(function(err) {
        res.json(responses.get('AUTH_BAD_TOKEN', {}, err, null, req));
    });
});
router.post('/recipients/remove', function(req, res) {
    if(!req.body.token||!req.body.id) {
        res.json(responses.get('AUTH_MISSING_ARGS', {}, null, null, req));
        return;
    }
    admin.auth().verifyIdToken(req.body.token).then(function(decodedToken) {
        conn.execute(
            'UPDATE recipients SET deleted = TRUE WHERE id = ? AND owner = ? AND deleted != TRUE',
            [req.body.id, decodedToken.uid],
            function(err, results, fields) {
                if(err) {
                    res.json(responses.get('GENERIC_DB_ERROR', {}, err, decodedToken.uid, req));
                }
                else {
                    if(results.affectedRows < 1) {
                        res.json(responses.get('GENERIC_PERMISSIONS_ERROR', {}, null, decodedToken.uid, req));
                    }
                    else {
                        res.json(responses.get('RECIPIENT_REMOVE_SUCCESS', {}, null, decodedToken.uid, req));
                    }
                }
            });
    }).catch(function(err) {
        res.json(responses.get('AUTH_BAD_TOKEN', {}, err, null, req));
    });
});

router.post('/activity/get', function(req, res) {
    if(!req.body.token) {
        res.json(responses.get('AUTH_MISSING_ARGS', {}, null, null, req));
        return;
    }
    admin.auth().verifyIdToken(req.body.token).then(function(decodedToken) {
        getSetting(decodedToken.uid, 'activities_visible', req, function(value) {
            value = value || "10";
            if(parseInt(value) > 100) {
                value = "1";
            }
            getAttribute(decodedToken.uid, 'timezone', req, function(err, response) {
                var timezone = response.value || 'UTC';
                conn.execute(
                    'SELECT title, summary, message, type, send_timestamp as `timestamp` FROM activity WHERE uid=? ORDER BY send_timestamp DESC LIMIT ?',
                    [decodedToken.uid, parseInt(value)],
                    function(err, results, fields) {
                        if(err) {
                            res.json(responses.get('GENERIC_DB_ERROR', {}, err, decodedToken.uid, req));
                            return;
                        }
                        for(var i=0; i<results.length; i++) {
                            results[i]['date'] = moment(results[i]['timestamp']).tz(timezone).format('MMMM Do YYYY, h:mm a [(' + timezone + ')]');
                        }
                        res.json(responses.get('ACTIVITY_GET_SUCCESS', { activity: results }, null, decodedToken.uid, req));
                    });
            });
        });
    }).catch(function(err) {
        try {
            res.json(responses.get('AUTH_BAD_TOKEN', {}, err, null, req));
        }
        catch(e) {
            console.log('WARN: error within /activity/get auth catch block');
        }
    });
});

router.post('/checkIn', function(req, res) {
    if(!req.body.token||!req.body.info) {
        res.json(responses.get('AUTH_MISSING_ARGS', {}, null, null, req));
    }
    admin.auth().verifyIdToken(req.body.token).then(function(decodedToken) {
        try {
            var info = JSON.parse(req.body.info);
            info.rating = parseFloat(info.rating || "-1");
            info.message = info.message || null;
            info.image_id = info.image_id || null;
            info.location = info.location || null;

            var recipients = req.body.recipients.split(',');
        } catch(err) {
            res.json(responses.get('MALFORMED_ARGUMENT', {}, err, decodedToken.uid, req));
        }

        conn.execute(
            'INSERT INTO check_in (uid, rating, message, image_id, location, recipients) VALUES (?, ?, ?, ?, ?, ?)',
            [decodedToken.uid, info.rating, info.message, info.image_id, info.location, recipients.join(',')],
            function(err, results, fields) {
                if(err) {
                    res.json(responses.get('GENERIC_DB_ERROR', {}, err, decodedToken.uid, req));
                }
                else {
                    getRecipients(req.body.token, function(err, results) {
                        if(err) {
                            res.json(responses.get('RECIPIENT_GET_ERROR', {}, err, decodedToken.uid, req));
                        }
                        else {
                            info.location_image_url = info.location != null ? getMapForLocation(info.location) : null;
                            var recipientEmails = [];
                            var settingCallbacks = 0;
                            var settingTarget = 0;
                            for(var i=0; i<results.length; i++) {
                                var currentEmail = results[i].email;
                                for(var j=0; j<recipients.length; j++) {
                                    if(results[i].id === parseInt(recipients[j]) && currentEmail != null) {
                                        settingTarget++;
                                        getSetting(decodedToken.uid, 'receive_emails', req, function(value, email) {
                                            settingCallbacks++;
                                            if(value !== false) {
                                                recipientEmails.push(email);
                                            }
                                            if(settingCallbacks >= settingTarget) {
                                                callback();
                                            }
                                        }, currentEmail);

                                        break;
                                    }
                                }
                            }
                            function callback() {
                                if (recipientEmails.length > 0) {
                                    sendEmails(decodedToken.uid, recipientEmails, info, req, function (err) {
                                        if (err) {
                                            //responses.get('GENERIC_EMAIL_ERROR', {}, err, decodedToken.uid, req);
                                        }
                                    });
                                }
                                sendPushNotifications(decodedToken.uid, recipientEmails, info, function (err) {
                                    if (err) {

                                    }
                                });
                                res.json(responses.get('CHECKIN_SUCCESS', {}, null, decodedToken.uid, req));
                            }
                        }
                    });
                }
            });
    }).catch(function(err) {
        res.json(responses.get('AUTH_BAD_TOKEN', {}, err, null, req));
    });
});
router.post('/image/upload', function(req, res) {
    if(!req.body.token||!req.body.image) {
        res.json(responses.get('AUTH_MISSING_ARGS', {}, null, null, req));
        return;
    }
    admin.auth().verifyIdToken(req.body.token).then(function(decodedToken) {
        imageId = generateId();
        fs.writeFile('images/' + imageId + '.png', req.body.image, 'base64', function(err) {
            if(err) {
                res.json(responses.get('UPLOAD_DATA_MALFORMED', {}, err, decodedToken.uid, req));
            }
            else {
                res.json(responses.get('UPLOAD_SUCCESS', {image_id: imageId}, null, decodedToken.uid, req));
            }
        });
    });
});
router.all('/image/get/:imageId', function(req, res) {
    res.sendFile(path.resolve('images/' + req.params.imageId + '.png'));
});
router.all('/maps/get/:mapId', function(req, res) {
    var cachePath = path.resolve('cache/maps/' + req.params.mapId + '.png');
    if(!fs.existsSync(cachePath)) {
        res.send('No file');
    }
    else {
        res.sendFile(cachePath)
    }
});

function getRecipients(token, callback) {
    admin.auth().verifyIdToken(token).then(function(decodedToken) {
        conn.execute(
            'SELECT id,name,uid,email,phone_number FROM recipients WHERE owner = ? AND deleted != TRUE',
            [decodedToken.uid],
            function(err, results, fields) {
                if(err) {
                    callback(err, 'GENERIC_DB_ERROR');
                }
                else {
                    callback(undefined, results);
                }
            });
    }).catch(function(err) {
        callback('AUTH_BAD_TOKEN', err);
    });
}
function getSetting(uid, name, req, callback, mutables) {
    getAttribute(uid, 'settings', req, function(err, res) {
        if(err || !res['value']) {
            callback(null, mutables);
        }
        else {
            callback(JSON.parse(res['value'])[name], mutables);
        }
    });
}
function getAttribute(uid, attributeId, req, callback) {
    conn.execute(
        'SELECT value FROM user_attributes WHERE uid = ? AND attribute = (SELECT id FROM attributes WHERE name = ?)',
        [uid, attributeId.toUpperCase()],
        function(err, results, fields) {
            if(err) {
                callback(true, responses.get('GENERIC_DB_ERROR', {}, err, uid, req));
            }
            else {
                if(results.length > 0) {
                    callback(false, responses.get('ATTRIBUTE_GET_SUCCESS', {value: results[0].value}, null, uid, req));
                }
                else {
                    callback(false, responses.get('ATTRIBUTE_GET_SUCCESS', {value: null}, null, uid, req));
                }
            }
        });
}
function sendEmails(uid, emails, info, req, callback) {
    admin.auth().getUser(uid).then(function (user) {
        var location = info.location ? JSON.parse(info.location) : null;
        var subject = user.displayName + ' has checked in';

        var emailContent = '';
        emailContent += '<p>' + (info.rating === -1 ? 'No rating was given' : 'Rating: ' + info.rating + ' of 5 stars') + '</p>';
        emailContent += '<p>' + (info.message === null ? 'No message was sent' : 'Message: ' + info.message) + '</p>';
        emailContent += '<p>' + (info.image_id === null ? 'No image was sent' : '<img src="' + global.domain + '/user/image/get/' + info.image_id + '"/>') + '</p>';
        getAttribute(uid, 'timezone', req, function(err, res) {
            if(err) {
                console.log('error: '+res);
            }
            else {
                var timezone = res.value || 'UTC';

                Twig.renderFile('./views/email_template.twig', {
                    domain: global.domain,
                    display_name: user.displayName,
                    message: info.message || undefined,
                    image_id: info.image_id || undefined,
                    location: info.location || undefined,
                    location_latitude: location.latitude,
                    location_longitude: location.longitude,
                    // date: dateFormat(new Date(), 'mmmm dS, yyyy'),
                    // time: dateFormat(new Date(), 'h:MM TT')
                    date_time: moment().tz(timezone).format('MMMM Do YYYY, h:mm a [(' + timezone + ')]')
                }, function(err, html) {
                    if(err) {
                        console.log(err);
                        return;
                    }
                    email.sendMail({
                        from: 'burnscoding@gmail.com',
                        bcc: emails.join(','),
                        subject: subject,
                        html: html
                    }, function(err, info) {
                        if(err) {
                            callback(err);
                        }
                        else {
                            callback();
                        }
                    });
                });
            }
        });
    });
}
function sendPushNotifications(uid, emails, info, callback) {
    admin.auth().getUser(uid).then(function(user) {
        var title = user.displayName + ' has checked in';
        var titleSelf = 'You have checked in';
        var summary = getSummary(user.displayName);
        var summarySelf = getSummary('You');
        var message = [];
        function getSummary(displayName) {
            var out = [];
            if(info.rating !== -1) {
                out.push(displayName + ' gave a rating of ' + info.rating);
            }
            if(info.message !== null && info.image_id === null) {
                out.push('A message was sent');
            }
            else if(info.message !== null && info.image_id !== null) {
                out.push('A message and an image were sent');
            }
            else if(info.message === null && info.image_id !== null) {
                out.push('An image was sent');
            }
            if(info.location !== null) {
                out.push('Location data was shared');
            }
            return out;
        }


        summary = summary.join('. ');
        summarySelf = summarySelf.join('. ');

        var location = JSON.parse(info.location);

        // if(info.rating !== -1) message += '<p>Rating: ' + info.rating + ' stars</p>';
        if(info.message) {
            message.push({
                title: 'Message',
                text: info.message
            });
        }
        if(info.image_id) {
            message.push({
                title: 'Image',
                image_url: global.domain + '/user/image/get/' + info.image_id
            });
        }
        if(info.location) {
            message.push({
                title: 'Location',
                location: location
            });
        }

        if(message.length < 1) {
            message.push({
                text: 'No details were provided'
            });
        }

        addActivity(user.uid, titleSelf, summarySelf, message, 'CHECKIN_S', function(err) {
            if(err) console.log(err);
        });

        for(var email_id = 0; email_id < emails.length; email_id++) {
            var email = emails[email_id];
            admin.auth().getUserByEmail(email)
                .then(function(user) {
                    addActivity(user.uid, title, summary, message, 'CHECKIN_R', function(err) {
                        if(err) console.log(err);
                    });
                    conn.execute(
                        'SELECT token FROM fcm_tokens WHERE uid=?',
                        [user.uid],
                        function(err, results, fields) {
                            for(var i=0; i<results.length; i++) {
                                admin.messaging().send({
                                    "notification": {
                                        "title": title,
                                        "body": summary
                                    },
                                    "android":{
                                        "priority": "high",
                                        "notification": {
                                            "sound": "default"
                                        }
                                    },
                                    "apns": {
                                        "payload": {
                                            "aps": {
                                                "sound": "default"
                                            }
                                        }
                                    },
                                    "token": results[i]['token']
                                }).then(function(response) {

                                }).catch(function(err) {

                                });
                            }
                        });
                })
                .catch(function(err) {

                });
        }
    });
}
function addActivity(uid, title, summary, message, type, callback) {
    conn.execute(
        'INSERT INTO activity (uid, title, summary, message, type) VALUES (?, ?, ?, ?, ?)',
        [uid, title, summary, message, type],
        function(err, results, fields) {
            if(err) {
                callback(err);
            }
            else {
                callback();
            }
        });
}
function generateId(length) {
    length = length || 32;
    var text = "";
    var possible = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_";

    for (var i = 0; i < length; i++)
        text += possible.charAt(Math.floor(Math.random() * possible.length));

    return text;
}
function getMapForLocation(location) {
    location = JSON.parse(location);
    var center = location.latitude+','+location.longitude;
    var params = {
        center: center,
        zoom: 14,
        size: '640x480',
        maptype: 'roadmap',
        markers: [
            {
                location: center,
                color   : 'red',
                shadow  : true
            }
        ]
        // style: [
        //     {
        //         feature: 'road',
        //         element: 'all',
        //         rules: {
        //             hue: '0x00ff00'
        //         }
        //     }
        // ]
    };
    var url = global.gmaps.staticMap(params);

    imageDownloader.image({
        url: url,
        dest: './cache/maps/' + center + '.png'
    });

    return global.domain + '/user/maps/get/' + center;
}

function shallowClone(obj) {
    var out = {};
    var keys = Object.keys(obj);
    for(var i = 0; i < keys.length; i++) {
        out[keys[i]] = obj[keys[i]];
    }
    return out;
}

module.exports = router;
