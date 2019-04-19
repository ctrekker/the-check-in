var Twig = require('twig');

Twig.renderFile('./views/checkin_template.twig', {
    display_name: 'Connor',
    message: 'Another test message',
    image_id: 'V52U3gNQB19WLnUGKqrfkieTV1lrnwYi',
    location: '39,-103',
    date: 'January 8, 2018',
    time: '12:40 PM'
}, function(err, html) {
    if(err) {
        console.log(err);
        return;
    }
    console.log(html);
});