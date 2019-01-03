var mongoose = require('mongoose');
var Schema = mongoose.Schema;

var FCMTokenSchema = new Schema({
    device: { type: Schema.Types.ObjectId, ref: 'Device', required: true },
    user: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    token: { type: String, required: true },
    update_timestamp: { type: Date, default: Date.now(), required: true }
});
module.exports = mongoose.model('FCMToken', FCMTokenSchema);