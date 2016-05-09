require "ruboty/line_bot/version"
require "ruboty/adapters/line_bot"
if ENV['RESPOND_TO_ALL'] == '1'
  require "ruboty/action_tweaks"
end
