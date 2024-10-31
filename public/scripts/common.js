var SlackMoji = {};

$(document).ready(function() {

  SlackMoji.message = function(text) {
    $('#messages').fadeOut('slow', function() {
      $('#messages').removeClass('has-error');
      $('#messages').fadeIn('slow').html(text)
  });
};

  SlackMoji.errorMessage = function(text) {
    $('#messages').fadeOut('slow', function() {
        $('#messages').addClass('has-error');
        $('#messages').fadeIn('slow').html(text)
    });
  };

  SlackMoji.error = function(xhr) {
    try {
      var message;
      if (xhr.responseText) {
        var rc = JSON.parse(xhr.responseText);
        if (rc && rc.error) {
          message = rc.error;
        } else if (rc && rc.message) {
          message = rc.message;
          if (message == 'invalid_code') {
            message = 'The code returned from the OAuth workflow was invalid.'
          } else if (message == 'code_already_used') {
            message = 'The code returned from the OAuth workflow has already been used.'
          }
        } else if (rc && rc.error) {
          message = rc.error;
        }
      }

      SlackMoji.errorMessage(message || xhr.statusText || xhr.responseText || 'Unexpected Error');

    } catch(err) {
      SlackMoji.errorMessage(err.message);
    }
  };

});
