var createError = require('http-errors');
var express = require('express');
var path = require('path');
var cookieParser = require('cookie-parser');
var logger = require('morgan');
var mysql = require('mysql2');
var nodemailer = require('nodemailer');
var smtpTransport = require('nodemailer-smtp-transport');
var bodyParser = require('body-parser');
var fs = require('fs');
var GoogleMapsAPI = require('googlemaps');
var gcstorage = require('@google-cloud/storage');

var config = require('./config.json');

if(!fs.existsSync('tmp')) fs.mkdir('tmp');

global.conn = mysql.createConnection({
    host: config.database.host,
    user: config.database.user,
    password: config.database.password,
    database: config.database.database
});
global.email = nodemailer.createTransport(smtpTransport({
    host: config.email.host,
    port: 25,
    auth: {
        user: config.email.user,
        pass: config.email.pass
    }
}));
email.sendMail({
    from: 'thecheckin@burnscoding.com',
    bcc: 'ctrekker4@gmail.com',
    subject: 'Automated message',
    html: '<h2>This is an automated update message</h2><p>Hi Connor, this is thecheckin backend!</p>'
}, function(err, info) {
    if(err) {
        console.log(err);
    }
    else {
        console.log('Mail sent!');
    }
});
global.gmaps = new GoogleMapsAPI({
    key: config.gmaps.key
});
global.gstorage = new gcstorage.Storage({
    projectId: 'health-check-4',
    keyFilename: 'firebase-admin-key.json'
});
global.cacheBucket = gstorage.bucket('the-check-in-cache');
global.cacheBucketRoot = 'https://storage.googleapis.com/the-check-in-cache';
global.domain = config.domain;
conn.connect(function(err) {
    if(err) {
        console.log(err);
        process.exit(1);
    }
    console.log('MySQL database connected');
});

var indexRouter = require('./routes/index');
var userRouter = require('./routes/user');

var app = express();

// view engine setup
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'twig');
app.set('trust proxy', true);

app.use(logger('dev'));
// app.use(express.json());
app.use(bodyParser({limit: '50mb'}));
app.use(express.urlencoded({ extended: true }));
app.use(cookieParser());
app.use(express.static(path.join(__dirname, 'public')));

app.use('/', indexRouter);
app.use('/user', userRouter);

// catch 404 and forward to error handler
app.use(function(req, res, next) {
    next(createError(404));
});

// error handler
app.use(function(err, req, res, next) {
    // set locals, only providing error in development
    res.locals.message = err.message;
    res.locals.error = req.app.get('env') === 'development' ? err : {};

    // render the error page
    res.status(err.status || 500);
    res.render('error');
});

module.exports = app;
