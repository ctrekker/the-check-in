var mongoose = require('mongoose');
var Schema = mongoose.Schema;
var ActivitySchema = new Schema({
    user: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    title: String
    summary: String,
    message: String,
    type: String,
    send_timestamp: { type: Date, default: Date.now() }
});
module.exports = mongoose.model('Activity', ActivitySchema);