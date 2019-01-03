var mongoose = require('mongoose');
var Schema = mongoose.Schema;

var RecipientSchema = new Schema({
    owner: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    user: { type: Schema.Types.ObjectId, ref: 'User' },
    phone_number: String,
    email: String,
    name: String,
    deleted: { type: Boolean, default: false, required: true }
});
module.exports = mongoose.model('Recipient', RecipientSchema);