function shallowClone(obj) {
    var out = {};
    var keys = Object.keys(obj);
    for(var i=0; i<keys.length; i++) {
        out[keys[i]] = obj[keys[i]];
    }
    return out;
}

var responses = {
    AUTH_CREATE_SUCCESS: {
        type: 'success',
        code: 'auth/create-success'
    },
    AUTH_DETAILS_SUCCESS: {
        type: 'success',
        code: 'auth/details-success'
    },
    AUTH_MISSING_ARGS: {
        type: 'error',
        code: 'auth/missing-args'
    },
    AUTH_BAD_TOKEN: {
        type: 'error',
        code: 'auth/bad-token'
    },
    AUTH_GETUSER_ERROR: {
        type: 'error',
        code: 'auth/getuser-error'
    },
    ATTRIBUTE_GET_SUCCESS: {
        type: 'success',
        code: 'attr/get-success'
    },
    ATTRIBUTE_SET_SUCCESS: {
        type: 'success',
        code: 'attr/set-success'
    },
    CHECKIN_SUCCESS: {
        type: 'success',
        code: 'checkin/success',
        message: 'You have now checked in'
    },
    CHECKIN_NO_EMAIL_WARNING: {
        type: 'warning',
        code: 'checkin/no-email-warning',
        message: 'No email recipients were provided'
    },
    FCM_UPDATE_SUCCESS: {
        type: 'success',
        code: 'device/fcm-update-success'
    },
    DEVICE_COUNT_OVERFLOW: {
        type: 'error',
        code: 'device/overflow'
    },
    DEVICE_INIT_SUCCESS: {
        type: 'success',
        code: 'device/init-success'
    },
    MALFORMED_ARGUMENT: {
        type: 'error',
        code: 'arg/malformed'
    },
    GENERIC_SUCCESS: {
        type: 'success'
    },
    GENERIC_ERROR: {
        type: 'error'
    },
    GENERIC_DB_ERROR: {
        type: 'error',
        code: 'generic/db-error'
    },
    GENERIC_EMAIL_ERROR: {
        type: 'error',
        code: 'generic/email-error'
    },
    GENERIC_PERMISSIONS_ERROR: {
        type: 'error',
        code: 'generic/permissions-error'
    },
    RECIPIENT_GET_SUCCESS: {
        type: 'success',
        code: 'recipient/get-success'
    },
    RECIPIENT_GET_ERROR: {
        type: 'error',
        code: 'recipient/get-error'
    },
    RECIPIENT_ADD_SUCCESS: {
        type: 'success',
        code: 'recipient/add-success'
    },
    RECIPIENT_REMOVE_SUCCESS: {
        type: 'success',
        code: 'recipient/remove-success'
    },
    ACTIVITY_GET_SUCCESS: {
        type: 'success',
        code: 'activity/get-success'
    },
    UPLOAD_SUCCESS: {
        type: 'success',
        code: 'upload/success'
    },
    UPLOAD_DATA_MALFORMED: {
        type: 'error',
        code: 'upload/malformed-data'
    }
};
module.exports = {
    get: function(id, extra, err, uid, req) {
        var baseResponse = responses[id];
        if(extra) {
            if(Object.keys(extra).length > 0) {
                var keys = Object.keys(extra);
                for(var i=0; i<keys.length; i++) {
                    baseResponse[keys[i]] = extra[keys[i]];
                }
            }
        }

        var response = shallowClone(baseResponse);

        // Make sure everything is null rather than undefined
        err = err || null;
        baseResponse.type = baseResponse.type || null;
        baseResponse.code = baseResponse.code || null;
        if(err) baseResponse.message = baseResponse.message || err.message || err.errorInfo.message || null;
        else baseResponse.message = baseResponse.message || null;
        uid = uid || null;
        req.ip = req.ip || null;

        conn.execute(
            'INSERT INTO response_log (type, code, message, user_id, user_ip, error_raw) VALUES (?, ?, ?, ?, ?, ?)',
            [baseResponse.type, baseResponse.code, baseResponse.message, uid, req.ip, (err)?err.toString():err],
            function(err, results, fields) {
                if(err) {
                    console.log(err);
                }
            });

        return response;
    }
};