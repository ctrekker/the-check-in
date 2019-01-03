var mongoose = require('mongoose');
var Schema = mongoose.Schema;

var CheckInSchema = new Schema({
    user: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    checkin_time: { type: Date, default: Date.now(), required: true },
    properties: {
        rating: Number,
        message: String,
        image_id: { type: Schema.Types.ObjectId, ref: 'Image' },
        location: String
    },
    recipients: [{ type: Schema.Types.ObjectId, ref: 'Recipient' }]
});
module.exports = mongoose.model('CheckIn', CheckInSchema);