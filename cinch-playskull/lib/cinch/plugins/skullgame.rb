require 'cinch'
require 'set'

require_relative 'game'

$pm_users = Set.new

module Cinch

  class Message
    old_reply = instance_method(:reply)

    define_method(:reply) do |*args|
      if self.channel.nil? && !$pm_users.include?(self.user.nick)
        self.user.send(args[0], true)
      else
        old_reply.bind(self).(*args)
      end
    end
  end

end

module Cinch

  class User
    old_send = instance_method(:send)

    define_method(:send) do |*args|
      old_send.bind(self).(args[0], !$pm_users.include?(self.nick))
    end
  end

  module Plugins

    class SkullGame
      include Cinch::Plugin

      def initialize(*args)
        super
        @active_game = Game.new
        @channel_name = config[:channel]
      end

      match /join/i, :method => :join
      match /leave/i, :method => :leave
      match /start/i, :method => :start

#      match /disks/i, :method => :reply_with_disk_choices
      match /diskcount (\d)/, :method=> :set_disk_count
      match /shuffle/, :method => :set_shuffle

      match /place (\d)/i, :method => :place_disk
      match /play (\d)/i, :method => :place_disk
      match /raise$/i, :method => :raise_bid
      match /raise (\d+)/i, :method => :raise_bid_number
      match /bid$/i, :method => :raise_bid
      match /bid (\d+)/i, :method => :raise_bid_number


      match /pass/i, :method => :pass_bid
      match /flip (.+)/i, :method => :flip_single
      match /remove (\d)/i, :method => :remove_chosen_disk

      match /help/i, :method => :help
      match /rules/i, :method => :rules
      match /who/i, :method => :show_players_in_game

      match /nextround/i, :method => :nextround
      match /forcereset/i, :method => :forcereset
      match /reset/i, :method => :forcereset #all players can reset if they're in the game
      match /infodebug/i, :method => :info
      match /status/i, :method => :status


      def help(m)
        User(m.user).send '--------Basic commands--------'
        User(m.user).send '!help to see this help screen'
        User(m.user).send '!join to join a game'
        User(m.user).send '!leave to leave a game'
        User(m.user).send '!start to start a game'
        User(m.user).send '----------------'
        User(m.user).send '!place [num] to place a disk (see your private message for numbers)'
        User(m.user).send '!bid [num] to bid'
        User(m.user).send '!bid to bid the next higher number'
        User(m.user).send '!pass to pass'
        User(m.user).send '!flip [name] to flip another players disk (yours are autoflipped'
        User(m.user).send '!remove [num] to remove a disk if you autoflipped a skull'
        User(m.user).send '----------------'
      end

      def rules(m)
        User(m.user).send '--------Basic rules--------'
        User(m.user).send 'Based on skull, players have 4 disks (3 roses and 1 skull)'
        User(m.user).send 'On a players turn, they choose and place a disk face down'
        User(m.user).send 'A player may choose to start bidding instead of placing a disk'
        User(m.user).send 'From then on, players must increase the bid if they want to continue'
        User(m.user).send 'If a player passes, they are out of the bidding.'
        User(m.user).send 'The last player in the bidding is the revealer'
        User(m.user).send '--------Revealing disks--------'
        User(m.user).send 'A player wants to reveal as many disks as the bid, without flipping a skull'
        User(m.user).send 'The first disks the player flips must be their own.'
        User(m.user).send 'If no skull, then one by one, they flip disks of other players.'
        User(m.user).send 'If they succeed in flipping only flowers, they flip their mat over'
        User(m.user).send 'If their mat was already flipped, they win instead, and the game is over.'
        User(m.user).send '--------Losing disks--------'
        User(m.user).send 'If a player flips over one of their own disks as a skull'
        User(m.user).send 'then the player may choose which disk of theirs to remove from the game'
        User(m.user).send 'If a player flips over another players skull, it is randomly chosen'
        User(m.user).send 'A player with no disks is out of the game.'
        User(m.user).send '(If only one player remains, that player wins)'
        User(m.user).send '----------------'
      end

      def join(m)
        if @active_game.started
          User(m.user).send 'Game already started'
        elsif @active_game.user_hash.include?(m.user.nick)
          Channel(@channel_name).send " #{m.user.nick} already joined. Game has #{@active_game.players_joined} player(s)."
        else
          @active_game.add_user(m.user)
          Channel(@channel_name).send " #{m.user.nick} joined. Game now has #{@active_game.players_joined} player(s)."
        end
      end

      def leave(m)
        if @active_game.started
          User(m.user).send 'Game already started'
        else
          @active_game.remove_user(m.user)
          Channel(@channel_name).send "#{m.user.nick} left. Game now has #{@active_game.players_joined} player(s)."
        end
      end

      def show_players_in_game() #m
        Channel(@channel_name).send "Players in game: #{@active_game.user_hash.keys.join(', ')}"
      end


      def set_disk_count(m,num_disks_input)
        if @active_game.started
          User(m.user).send "Game already started"
          return
        end
        num_disks=num_disks_input.to_i
        if (num_disks<=0)
         User(m.user).send "Invalid number of disks chosen"
          return
        elsif (num_disks>5)
          User.(m.user).send "Maximum 5 disks for each player"
          return
        end
        @active_game.disks_for_each_player=num_disks
        User(m.user).send "Preparing #{num_disks} disks for each player."
      end

      def set_shuffle(m)
        if @active_game.shuffle_names
            @active_game.shuffle_names=false
            Channel(@channel_name).send "Shuffling play order is off"
        else
          @active_game.shuffle_names=true
          Channel(@channel_name).send "Shuffling play order is on"
        end
      end

      def start(m)
        if @active_game.started
          User(m.user).send 'Game has started already'
        elsif @active_game.players_joined<2
          User(m.user).send 'Need at least 2 players'
        else

          @active_game.setup_game

          @active_game.user_hash.keys.each do |single_name|
            current_player=Player.new(@active_game.disks_for_each_player)
            current_player.set_name(single_name)
            current_player.set_user(@active_game.user_hash[single_name])
            @active_game.player_hash[single_name]=current_player
          end

          Channel(@channel_name).send "Game has started with #{@active_game.playing_user_names.join(', ')}."
          Channel(@channel_name).send "Use !place to start placing."

          @active_game.round_order=@active_game.playing_user_names.dup
          @active_game.turn_queue=@active_game.round_order.dup

          self.start_round()
        end
      end

      def nextround(m)
        self.start_round
      end

      def start_round
        return if !@active_game.started #may try to start round after game has been won
        round_order_string=@active_game.round_order.join(', ')
        Channel(@channel_name).send "A new round has started (Turn order is #{round_order_string})."

        @active_game.turn_queue=@active_game.round_order.dup
        @active_game.bid=0
        @active_game.disks_placed=0

        @active_game.user_hash.keys.each do |single_name|
          single_player=@active_game.player_hash[single_name]
          single_player.all_disks.shuffle!
          single_player.table_disks=[]
          max_disk_num=single_player.all_disks.length-1
          puts "Player #{single_player} is has 0 to #{max_disk_num} disks"
          single_player.remaining_disk_nums=(0..max_disk_num).to_a.map! { |num| num.to_s }
          puts "Player has disks #{single_player.remaining_disk_nums}"
        end

        @active_game.revealer=nil
        @active_game.revealer_remove=false

        @active_game.user_hash.values.each { |single_user| puts "Showing disk choices for #{single_user.nick}" }

        @active_game.user_hash.values.each { |single_user| self.reply_with_disk_choices(single_user) }

      end

      def reply_with_disk_choices(input_user)
        #current_user=@active_game.user_hash[input_name]
        current_name=input_user.nick
        current_player=@active_game.player_hash[current_name]

        total_disks=current_player.all_disks.length-1 #top disk number
        puts "===Replying with #{total_disks} for #{current_name}"

        disk_message=(0..total_disks).collect{ |num|
          if (current_player.remaining_disk_nums.include?(num.to_s) || @active_game.revealer_remove)
             "#{num} #{current_player.all_disks[num]}"
          else
             "#{num}"
          end
        }.join(", ")
        puts "Trying to send message #{disk_message}"
        input_user.send("===#{disk_message}===")
      end

      def place_disk(m, num)
        #Channel(@channel_name).send "Got place command for #{num} from #{m.user.nick}"
        return unless @active_game.user_in_started_game(m.user)
        current_player_name=@active_game.turn_queue[0]
        if current_player_name!=(m.user.nick)
          Channel(@channel_name).send "It isn't your turn. Wait for #{current_player_name}"
          return
        elsif @active_game.bid >0
          Channel(@channel_name).send "Can no longer play disks; use !raise to raise the bid"
          return
        else
          current_player=@active_game.get_player_by_user(m.user)

          if num.to_i>=current_player.all_disks.length
            Channel(@channel_name).send "You don't have that many disks."
          elsif current_player.remaining_disk_nums.include?(num)
            disk_to_place=current_player.all_disks[num.to_i]
            current_player.table_disks.push(disk_to_place)
            current_player.remaining_disk_nums.delete(num)
            @active_game.disks_placed+=1
            puts "Played disk #{num.to_i}" #shows the chosen disk
            self.make_next_turn()

          else
            Channel(@channel_name).send "You already played disk #{num}"
            puts "Can't place disk #{num}, only have disks #{current_player.remaining_disk_nums}"
          end

        end
      end


      def raise_bid_number(m, input_bid)
        return unless @active_game.user_in_started_game(m.user)
        current_player_name=@active_game.turn_queue[0]
        new_bid=input_bid.to_i
        if current_player_name!=(m.user.nick)
          Channel(@channel_name).send "It isn't your turn. Wait for #{current_player_name}"
          return
        elsif @active_game.disks_placed==0
          Channel(@channel_name).send "There are no disks out. Use !place [number] to place a disk."
          return
        elsif new_bid<=@active_game.bid
          Channel(@channel_name).send "The current bid is #{@active_game.bid}; you must go higher"
          return
        elsif new_bid>@active_game.disks_placed
          Channel(@channel_name).send "There are only #{@active_game.disks_placed} disks, so you can't bid more than #{@active_game.disks_placed}."
          return
        else
          @active_game.bid=new_bid
          Channel(@channel_name).send "Player #{m.user.nick} bids #{@active_game.bid}"
          make_next_turn()
        end
      end

      def raise_bid(m)
        self.raise_bid_number(m, @active_game.bid+1) #raise_bid is another name for this
      end

      def remove_name_and_check_for_win(player_name)
        @active_game.round_order.delete(player_name)
        Channel(@channel_name).send "Player #{player_name} is out of the game!"
        if @active_game.round_order.length==1
          Channel(@channel_name).send "Player #{@active_game.round_order.pop} wins!"
          self.reset_game
        elsif @active_game.round_order.length<1
          Channel(@channel_name).send "No one is playing!"
        end
      end

      def make_next_turn()
        previous_player_name=@active_game.turn_queue.shift
        @active_game.turn_queue.push(previous_player_name)
        new_turn_name=@active_game.turn_queue[0]
        self.reply_with_disk_choices(@active_game.user_hash[new_turn_name])
        Channel(@channel_name).send "Turn: #{new_turn_name}, Bid: #{@active_game.bid}"
      end

      def pass_bid(m)
        ##nick?
        return unless @active_game.user_in_started_game(m.user)

        current_player_name=@active_game.turn_queue[0]
        if current_player_name!=(m.user.nick)
          Channel(@channel_name).send "It isn't your turn. Wait for #{current_player_name}"
          return
        end

        make_next_turn()
        @active_game.turn_queue.delete(m.user.nick)
        if @active_game.turn_queue.length>1
          Channel(@channel_name).send "Player #{m.user.nick} passes." #Use !reveal (name) to identify
          return
        elsif @active_game.turn_queue.empty?
          Channel(@channel_name).send "Somehow unsure who is revealing." #Use !reveal (name) to identify
          return
        end
        #Here, revealing begins

        @active_game.revealer=@active_game.turn_queue.pop

        revealer_player=@active_game.player_hash[@active_game.revealer]
        revealer_index=@active_game.round_order.find_index(@active_game.revealer)
        @active_game.round_order.rotate!(revealer_index) unless revealer_index.nil? #rotate so revealer goes first

        if @active_game.bid< revealer_player.table_disks.length
          revealed_disks=revealer_player.table_disks.pop(@active_game.bid)
        else
          revealed_disks=revealer_player.table_disks.dup
        end
        Channel(@channel_name).send "All other players pass..."

        sleep(1)

        Channel(@channel_name).send "Player #{@active_game.revealer} reveals #{revealed_disks.join(', ')}."
        if revealed_disks.include?(:skull)
          Channel(@channel_name).send "Player #{@active_game.revealer} removes a disk."
          revealer_player.all_disks.shuffle! #player shuffles disks before looking and removing one
          @active_game.revealer_remove=true
          self.reply_with_disk_choices(@active_game.user_hash[@active_game.revealer])
          if revealer_player.all_disks.length<=1
            remove_name_and_check_for_win(@active_game.revealer)
            self.start_round
            return
          end
          Channel(@channel_name).send "(Use !remove (number) to remove a disk from the above choices.)"

        else
          Channel(@channel_name).send "No skull revealed."
          @active_game.bid -= revealed_disks.length
          check_for_bid_completed
        end

      end

      def remove_chosen_disk(m, input_number)
        return unless @active_game.user_in_started_game(m.user)
        if !@active_game.revealer_remove
          Channel(@channel_name).send "Wait for a skull to be revealed to remove a disk."
          #return
        elsif m.user.nick!=@active_game.revealer
          Channel(@channel_name).send "Only the revealer #{@active_game.revealer} can remove a disk."
          #return
        else
          revealer_player=@active_game.player_hash[@active_game.revealer]
          num_disks=revealer_player.all_disks.length
          disk_number=input_number.to_i
          if disk_number<0 or disk_number>num_disks
            Channel(@channel_name).send "Choose a number from 0 to #{num_disks-1}"
            return
          end
          revealer_player=@active_game.player_hash[@active_game.revealer]
          chosen_disk=revealer_player.all_disks.delete_at(disk_number)
          m.user.send("You removed #{chosen_disk}")
          @active_game.revealer_remove=false
          if num_disks==1
            remove_name_and_check_for_win(@active_game.revealer)
          end
          self.start_round #if game is over, won't start
        end
      end


      def flip_single(m, target_player)
        return unless @active_game.user_in_started_game(m.user)
        if @active_game.revealer.nil?
          Channel(@channel_name).send "Flipping disks happens when one player remains. Use !place, !raise, or !pass."
          return
        elsif m.user.nick!=@active_game.revealer
          Channel(@channel_name).send "Only the current revealer (#{@active_game.revealer}) can flip disks"
          return
        elsif @active_game.player_hash[target_player].nil?
          Channel(@channel_name).send "Player #{target_player} is not in the game."
          return
        end

        disk_flipped=@active_game.player_hash[target_player].table_disks.pop

        if disk_flipped.nil?
          Channel(@channel_name).send "Player #{target_player} has no disks remaining."
          return
        end
        Channel(@channel_name).send "Revealer #{@active_game.revealer} flips..."
        sleep(1)
        if disk_flipped==:skull
          Channel(@channel_name).send "...a SKULL from #{target_player}!"
          revealer_player=@active_game.player_hash[@active_game.revealer]
          disk_removed=revealer_player.all_disks.shuffle!.pop
          m.user.send("A disk (#{disk_removed}) was randomly removed.")
          disks_left=revealer_player.all_disks.length
          if disks_left>0
            Channel(@channel_name).send "Player #{@active_game.revealer} has #{disks_left} disks left."
          else
            remove_name_and_check_for_win(@active_game.revealer)
          end
          self.start_round()

        else
          Channel(@channel_name).send "...a ROSE from #{target_player}."
          @active_game.bid-=1
          check_for_bid_completed()
        end

      end

      def check_for_bid_completed
        if @active_game.bid>0
          Channel(@channel_name).send "Flip #{@active_game.bid} more disks."
          return
        end

        Channel(@channel_name).send "Revealer #{@active_game.revealer} has made the bid!."
        revealer_player=@active_game.player_hash[@active_game.revealer]
        if revealer_player.mat_flipped
          Channel(@channel_name).send "Revealer #{@active_game.revealer} has won!"
          self.reset_game
        else
          Channel(@channel_name).send "Revealer now has a flipped mat."
          revealer_player.mat_flipped=true
          self.start_round()
        end
      end


      def forcereset(m)
        #only users in the game can reset it
        self.reset_game if @active_game.user_in_started_game?(m.user)
      end

      def reset_game
        @active_game=Game.new
        Channel(@channel_name).send "The game has been reset."
      end


      def status(m)
        return unless @active_game.user_in_started_game(m.user)

        Channel(@channel_name).send "Current player #{@active_game.turn_queue[0]}"
        Channel(@channel_name).send "Player order #{@active_game.turn_queue}"
        Channel(@channel_name).send "Players are seated as #{@active_game.round_order}"
        Channel(@channel_name).send "Bid is #{@active_game.bid}"
        @active_game.playing_user_names.each do |single_name|
          num_disks_played=@active_game.player_hash[single_name].table_disks.length
          Channel(@channel_name).send "Player #{single_name} has played #{num_disks_played} disks"
        end

        if @active_game.revealer.nil?
          Channel(@channel_name).send "(No revealer yet)"
        else
          Channel(@channel_name).send "Revealer is #{@active_game.revealer}"
        end
        if @active_game.revealer_remove
          Channel(@channel_name).send "Waiting for a disk to be removed."
          Channel(@channel_name).send "Use !remove [num] to remove a disk."
        end

      end

      def info(m) #this gives spoilers, so use for debugging
        return unless @active_game.user_in_started_game(m.user)

        self.status(m)
        @active_game.playing_user_names.each do |single_name|
          disks_string=@active_game.player_hash[single_name].table_disks.join(', ')
          Channel(@channel_name).send "Player #{single_name} has played disks #{disks_string}"
          disks_left_string=@active_game.player_hash[single_name].remaining_disk_nums.join(', ')
          Channel(@channel_name).send "Player #{single_name} has disks #{disks_left_string}"
        end
      end

      def show_players_in_game(m)
        Channel(@channel_name).send "#{players_string=@active_game.user_hash.keys.join(', ')}"
      end

    end
  end
end