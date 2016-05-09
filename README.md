# Ruboty::LineBot

LINE BOT API Adapter for [Ruboty](https://github.com/r7kamura/ruboty).

## Usage

```ruby
gem "ruboty-line_bot"
```

## ENV
```
LINE_CHANNEL_ID          - LINE Channel ID
LINE_CHANNEL_SECRET      - LINE Channel Secret
LINE_CHANNEL_MID         - LINE Channel MID
LINE_SERVER_BIND_ADDRESS - Bind address (default: 0.0.0.0)
LINE_SERVER_PORT         - Port         (default: 4567)
LINE_SERVER_ENDPOINT     - Endpoint     (default: /callback)
RESPOND_TO_ALL           - Pass 1 to force ruboty to respond all messages without mention
```
