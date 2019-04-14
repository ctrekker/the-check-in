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
                            // results[i]['date'] = standardDateFormat(results[i]['timestamp'], timezone);
                            results[i]['date'] = conciseDateFormat(results[i]['timestamp'], timezone);
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
    if(!req.body.token||!req.body.recipients) {
        res.json(responses.get('AUTH_MISSING_ARGS', {}, null, null, req));
    }
    admin.auth().verifyIdToken(req.body.token).then(function(decodedToken) {
        // Init recipients
        var recipients = req.body.recipients.split(',');

        // Init info
        var info;
        if(req.body.info) {
            try {
                info = JSON.parse(req.body.info);
            } catch (err) {
                res.json(responses.get('MALFORMED_ARGUMENT', {}, err, decodedToken.uid, req));
                return;
            }
        }
        else {
            info = {};
        }
        info.rating = parseFloat(info.rating || "-1");
        info.message = info.message || null;
        info.image_id = info.image_id || null;
        info.location = info.location || null;
        info.user = {
            name: decodedToken.name,
            email: decodedToken.email
        };

        // Init flags
        var flags;
        if(req.body.flags) {
            try {
                flags = JSON.parse(req.body.flags);
            } catch(err) {
                res.json(responses.get('MALFORMED_ARGUMENT', {}, err, decodedToken.uid, req));
                return;
            }
        }
        // Defaults
        else {
            flags = {}
        }
        if(!flags.REQUEST_CHECKIN) flags.REQUEST_CHECKIN = false;

        var associatedWith;
        if(req.body.associatedWith) {
            try {
                associatedWith = parseInt(req.body.associatedWith);
            } catch(err) {
                res.json(responses.get('MALFORMED_ARGUMENT', {}, err, decodedToken.uid, req));
                return;
            }
        }
        else {
            associatedWith = -1;
        }

        conn.execute('SELECT id FROM check_in ORDER BY id DESC LIMIT 1',
            [],
            function(err, results, fields) {
                var checkinId = -1;
                if (!err) {
                    checkinId = results[0]['id'] + 1;
                    info.checkinId = checkinId;
                }
                else {
                    res.json(responses.get('GENERIC_DB_ERROR', {}, err, decodedToken.uid, req));
                    return;
                }
                conn.execute(
                    'INSERT INTO check_in (id, uid, rating, message, image_id, location, recipients, flag_request) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
                    [checkinId, decodedToken.uid, info.rating, info.message, info.image_id, info.location, recipients.join(','), flags.REQUEST_CHECKIN],
                    function(err, results, fields) {
                        if(err) {
                            res.json(responses.get('GENERIC_DB_ERROR', {}, err, decodedToken.uid, req));
                        }
                        else {
                            if(associatedWith !== -1) {
                                conn.execute(
                                    'SELECT uid, recipients FROM check_in WHERE id=?',
                                    [associatedWith],
                                    function(err, results, fields) {
                                        if(err || results.length === 0) {
                                            return;
                                        }
                                        admin.auth().getUser(decodedToken.uid).then(function(user) {
                                            var splitRecipients = results[0]['recipients'].split(',');
                                            getRecipients(results[0]['uid'], function(err, results) {
                                                for(var i=0; i<results.length; i++) {
                                                    if(splitRecipients.indexOf(results[i]['id'].toString()) !== -1 && results[i]['email'] === user.email) {
                                                        associationValid();
                                                        break;
                                                    }
                                                }
                                            }, true, true);

                                            function associationValid() {
                                                conn.execute(
                                                    "UPDATE activity SET type=? WHERE uid=? AND checkin_id=? AND type='CHECKIN_RR'",
                                                    ['CHECKIN_RR_R', decodedToken.uid, associatedWith],
                                                    function(err, results, fields) {
                                                        // Everything is complete
                                                    });
                                            }
                                        }).catch(function(err) {

                                        });
                                    });
                            }

                            getRecipients(req.body.token, function(err, results) {
                                if(err) {
                                    res.json(responses.get('RECIPIENT_GET_ERROR', {}, err, decodedToken.uid, req));
                                }
                                else {
                                    info.location_image_url = info.location != null ? getMapForLocation(info.location) : null;
                                    var recipientEmails = [];
                                    var allEmails = [];
                                    var settingCallbacks = 0;
                                    var settingTarget = 0;

                                    for (var i = 0; i < results.length; i++) {
                                        var currentEmail = results[i].email;
                                        for (var j = 0; j < recipients.length; j++) {
                                            if (results[i].id === parseInt(recipients[j]) && currentEmail != null) {
                                                allEmails.push(currentEmail);
                                                settingTarget++;
                                                getSetting(decodedToken.uid, 'receive_emails', req, function (value, email) {
                                                    settingCallbacks++;
                                                    if (value !== false) {
                                                        recipientEmails.push(email);
                                                    }
                                                    if (settingCallbacks >= settingTarget) {
                                                        callback();
                                                    }
                                                }, currentEmail);

                                                break;
                                            }
                                        }
                                    }

                                    function callback() {
                                        if (recipientEmails.length > 0) {
                                            sendEmails(decodedToken.uid, recipientEmails, info, flags, req, function (err) {
                                                if (err) {
                                                    //responses.get('GENERIC_EMAIL_ERROR', {}, err, decodedToken.uid, req);
                                                }
                                            });
                                        }
                                        // conn.execute(
                                        //     'SELECT LAST_INSERT_ID() AS checkinId',
                                        //     [],
                                        //     function (err, results, fields) {

                                        sendPushNotifications(decodedToken.uid, allEmails, info, checkinId, flags.REQUEST_CHECKIN, function (err) {
                                            if (err) {

                                            }
                                        });
                                        // });

                                        var custom = {};
                                        if(flags.REQUEST_CHECKIN) {
                                            custom.message = 'You have now requested a check in';
                                        }
                                        res.json(responses.get('CHECKIN_SUCCESS', custom, null, decodedToken.uid, req));
                                    }
                                }
                            });
                        }
                    });
            });
    }).catch(function(err) {
        res.json(responses.get('AUTH_BAD_TOKEN', {}, err, null, req));
    });
});
router.post('/checkIn/get', function(req, res) {
    if(!req.body.token||!req.body.quantity||!req.body.page||!req.body.query) {
        res.json(responses.get('AUTH_MISSING_ARGS', {}, null, null, req));
        return;
    }
    admin.auth().verifyIdToken(req.body.token).then(function(decodedToken) {
        var quantity, page;
        if(!isNaN(req.body.quantity) && !isNaN(req.body.page)) {
            quantity = parseInt(req.body.quantity);
            page = parseInt(req.body.page);
        } else {
            res.json(responses.get('MALFORMED_ARGUMENT', {}, null, decodedToken.uid, req));
            return;
        }

        if(quantity > 100) {
            res.json(responses.get('MALFORMED_ARGUMENT', {}, null, decodedToken.uid, req));
            return;
        }

        var query = req.body.query;
        var flag_request;
        switch(query) {
            case 'your_checkins':
            case 'your_checkin_requests':
                flag_request = query !== 'your_checkins';
                conn.execute(
                    'SELECT checkin_time, rating, message, image_id, location, recipients FROM check_in WHERE uid=? AND flag_request=? ORDER BY checkin_time DESC LIMIT ?, ?',
                    [decodedToken.uid, flag_request, page*quantity, quantity],
                    function(err, results, fields) {
                        if(err) {
                            res.json(responses.get('GENERIC_DB_ERROR', {}, err, decodedToken.uid, req));
                            return;
                        }
                        getAttribute(decodedToken.uid, 'timezone', req, function(err, response) {
                            var timezone = response.value || 'UTC';
                            for(var i=0; i<results.length; i++) {
                                results[i]['checkin_time_parsed'] = standardDateFormat(results[i]['checkin_time'], timezone);
                                results[i]['message'] = constructJsonMessage(results[i]);
                            }

                            res.json(results);
                        });
                    });
                break;
            case 'others_checkins':
            case 'others_checkin_requests':
                flag_request = query !== 'others_checkins';
                conn.execute(
                    'SELECT uid, checkin_time, rating, message, image_id, location, recipients FROM check_in WHERE id IN (SELECT checkin_id FROM check_in_others WHERE recipient_uid=?) AND flag_request=? ORDER BY checkin_time DESC LIMIT ?, ?',
                    [decodedToken.uid, flag_request, page*quantity, quantity],
                    function(err, results, fields) {
                        if(err) {
                            res.json(responses.get('GENERIC_DB_ERROR', {}, err, decodedToken.uid, req));
                            return;
                        }
                        getAttribute(decodedToken.uid, 'timezone', req, function(err, response) {
                            var timezone = response.value || 'UTC';
                            var completedCount = 0;

                            function loadName(uid, index, callback) {
                                admin.auth().getUser(uid).then(function(user) {
                                    callback(user.displayName, index);
                                    completedCount++;

                                    if(completedCount >= results.length) {
                                        complete();
                                    }
                                }).catch(function(err) {
                                    callback(null, index);
                                });
                            }

                            function complete() {
                                res.json(results);
                            }

                            for(var i=0; i<results.length; i++) {
                                results[i]['checkin_time_parsed'] = standardDateFormat(results[i]['checkin_time'], timezone);
                                results[i]['message'] = constructJsonMessage(results[i]);
                                loadName(results[i]['uid'], i, function(name, index) {
                                    results[index]['name'] = name;
                                    results[index]['uid'] = undefined;
                                });
                            }
                            if(results.length === 0) {
                                res.json([]);
                            }
                        });
                    });
                break;
        }

    }).catch(function(err) {
        res.json(responses.get('AUTH_BAD_TOKEN', {}, err, null, req));
    });
});
router.post('/checkIn/get/resultCount', function(req, res) {
    if(!req.body.token||!req.body.query) {
        res.json(responses.get('AUTH_MISSING_ARGS', {}, null, null, req));
        return;
    }
    admin.auth().verifyIdToken(req.body.token).then(function(decodedToken) {
        var query = req.body.query;
        var flag_request;
        switch(query) {
            case 'your_checkins':
            case 'your_checkin_requests':
                flag_request = query !== 'your_checkins';
                conn.execute(
                    'SELECT COUNT(*) AS entryCount FROM check_in WHERE uid=? AND flag_request=?',
                    [decodedToken.uid, flag_request],
                    function(err, results, fields) {
                        res.json(responses.get('RESULT_COUNT_GET_SUCCESS', {resultCount: parseInt(results[0]['entryCount'])}, null, decodedToken.uid, req));
                    });
                return;
            case 'others_checkins':
            case 'others_checkin_requests':
                flag_request = query !== 'others_checkins';
                conn.execute(
                    'SELECT COUNT(*) AS entryCount FROM check_in_others WHERE recipient_uid=? AND (SELECT flag_request FROM check_in WHERE id=checkin_id)=?',
                    [decodedToken.uid, flag_request],
                    function(err, results, fields) {
                        res.json(responses.get('RESULT_COUNT_GET_SUCCESS', {resultCount: parseInt(results[0]['entryCount'])}, null, decodedToken.uid, req));
                    });
                return;
            default:
                res.json(responses.get('MALFORMED_ARGUMENT', {}, null, decodedToken.uid, req));
                return;
        }
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

        var img_local = 'tmp/' + imageId + '.png';
        fs.writeFile(img_local, req.body.image, 'base64', function(err) {
            if(err) {
                res.json(responses.get('UPLOAD_DATA_MALFORMED', {}, err, decodedToken.uid, req));
            }
            else {
                var img = cacheBucket.file('images/' + imageId);
                fs.createReadStream(img_local)
                    .pipe(img.createWriteStream({
                        metadata: {
                            contentType: 'image/png'
                        }
                    }))
                    .on('error', function(err) {
                        res.json(responses.get('UPLOAD_ERROR', {}, err, decodedToken.uid, req));
                    })
                    .on('finish', function() {
                        fs.unlink(img_local, function(err) {
                            if(err) {
                                res.json(responses.get('UPLOAD_ERROR', {}, err, decodedToken.uid, req));
                                return;
                            }
                            res.json(responses.get('UPLOAD_SUCCESS', {image_id: imageId}, null, decodedToken.uid, req));
                        });
                    });
            }
        });
    });
});

