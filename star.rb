require_relative "const"

class BoardSpace
  include CConst

  attr_accessor :x, :y
  attr_accessor :star

  @@board_empty_spaces = Array.new(CConst::BOARD_X) { Array.new(CConst::BOARD_Y) { true } }

  def self.board_empty_spaces
    @@board_empty_spaces
  end

  def initialize(star = ".", x = -1, y = -1)
    @star = star
  end

  def tf_disp
    tfs = @@task_forces[PLAYER].compact.reject { |tf| (tf.x != @x) || (tf.y != @y) }

    case tfs.length
    when 0
      " "
    when 1
      tfs[0].name
    else
      "*"
    end
  end

  def enemy_disp
    star = @@stars.reject { |star| (star.x != @x) || (star.y != @y) }.first

    if star && star.tf_conflict?
      "!"
    elsif star && star.colony?(PLAYER)
      "@"
    elsif star.nil? || star.visit[PLAYER]
      " "
    else
      "?"
    end
  end

  def to_s
    "#{enemy_disp}#{@star}#{tf_disp}"
  end
end

class Star < BoardSpace
  attr_accessor :enemy_arrivals, :enemy_departures, :player_arrivals
  attr_accessor :visit
  attr_accessor :planets
  attr_accessor :task_forces

  def initialize(star = "_")
    super(star)

    @enemy = "?"

    @enemy_arrivals = false
    @enemy_departures = false
    @player_arrivals = false

    @visit = Array.new(2) { false }

    begin
      @x = rand(CConst::BOARD_X)
      @y = rand(CConst::BOARD_Y)
    end until self.class.board_empty_spaces[@x][@y]
    self.class.board_empty_spaces[@x][@y] = false

    assign_planets

    @task_forces = Array.new(2) { Array.new }

    @@stars << self
  end

  def tf_conflict?
    @task_forces[PLAYER].any? && @task_forces[ENEMY].any? && (any_bc?(PLAYER) || any_bc?(ENEMY))
  end

  def any_bc?(team)
    @task_forces[team].collect { |tf| tf.dest && tf.has_weapons? }.reject { |w| false }.any?
  end

  def distance_to(star)
    (Math.sqrt((star.x - @x)**2 + (star.y - @y)**2)).round
  end

  def reachable_stars
    @@stars.reject { |star| (star.distance_to(self) > @@enemy.r) || (star == self) }
  end

  def random_reachable_star
    rs = reachable_stars
    rs[rand(rs.length)]
  end

  def name
    to_s[1]
  end

  def summary
    printf "\n\n----- star %c -----\n", name
    @task_forces[PLAYER].each { |tf| puts tf.to_s if tf.sum_all_ships > 0 }
    if @task_forces[PLAYER].any? || colony?(PLAYER)
      @task_forces[ENEMY].each { |tf| print("#{tf.to_s}\n") if tf.sum_all_ships > 0 }
    end
    @planets.any? ? @planets.each { |planet| puts planet } : print("no usable planets\n")
  end

  def colony?(team)
    @planets.reject { |planet| planet.team != team }.any?
  end

  def colonies(team)
    @planets.reject { |planet| planet.team != team }.count
  end

  def present?(team)
    @task_forces[team].reject { |tf| tf.dest != self }.any? || colony?(team)
  end

  def under_defended?
    result = false
    @planets.each do |planet|
      if ( (planet.team == ENEMY) && (planet.iu > 10) && ( (6 * planet.amb + planet.mb) < (planet.iu / 15).round ))
        result = true
        break
      end
    end
    return result
  end

  def depart
    @enemy_departures = true if present?(PLAYER)
  end

  def revolt
    @planets.each do |planet|
      next if (planet.team == NONE) || !planet.conquered?

      if (planet.team == PLAYER) && !any_bc?(PLAYER)
        loses = PLAYER
        gets_back = ENEMY
      elsif (planet.team == ENEMY) && !any_bc?(ENEMY)
        loses = ENEMY
        gets_back = PLAYER
      else
        loses = NONE
      end

      if loses != NONE
        planet.team = gets_back
        planet.conquered = false
        planet.psee_capacity = planet.capacity
      end
    end # each planet
  end # revolt

  def display_forces(en_tf, pl_tf)
    en_forces = 0
    pl_forces = 0

    @battle = true

    en_tf.delete if en_tf.sum_all_ships == 0
    pl_tf.delete if pl_tf.sum_all_ships == 0

    en_forces = weapons(ENEMY)  * en_tf.forces if en_tf.dest == self
    pl_forces = weapons(PLAYER) * pl_tf.forces if pl_tf.dest == self

    @battle = false if (en_tf.dest != self) || (pl_tf.dest != self) || (en_forces == 0 && pl_forces == 0)

    summary

    if @battle
      @enodds = pl_forces.to_f / (en_forces + en_tf.t + en_tf.s * 2)
      @enodds = [14.0, @enodds].min
      @enodds = Math.exp(Math.log(0.8) * @enodds)

      @plodds = en_forces.to_f / (pl_forces + pl_tf.t + pl_tf.s * 2)
      @plodds = [14.0, @plodds].min
      @plodds = Math.exp(Math.log(0.8) * @plodds)

      printf "enemy  %5d", en_forces
      en_forces > 0 ? printf("(weap %2d)", @@enemy.w)  : print("         ")
      printf "sur: %4.0f\n", @enodds * 100

      printf "player %5d", pl_forces
      pl_forces > 0 ? printf("(weap %2d)", @@player.w) : print("         ")
      printf "sur: %4.0f\n", @plodds * 100
    end
  end # display_forces

  def tf_battle
    @enodds = 0
    @plodds = 0
    @battle = false

    while @task_forces[PLAYER].length > 1
      @task_forces[PLAYER][0].join_silent(@task_forces[PLAYER][1])
    end

    en_tf = @task_forces[ENEMY][0]
    pl_tf = @task_forces[PLAYER][0]

    display_forces(en_tf, pl_tf) # sets battle, enodds and plodds based on task forces
    pause

    first = true

    while @battle
      begin
        print " Enemy  losses:"
        ene_no_loss_t = en_tf.lose("t", @enodds)
        ene_no_loss_s = en_tf.lose("s", @enodds)
        ene_no_loss_c = en_tf.lose("c", @enodds)
        ene_no_loss_b = en_tf.lose("b", @enodds)
        ene_no_loss = ene_no_loss_t && ene_no_loss_s && ene_no_loss_c && ene_no_loss_b
        print " (none)" if ene_no_loss

        print "\n Player losses:"
        pla_no_loss_t = pl_tf.lose("t", @plodds)
        pla_no_loss_s = pl_tf.lose("s", @plodds)
        pla_no_loss_c = pl_tf.lose("c", @plodds)
        pla_no_loss_b = pl_tf.lose("b", @plodds)
        pla_no_loss = pla_no_loss_t && pla_no_loss_s && pla_no_loss_c && pla_no_loss_b
        print " (none)" if pla_no_loss

        printf "\n*DBG* %s", en_tf
        printf "\n*DBG* %s\n", pl_tf
      end while (!first && ene_no_loss && pla_no_loss)

      first = false

      display_forces(en_tf, pl_tf)

      if @battle
        # withdraw the bad guys
        if pl_tf.has_weapons?
          team = NONE
          size = 0
          @planets.each do |planet|
            if planet.capacity > size
              size = planet.capacity
              team = planet.team
            end
          end

          new_tf = TaskForce.new(ENEMY, self, t: en_tf.t, s: en_tf.s)

          # completely withdraw?
          if ( ((@enodds < 0.7) && (size < 30)) || ((@enodds < 0.5) && (team == PLAYER)) || ((@enodds < 0.3) && (size < 60)) || (@enodds < 0.2) )
            new_tf.c = en_tf.c
            new_tf.b = en_tf.b
          end

          if new_tf.sum_all_ships > 0
            dest = random_reachable_star
            new_tf.dest = dest
            new_tf.eta = ((distance_to(dest) - 0.01) / @@enemy.v).to_i + 1
            new_tf.xf = @x
            new_tf.yf = @y
          else
            new_tf.delete
          end

          fin = false
          begin
            print "B? "
            input = get_chr.upcase
            print "\n"

            case input
            when "M"
              Conquest.draw
            when "H"
              help(2)
            when "S"
              @@player.star_summary
            when "T"
              @@player.tf_summary
            when "C"
              @@player.print_col
            when "?"
              # noop
            when "R"
              @@player.show_resources
            when "O"
              display_forces(en_tf, pl_tf)
            when "W"
              print " ships: "
              new_tf = @@player.split_tf(pl_tf, gets.chomp.upcase.split)
              new_tf.set_des
              # on error join the new tf silently back to pl_tf, else...
              new_tf.withdrew = true
              display_forces(en_tf, pl_tf)
            when " ", "G"
              fin = true
            else
              print "!illegal command"
            end
          end while !fin && @battle

          if new_tf.dest
            print "en withdraws "
            new_tf.disp_tf

            en_tf.t -= new_tf.t
            en_tf.s -= new_tf.s
            en_tf.c -= new_tf.c
            en_tf.b -= new_tf.b

            en_tf.delete if en_tf.sum_all_ships == 0

            display_forces(en_tf, pl_tf)

            pause
          end
        end # if player tf has weapons
      end # if battle
    end # while battle

    revolt
  end # tf_battle

  def enemy_attack
    # first = Array.new(7) { true }

    en_tf = @task_forces[ENEMY][0]

    begin
      attack_factors = en_tf.c + 6 * en_tf.b

      best_planet = nil
      best_score = 1000

      @planets.select { |planet| planet.team == PLAYER }.each do |planet|
        odds = planet.esee_def.to_f / attack_factors
        if planet.capacity > 30
          odds = (odds - 2) * planet.capacity
        else
          odds = (odds - 1.5) * planet.capacity
        end
        if odds < best_score
          best_score = odds
          best_planet = planet
        end
      end

      if best_score < 0
        printf "\nEnemy attacks: %c%d", name, best_planet.number
        summary
        pause
        best_planet.fire_salvo(ENEMY, en_tf)
        en_tf.delete if en_tf.sum_all_ships == 0
        best_planet.esee_def = best_planet.mb + 6 * best_planet.amb
        # pause
      end
    end while (best_score < 0) && any_bc?(ENEMY)

    revolt
  end # enemy_attack

  def player_attack
    @battle = any_bc?(PLAYER)

    if @battle
      print "\nAttack at star #{name}"

      while @battle
        summary

        print "P? "

        input = get_chr.upcase

        case input
        when "S"
          @@player.star_summary
        when "M"
          Conquest.draw
        when "H"
          help(3)
          pause
        when "N"
          @@player.make_tf
        when "J"
          @@player.join_tf
        when "C"
          # print_col
        when "R"
          @@player.show_resources
        when "T"
          @@player.tf_summary
        when "G", " "
          play_salvo
        when "B"
          print "break off attack\n"
          @battle = false
        else
          print " !illegal command"
        end # case
      end # while @battle

      @planets.each { |planet| planet.under_attack = false }

      print "\nPlanet attack concluded"

      revolt
    end # if @battle
  end # player_attack

  def play_salvo
    print "Attack planet "

    planet = nil

    if colonies(ENEMY) > 1
      print ":"
      planet_num = get_chr.ord - 48
      planet_arr = @planets.reject { |planet| planet.number != planet_num }
      if planet_arr.empty?
        print "! That is not a usable planet"
      elsif planet_arr.first.team != ENEMY
        print " !Not an enemy colony"
      else
        planet = planet_arr.first
      end
    else # only one enemy colony? Could be zero?
      planet_arr = @planets.reject { |planet| planet.team != ENEMY }
      if planet_arr.any?
        planet = planet_arr.first
        printf "%d", planet.number
      end
    end

    if planet
      print " attacking tf "

      tf = nil

      if @task_forces[PLAYER].length > 1
        print ":"
        tf = tf_from_chr(PLAYER, get_chr)
      else
        tf = @task_forces[PLAYER].first if @task_forces[PLAYER].any?
      end

      if tf.nil?
        print " !Illegal  tf\n"
      elsif tf.dest.nil?
        print " !Nonexistent tf\n"
      elsif (tf.dest != self) || (tf.eta != 0)
        print " !Tf if not at this star\n"
      elsif !tf.has_weapons?
        print " !Tf has no warships\n"
      else # valid tf
        print "#{tf.name}\n"
        first_time = !planet.under_attack
        if !planet.under_attack
          planet.under_attack = true
          summary
        end
        planet.fire_salvo(PLAYER, tf)
        tf.delete if tf.sum_all_ships == 0
        @battle = colony?(ENEMY) && any_bc?(PLAYER)
      end
    end # valid planet
  end # play_salvo

  private

  def assign_planets
    @planets = []
    num_planets = rnd(4) - 2
    num_planets = 1 if num_planets < 0
    (1..num_planets).each do |n|
      num = rnd(2) + (2 * n) - 2
      @planets << Planet.new(self, num)
    end
  end
end # Star
