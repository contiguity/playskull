class Game
  attr_accessor :user_hash, :player_hash, :playing_user_names, :started, :bid,  :round_order, :turn_queue, :revealer, :disks_placed, :revealer_remove, :disks_for_each_player, :shuffle_names #, :playing_user_names, :started, :all_disks_hash, :placed_disks_hash, mat_flipped

  def initialize
    self.player_hash = {}
    self.user_hash = {}
    self.playing_user_names=[]
    self.started = false
    self.disks_for_each_player=4#default
    self.shuffle_names = true
  end

  def add_user(user)
    user_hash[user.nick]=user unless user_hash.has_key?(user.nick)
  end

  def remove_user(user)
    user_hash.delete(user.nick)
  end

  def setup_game
    self.started=true
    #self.phase=:main
    self.bid=0
    self.playing_user_names=self.user_hash.keys
    self.playing_user_names.shuffle! if self.shuffle_names
    self.revealer_remove=false
  end

  def user_in_started_game?(input_user)
    self.started && self.playing_user_names.include?(input_user.nick)
  end

  def players_joined
    self.user_hash.length
  end

  #def toggle_variant(input_variant)
  #  on_after=!self.variants.include?(input_variant)
  #  if on_after
  #    self.variants.push(input_variant)
  #  else
  #    self.variants.delete(input_variant)
  #  end
  #end

  def get_player_by_user(input_user)
    #current_name=self.playing_user_names.select{|name| self.user_hash[name] == input_user}.first
    current_name=input_user.nick #this uses user.nick, but other places use this too
    return self.player_hash[current_name] #could return nil if user doesn't exist
  end

  def user_in_started_game(input_user)
    self.user_hash.value?(input_user) and self.started
  end
end



class Player
  attr_accessor :name, :user, :all_disks, :table_disks, :remaining_disk_nums, :mat_flipped

  def initialize(num_disks)
    self.all_disks=[:skull]
    self.remaining_disk_nums=[]
    num_disks.times do |disk_num|
      self.all_disks.push(:rose) unless disk_num==0
      self.remaining_disk_nums.push(disk_num.to_s)
    end

    #self.all_disks = [:skull, :rose, :rose, :rose]
    self.all_disks.shuffle
    self.table_disks=[]
    self.mat_flipped = false
  end

  def set_name(input_name)
    self.name=input_name
  end

  def set_user(input_user)
    self.user=input_user
  end

end