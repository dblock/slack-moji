$(document).ready(function() {
  // Slack OAuth
  var code = $.url('?code')
  if (code) {
    SlackMoji.message('Working, please wait ...');
    $('#register').hide();
    $.ajax({
      type: "POST",
      url: "/api/teams",
      data: {
        code: code
      },
      success: function(data) {
        SlackMoji.message('Team successfully registered!<br><br>Invite <b>@moji</b> to a channel.');
      },
      error: SlackMoji.error
    });
  }
});
