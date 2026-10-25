$(document).ready(function() {
  // Slack OAuth
  var code = $.url('?code')
  if (code) {
    SlackMoji.message('Working, please wait ...');
    $('#homepage').hide();
    $('#register').show();
    $.ajax({
      type: "POST",
      url: "/api/teams",
      data: {
        code: code
      },
      success: function(data) {
        SlackMoji.message('Team successfully registered!<br><br>Try <b>/moji me</b> to add emoji to your profile.');
      },
      error: SlackMoji.error
    });
  }
});
