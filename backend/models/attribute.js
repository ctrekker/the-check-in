var mongoose = require('mongoose');
var Schema = mongoose.Schema;

var AttributeSchema = new Schema({
    name: String
});
module.exports = mongoose.model('Attribute', AttributeSchema);