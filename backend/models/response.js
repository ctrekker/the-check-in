var mongoose = require('mongoose');
var Schema = mongoose.Schema;

var ResponseSchema = new Schema({
    type: String,
    code: String,
    message: String,
    response_time: { type: Date, default: Date.now(), required: true },
    user: { type: Schema.Types.ObjectId, ref: 'User' },
    user_ip: String,
    error_raw: String
});
module.exports = mongoose.model('Response', ResponseSchema);