function getRecipients(token, callback, isUid, showDeleted) {
    isUid = isUid || false;
    showDeleted = showDeleted || false;
    function after(uid) {
        conn.execute(
            showDeleted ?
                'SELECT id,name,uid,email,phone_number FROM recipients WHERE owner = ?' :
                'SELECT id,name,uid,email,phone_number FROM recipients WHERE owner = ? AND deleted != TRUE',
            [uid],
            function(err, results, fields) {
                if(err) {
                    callback(err, 'GENERIC_DB_ERROR');
                }
                else {
                    callback(undefined, results);
                }
            });
    }
    if(!isUid) {
        admin.auth().verifyIdToken(token).then(function(decodedToken) {
            after(decodedToken.uid);
        }).catch(function(err) {
            callback('AUTH_BAD_TOKEN', err);
        });
    }
    else {
        after(token);
    }
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
function sendEmails(uid, emails, info, flags, req, callback) {
    var send_time = new Date().getTime();
    admin.auth().getUser(uid).then(function (user) {
        var location = info.location ? JSON.parse(info.location) : null;
        var subject = user.displayName + (flags.REQUEST_CHECKIN ? ' sent a check in request' : ' checked in');

        var emailContent = '';
        emailContent += '<p>' + (info.rating === -1 ? 'No rating was given' : 'Rating: ' + info.rating + ' of 5 stars') + '</p>';
        emailContent += '<p>' + (info.message === null ? 'No message was sent' : 'Message: ' + info.message) + '</p>';
        emailContent += '<p>' + (info.image_id === null ? 'No image was sent' : '<img src="' + global.cacheBucketRoot + '/images/' + info.image_id + '"/>') + '</p>';
        getAttribute(uid, 'timezone', req, function(err, res) {
            if(err) {
                console.log('error: '+res);
            }
            else {
                var timezone = res.value || 'UTC';
                var subject_email = subject + ' at ' + standardTimeFormat(send_time, timezone);

                for(var i=0; i<emails.length; i++) {
                    var emailStr = emails[i];
                    sendEmail(emailStr);
                }

                function sendEmail(emailStr) {
                    Twig.renderFile('./views/email_template.twig', {
                        domain: global.domain,
                        cacheRoot: global.cacheBucketRoot,
                        subject: subject,
                        message: info.message || undefined,
                        image_id: info.image_id || undefined,
                        location: info.location || undefined,
                        location_latitude: location ? location.latitude : undefined,
                        location_longitude: location ? location.longitude : undefined,
                        // date: dateFormat(new Date(), 'mmmm dS, yyyy'),
                        // time: dateFormat(new Date(), 'h:MM TT')
                        date_time: standardDateFormat(send_time, timezone),
                        email_encoded: new Buffer(emailStr).toString('base64')
                    }, function(err, html) {
                        if(err) {
                            console.log(err);
                            return;
                        }
                        email.sendMail({
                            from: 'burnscoding@gmail.com',
                            bcc: emailStr,
                            subject: subject_email,
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
            }
        });
    });
}
function sendPushNotifications(uid, emails, info, checkinId, flag_request, callback) {
    admin.auth().getUser(uid).then(function(user) {
        var title = user.displayName + (flag_request ? ' sent a check in request' : ' checked in');
        var titleSelf = flag_request ? 'You requested a check in' : 'You have checked in';
        var summary = getSummary(user.displayName);
        var summarySelf = getSummary('You');
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

        // if(info.rating !== -1) message += '<p>Rating: ' + info.rating + ' stars</p>';
        var message = constructJsonMessage(info);

        addActivity(user.uid, info.checkinId, titleSelf, summarySelf, message, flag_request ? 'CHECKIN_RS' : 'CHECKIN_S', function(err) {
            if(err) console.log(err);
        });

        for(var email_id = 0; email_id < emails.length; email_id++) {
            var email = emails[email_id];
            admin.auth().getUserByEmail(email)
                .then(function(user) {
                    addActivity(user.uid, info.checkinId, title, summary, message, flag_request ? 'CHECKIN_RR' : 'CHECKIN_R', function(err) {
                        if(err) console.log(err);
                    });
                    if(checkinId !== -1) {
                        conn.execute(
                            'INSERT INTO check_in_others (recipient_uid, checkin_id) VALUES (?, ?)',
                            [user.uid, checkinId],
                            function (err, results, fields) {

                            });
                    }
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
function addActivity(uid, checkinId, title, summary, message, type, callback) {
    conn.execute(
        'INSERT INTO activity (uid, checkin_id, title, summary, message, type) VALUES (?, ?, ?, ?, ?, ?)',
        [uid, checkinId, title, summary, message, type],
        function(err, results, fields) {
            if(err) {
                callback(err);
            }
            else {
                callback();
            }
        });
}
function constructJsonMessage(info) {
    var message = [];
    if(info.message) {
        message.push({
            title: 'Message',
            text: info.message
        });
    }
    if(info.image_id) {
        message.push({
            title: 'Image',
            image_url: global.cacheBucketRoot + '/images/' + info.image_id
        });
    }
    if(info.location) {
        var location = JSON.parse(info.location);
        message.push({
            title: 'Location',
            location: location
        });
    }
    if(info.checkinId) {
        message.push({
            title: 'checkinId',
            value: info.checkinId,
            type: 'hidden'
        })
    }
    if(info.user) {
        message.push({
            title: 'user',
            value: info.user,
            type: 'hidden'
        });
    }

    if(message.length < 1) {
        message.push({
            text: 'No details were provided'
        });
    }
    return message;
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

    var local_map = './tmp/' + center + '.png';
    imageDownloader.image({
        url: url,
        dest: local_map
    }).then(function() {
        var cachedMap = cacheBucket.file('maps/' + center + '.png');
        fs.createReadStream(local_map)
            .pipe(cachedMap.createWriteStream({
                metadata: {
                    contentType: 'image/png'
                }
            }))
            .on('error', function(err) {
                console.log(err);
            })
            .on('finish', function() {
                fs.unlinkSync(local_map);
            });
    });

    return global.cacheBucketRoot + '/maps/' + center + '.png';
}

function standardDateFormat(timestamp, timezone) {
    timezone = timezone || '0:UTC';
    timezone = timezone.split(':');
    return moment(timestamp).add({ hours: parseInt(timezone[0]) }).format('MMMM Do YYYY, h:mm a [(' + timezone[1] + ')]');
}
function conciseDateFormat(timestamp, timezone) {
    timezone = timezone || '0:UTC';
    timezone = timezone.split(':');
    return moment(timestamp).add({ hours: parseInt(timezone[0]) }).format('M/D/YYYY h:mm a');
}
function standardTimeFormat(timestamp, timezone) {
    timezone = timezone || '0:UTC';
    timezone = timezone.split(':');
    return moment(timestamp).add({ hours: parseInt(timezone[0]) }).format('h:mm a');
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
