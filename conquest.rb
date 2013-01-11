require_relative "const"
require_relative "planet"
require_relative "star"
require_relative "task_force"
require_relative "player"
require_relative "help"

def rnd(i)
  ((((rand * 1E16) / 2) % i) + 1).to_i
end

def get_chr
  begin
    system("stty raw -echo")
    chr = STDIN.getc.chr
    result = chr
  ensure
    system("stty -raw echo")
  end
end

def tf_from_chr(team, chr)
  @@task_forces[team][chr.ord-97]
end

def star_from_chr(chr)
  @@stars[chr.ord-65]
end

def distance_to_star(x, y, star)
  Math.sqrt((star.x - x)**2 + (star.y - y)**2)
end

def pause
  print "\nPress any key to continue"
  get_chr
  print "\n"
end

def weapons(player)
  player == CConst::PLAYER ? @@player.w : @@enemy.w
end

def velocity(player)
  player == CConst::PLAYER ? @@player.v : @@enemy.v
end

@@board = nil
@@stars = []
@@planets = []
@@task_forces = Array.new(2) { Array.new }
@@player = nil
@@enemy = nil
@@growth_rate = Array[0.5, 0.3]
@@en_research = "v"

class Conquest
  include CConst

  def initialize
    @game_over = false
    @production_year = 1
    @@turn = 1

    init_board
    welcome
    self.class.draw(false)
    init_match

    run_game
  end

  def run_game
    until @game_over
      until input_player
      end

      unless @game_over
        input_mach
        move_ships
        battle
        invest if (@production_year == 4) && (@@turn < 100)
        up_year
      end

      game_over?
    end
  end

  def self.turn
    @@turn
  end

  def init_board
    @@board = Array.new(BOARD_X) { Array.new(BOARD_Y) { BoardSpace.new } }

    (0...BOARD_X).each do |x|
      (0...BOARD_Y).each do |y|
        @@board[x][y].x = x
        @@board[x][y].y = y
      end
    end

    (0...NUM_STARS).each do |star_num|
      new_star = Star.new((star_num + 65).chr)
      @@board[new_star.x][new_star.y] = new_star
    end
  end

  def welcome
    puts "\n** Welcome to CONQUEST! **"
    puts "**   Ruby Version 0.1   **\n"
  end

  def init_match
    puts "*Initialization*"

    @@player = Player.new(PLAYER)

    begin
      # Uncomment for a cheat to show stars with the largest planets
      # print @@stars.reject { |star| star.planets.reject { |planet| planet.capacity < 60 }.empty? }

      print "start at star? "
      star_number = get_chr.upcase.ord - 65
    end until star_number.between?(0, 20)

    player_star = @@stars[star_number]
    player_star.visit[PLAYER] = true
    task_force = TaskForce.new(PLAYER, player_star, t: INIT_UNIT)

    self.class.draw

    print "choose your initial fleet.\n"
    print "you have #{task_force.t} transports & #{@@player.balance} units to spend on ships or research.\n"
    begin
      @@player.show_resources
      printf("%s %3d? ", task_force, @@player.balance)
      @@player.parse_input(gets, task_force)
    end until @@player.balance == 0

    @@enemy = Player.new(ENEMY)

    @@enemy.r += 2

    case rnd(3)
    when 1
      @@enemy.w = rnd(4) + 2
    when 2
      @@enemy.v = rnd(3)
    when 3
      @@growth_rate[ENEMY] = (rnd(4) + 3) / 10
    end

    enemy_star = @@stars[rand(@@stars.length)]
    enemy_star.visit[ENEMY] = true
    TaskForce.new(ENEMY, enemy_star, t: INIT_UNIT, c: 1, s: 2)

    @@enemy.research(@@en_research, 2)

    battle if player_star == enemy_star

    self.class.draw
  end # init_match

  def self.pn?(n)
    (n % 5 == 0) || (n == 1)
  end

  def self.draw(clear = true)
    system("clear") if clear
    print("   ")
    (3 * BOARD_X).times { print "-" }
    print("\n")
    i = 14
    @@board.reverse_each do |row| 
      pn?(i+1) ? printf("%2d", i+1) : print("  ")
      print "|"
      row.each { |cell| print cell }
      print "|\n"
      i -= 1
    end
    print("   ")
    (3 * BOARD_X).times { print "-" }
    print("\n  ")
    (1..BOARD_X).each { |n| pn?(n) ? printf("%3d", n) : print("   ") }
    print("\n")
  end

  def game_over?
    quit_game = @game_over

    dead = Array.new(2) { false }
    total = Array.new(2) { 0 }
    transports = Array.new(2) { 0 }
    inhabs = Array.new(3) { 0 }

    (0..1).each do |team|
      @@task_forces[team].compact.each { |tf| transports[team] += tf.t }
    end

    @@stars.each do |star|
      star.planets.each { |planet| inhabs[planet.team] += planet.iu } 
    end

    (0..1).each do |team|
      total[team] = inhabs[team] + transports[team]
      dead[team] = total[team] == 0
    end

    if ( (!dead[PLAYER]) && (!dead[ENEMY]) && (@@turn >= 40) )
      dead[ENEMY] = total[PLAYER] / total[ENEMY] >= 8
      dead[PLAYER] = total[ENEMY] / total[PLAYER] >= 8
    end

    @game_over = dead[PLAYER] || dead[ENEMY] || (@@turn > 100) || quit_game

    if @game_over
      print "\n*** Game over ***\n"
      printf "Player: Population in transports:%3d", transports[PLAYER]
      printf "  IU's in colonies: %3d  TOTAL: %3d\n\n", inhabs[PLAYER], total[PLAYER]
      printf "Enemy:  Population in transports:%3d", transports[ENEMY]
      printf "  IU's in colonies: %3d  TOTAL: %3d\n", inhabs[ENEMY], total[ENEMY]
      if (total[ENEMY] > total[PLAYER]) || quit_game
        print "**** THE ENEMY HAS CONQUERED THE GALAXY ***\n"
      elsif total[PLAYER] > total[ENEMY]
        print "*** PLAYER WINS- YOU HAVE SAVED THE GALAXY! ***\n"
      else
        print "*** DRAWN ***\n"
      end
    end
  end # game_over?

  def input_player
    result = false

    print "? "
    input = get_chr.upcase

    case input
    when "M"
      self.class.draw
    when "B"
      @@player.blast_planet
    when "G", " "
      # noop
      self.class.draw
      result = true
    when "H"
      help(1)
    when "L"
      @@player.land
    when "D"
      @@player.send_tf
    when "S"
      @@player.star_summary
    when "N"
      @@player.make_tf
    when "J"
      @@player.join_tf
    when "C"
      @@player.print_col
    when "R"
      puts "research fields:"
      @@player.show_resources
    when "Q"
      print("Quit game....[verify] ")
      if get_chr.downcase == "y"
        @game_over = true
        result = true
      else  
        self.class.draw
      end
    when "?"
      # noop
    when "T"
      @@player.tf_summary
    when "X"
      @@stars.each { |star| star.summary if star.colony?(ENEMY) }
    else
      puts "!illegal command"
    end
    result
  end # input_player

  def input_mach
    @@task_forces[ENEMY].compact.each do |tf|
      if tf.dest && (tf.eta == 0)
        reachable_stars = tf.dest.reachable_stars
        not_visited = reachable_stars.reject { |star| star.visit[ENEMY] }

        ###################
        ### send_scouts ###
        ###################
        doind = not_visited.length
        while (doind > 0) && (tf.s > 0)
          new_tf = TaskForce.new(ENEMY, tf.dest, s: 1)
          new_dest = not_visited[rand(doind)]
          new_tf.dest = new_dest
          new_tf.eta = ((tf.dest.distance_to(new_dest) - 0.01) / @@enemy.v).to_i + 1
          tf.dest.depart
          tf.s -= 1
          doind -= 1
        end

        unreachable_stars = @@stars - reachable_stars
        doind = unreachable_stars.length
        while tf.s > 0
          new_tf = TaskForce.new(ENEMY, tf.dest, s: 1)
          new_dest = unreachable_stars[rand(doind)]
          new_tf.dest = new_dest
          new_tf.eta = ((tf.dest.distance_to(new_dest) - 0.01) / @@enemy.v).to_i + 1
          tf.dest.depart
          tf.s -= 1
        end

        tf.send_transports

        ###############
        ### move_bc ###
        ###############
        if tf.has_weapons?
          best_star = reachable_stars.first
          best_planet = nil
          top_score = -1000

          reachable_stars << tf.dest
          reachable_stars.each do |star|
            star.planets.each do |planet|
              score = planet.eval_bc_col
              score += 250 if star == tf.dest
              score -= 150 if star.task_forces[ENEMY].length > 0
              if score > top_score
                top_score = score
                best_planet = planet
                best_star = star
              end
            end
          end

          if best_star.name == tf.dest.name # stay put
            if best_planet != nil
              if (best_planet.team == ENEMY) && best_planet.conquered? && (best_planet.iu < 20)
                factors = [weapons(ENEMY) * tf.forces, 4 * best_planet.inhabitants].min
                best_planet.blast(factors)
                if best_planet.star.present?(PLAYER)
                  best_planet.psee_capacity = best_planet.capacity
                end
              elsif (best_planet.team == ENEMY) && best_planet.conquered? # decide whether to split
                if ( ((tf.b > 3) || (tf.c > 3)) && (rnd(4) == 4) ) || (tf.b > 8)
                  tf.wander_bc
                end
              end
            end
          else # move
            tf.dest.task_forces[ENEMY].delete(tf)
            tf.dest.depart
            tf.eta = ( (tf.dest.distance_to(best_star) - 0.01) / @@enemy.v).to_i + 1
            tf.dest = best_star
          end
        end # move_bc
      end # stationary enemy task force
    end # each enemy task force
  end # input_mach

  def move_ships
    (0..1).each do |team|
      @@task_forces[team].compact.each do |tf|
        tf.delete if tf.sum_all_ships == 0

        if tf.dest && (tf.eta > 0) # moving tf
          tf.eta -= 1

          if (team == PLAYER) && !tf.dest.visit[team] && (tf.eta == 0)
            printf "Task force %c exploring %c.\n", tf.name, tf.dest.name

            prob = (10 + rnd( 5) * tf.t) / 100.0
            prob = (70 + rnd(10) * tf.s) / 100.0 if tf.s > 0
            prob = (90 + rnd(10) * tf.c) / 100.0 if tf.c > 0
            prob = (97 + rnd( 3) * tf.b) / 100.0 if tf.b > 0
            prob = 100 if prob > 100

            no_loss_t = tf.lose("t", prob)
            no_loss_s = tf.lose("s", prob)
            no_loss_c = tf.lose("c", prob)
            no_loss_b = tf.lose("b", prob)
            no_loss = no_loss_t && no_loss_s && no_loss_c && no_loss_b
            
            print "No ships" if no_loss
            print " destroyed.\n"

            pause
            tf.delete if tf.sum_all_ships == 0
          end # player exploring new planet

          if tf.dest
            if team == PLAYER
              dx = tf.dest.x
              dy = tf.dest.y

              ratio = 1.0 - (tf.eta / tf.origeta.to_f)

              tf.x = tf.xf + (ratio * (dx - tf.xf)).round
              tf.y = tf.yf + (ratio * (dy - tf.yf)).round

              if tf.eta == 0
                tf.dest.planets.each { |planet| planet.psee_capacity = planet.capacity }

                tf.dest.player_arrivals = true

                tf.dest.visit[PLAYER] = true
              end
            end

            if (team == ENEMY) && (tf.eta == 0)
              tf.dest.visit[ENEMY] = true
              tf.dest.planets.each { |planet| planet.esee_team = planet.team }
              if tf.dest.task_forces[team].length > 0
                tf.join_silent(tf.dest.task_forces[team][0])
              end
              tf.dest.enemy_arrivals = true if tf.dest.present?(PLAYER)
            end

            tf.dest.task_forces[team] << tf if tf.eta == 0
          end # tf has a destination
        end # with destination and eta (en route)
      end # each tf
    end # each team

    @@task_forces[PLAYER].compact.each do |tf|
      if tf.dest
        tf.blasting = false
        dx = tf.x
        dy = tf.y
      end
    end

    any = false
    @@stars.each do |star|
      if star.player_arrivals
        unless any
          print "\nPlayer arrivals: "
          any = true
        end
        print star.name
        star.player_arrivals = false
      end
    end

    any = false
    @@stars.each do |star|
      if star.enemy_arrivals
        unless any
          print "\nEnemy arrivals: "
          any = true
        end
        print star.name
        star.enemy_arrivals = false
      end
    end

    any = false
    @@stars.each do |star|
      if star.enemy_departures
        unless any
          print "\nEnemy Departures: "
          any = true
        end
        print star.name
        star.enemy_departures = false
      end
    end

    @@stars.each { |star| star.revolt }
  end # move_ships

  def battle
    first = true

    @@stars.each do |star|
      if star.tf_conflict?
        if first
          print "\n* Tf battle *"
          first = false
        end

        star.tf_battle
      end

      if star.any_bc?(ENEMY) && star.colony?(PLAYER)
        star.enemy_attack
      elsif star.task_forces[PLAYER].any? && star.colony?(ENEMY)
        star.player_attack
      end
    end # each star
  end # battle

  def invest
    @production_year = 0
    print "\n* investment *\n"
    @@planets.each { |planet| planet.invest }
    battle
  end # invest

  def up_year
    @@turn += 1
    printf("\nYear %3d ", @@turn)
    @production_year += 1
    printf("Production Year %d ", @production_year)
  end # up_year
end # Conquest

if __FILE__ == $0
  @@conquest = Conquest.new
end
