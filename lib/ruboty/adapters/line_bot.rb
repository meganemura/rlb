require "rack"
require 'rack/handler/webrick'
require 'line/bot'

module Ruboty
  module Adapters
    class LineBot < Base
      env :LINE_CHANNEL_ID,          "LINE Channel ID"
      env :LINE_CHANNEL_SECRET,      "LINE Channel Secret"
      env :LINE_CHANNEL_MID,         "LINE Channel MID"
      env :LINE_SERVER_BIND_ADDRESS, "Bind address (default: 0.0.0.0)",   :optional => true
      env :LINE_SERVER_PORT,         "Port         (default: 4567)",      :optional => true
      env :LINE_SERVER_ENDPOINT,     "Endpoint     (default: /callback)", :optional => true

      def run
        init
        serve
        main_loop
      end

      def say(message)
        client.send_text(
          to_mid: message[:original][:from_mid],
          text:   message[:body],
        )
      end

      private

      def init
        @queue = Queue.new
        @cached_contacts = {}
      end

      def client
        @client ||= Line::Bot::Client.new do |config|
          config.channel_id     = channel_id
          config.channel_secret = channel_secret
          config.channel_mid    = channel_mid
        end
      end

      def serve
        Thread.new do
          server.start
        end
        Thread.abort_on_exception = true
      end

      def server
        return @server if @server

        @server = WEBrick::HTTPServer.new(server_options)
        @server.mount(endpoint, Rack::Handler::WEBrick, lambda(&method(:callback)))

        @server
      end

      def server_options
        {
          BindAddress: bind_address,
          Port:        port,
          Logger:      Ruboty.logger,
        }
      end

      def callback(env)
        req = Rack::Request.new(env)

        unless req.request_method == 'POST'
          return [404, {}, ['Not found']]
        end

        signature = req.env['HTTP_X_LINE_CHANNELSIGNATURE']

        unless client.validate_signature(req.body.read, signature)
          return [400, {}, ['Bad Request']]
        end

        @queue.enq(req.env)

        [204, {}, []]
      end

      def main_loop
        loop do
          request_from_queue.data.each do |event|
            next unless event.content.is_a?(Line::Bot::Message::Text)

            keys = [:id, :from_mid, :to_mid, :from_channel_id, :to_channel_id, :event_type, :created_time, :content]
            message = keys.each_with_object({}) {|key, hash| hash[key] = event.send(key) }

            contact = cached_contact(message[:from_mid])
            message.update(
              body:      message[:content].content[:text],
              from:      message[:from_mid],
              from_name: contact[:display_name],
              to:        message[:to_mid],
              type:      message[:event_type],
            )
            Ruboty.logger.debug('Received:' + message.inspect)
            robot.receive(message)
          end
        end
      end

      def cached_contact(mid)
        if contact = @cached_contacts[mid]
          contact
        else
          update_contact_cache(mid)
          @cached_contacts[mid]
        end
      end

      def update_contact_cache(mid)
        contact = client.get_user_profile(mid).contacts.first

        @cached_contacts[contact.mid] = {
          mid:            contact.mid,
          display_name:   contact.display_name,
          picture_url:    contact.picture_url,
          status_message: contact.status_message,
        }
      end

      def request_from_queue
        rack_raw_env = @queue.deq
        Line::Bot::Receive::Request.new(rack_raw_env)
      end

      def channel_id
        ENV['LINE_CHANNEL_ID']
      end

      def channel_secret
        ENV['LINE_CHANNEL_SECRET']
      end

      def channel_mid
        ENV['LINE_CHANNEL_MID']
      end

      def bind_address
        ENV['WEBHOOK_BIND_ADDRESS'] || '0.0.0.0'
      end

      def port
        ENV['WEBHOOK_PORT'] || '4567'
      end

      def endpoint
        ENV['WEBHOOK_ENDPOINT'] || '/callback'
      end
    end
  end
end
