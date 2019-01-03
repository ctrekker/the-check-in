var mongoose = require('mongoose');
var Schema = mongoose.Schema;

var DeviceSchema = new Schema({
    user: { type: Schema.Types.ObjectId, ref: 'User', required: true }
});
module.exports = mongoose.model('Device', DeviceSchema);