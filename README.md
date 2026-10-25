Slack Moji
==========

[![test](https://github.com/dblock/slack-moji/actions/workflows/test.yml/badge.svg)](https://github.com/dblock/slack-moji/actions/workflows/test.yml)

You don't have enough emojis in Slack. Hosted at [moji.playplay.io](https://moji.playplay.io/).

## Install

[![Add to Slack](https://platform.slack-edge.com/img/add_to_slack.png)](https://moji.playplay.io)

### Copyright & License

Copyright [Daniel Doubrovkine, Vestris LLC](https://www.vestris.com), 2019

[MIT License](LICENSE)

### Website assets

Local website assets use `asset_path` from rack-server-pages 0.3; escape HTML URLs with `h asset_path("/img/icon.png")` and use `asset_path("/img/icon.png").to_json` inside JavaScript. Templates and generated CSS revalidate with `private, no-cache` through `SlackRubyBotServer.config.server_pages`. Keep stylesheets with nested local assets as `.css.erb` (served at the original `.css` URL) so artwork changes update their URLs without changing the stylesheet source. Static assets retain the framework content ETag and timestamp defaults; no long-lived caching is enabled.
