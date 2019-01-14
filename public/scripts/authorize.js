$(document).ready(function() {
  // Slack OAuth for a user
  var code = $.url('?code')
  var id = $.url('?state')
  if (code && id) {
    SlackMoji.message('Working, please wait ...');
    $.ajax({
      type: "PUT",
      url: "/api/users/" + id,
      data: {
        code: code
      },
      success: function(data) {
        SlackMoji.message('User successfully authorized!');
      },
      error: SlackMoji.error
    });
  }
});
