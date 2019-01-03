var mongoose = require('mongoose');
var Schema = mongoose.Schema;

var UserSchema = new Schema({
    firebase_uid: { type: String, required: true },
    email: String,
    displayName: String
});
module.exports = mongoose.model('User', UserSchema);