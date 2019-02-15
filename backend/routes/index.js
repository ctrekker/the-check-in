var express = require('express');
var router = express.Router();
var path = require('path');
var admin = require('firebase-admin');
var request = require('request');

/* GET home page. */
router.get('/', function(req, res, next) {
    res.send('/');
});
router.get('/get-app', function(req, res) {
    res.render('app_not_available.twig', {});
});
router.get('/about-emails', function(req, res) {
    res.render('about_emails.twig', {});
});
router.get('/unsubscribe', function(req, res) {
    res.render('unsubscribe.twig', {});
});
router.post('/unsubscribe', function(req, res) {
    var email_encoded = req.body.email_encoded;
    var somethingWentWrongMessage = {
        title: 'Unsubscribe Error',
        message: 'Something went wrong while attempting to unsubscribe your email address. Please try again the next time you get an email from us.'
    };
    if(!email_encoded) {
        res.render('unsubscribe_fail.twig', somethingWentWrongMessage);
    }
    else {
        var email = new Buffer(email_encoded, 'base64').toString('ascii');
        conn.execute(
            'INSERT INTO email_blacklist (email) VALUES (?)',
            [email],
            function(err, results, fields) {
                if(err) {
                    res.render('unsubscribe_fail.twig', somethingWentWrongMessage);
                    return;
                }
                admin.auth().getUserByEmail(email).then(function(user) {
                    res.render('unsubscribe_fail.twig', {
                        title: 'Unable to Unsubscribe',
                        message: 'You cannot forcefully unsubscribe since you have a Check In account attached to this email. To unsubscribe, visit \'Settings\' in The Check In app and uncheck \'Receive emails from us\''
                    });
                }).catch(function(err) {
                    res.render('unsubscribe_success.twig');
                });
            });
    }
});
router.post('/unsubscribe-feedback', function(req, res) {
    console.log(req.body);

    res.send('');

    var reason = req.body.reason;
    if(reason.length < 100) {
        reason = reason.substring(0, 100);
    }
    conn.execute(
        'INSERT INTO feedback (type, message) VALUES (\'unsubscribe\', ?)',
        [reason],
        function (err, results, fields) {

        });
});
// NOTE: Does not get user settings, but rather the global settings form
router.post('/settings/get', function(req, res) {
    res.sendFile(path.resolve('./views/settings_form.json'));
});

module.exports = router;
