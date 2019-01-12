var express = require('express');
var router = express.Router();
var path = require('path');

/* GET home page. */
router.get('/', function(req, res, next) {
    res.send('/');
});
// NOTE: Does not get user settings, but rather the global settings form
router.post('/settings/get', function(req, res) {
    res.sendFile(path.resolve('./views/settings_form.json'));
});

module.exports = router;
