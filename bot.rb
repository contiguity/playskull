require 'cinch'
require './cinch-playskull/lib/cinch/plugins/skullgame'

bot = Cinch::Bot.new do

  configure do |c|
    c.nick            = "skullbot"
    c.server          = "chat.freenode.net"
    c.channels        = ["#playskull"]
    c.verbose         = true
    c.plugins.plugins = [
    Cinch::Plugins::SkullGame
    ]
     c.plugins.options[Cinch::Plugins::SkullGame] = {
        :mods     => ["contig"],
        :channel  => "#playskull",
    }
  end

end

bot.start
