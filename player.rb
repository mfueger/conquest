require_relative "const"

class Player
  include CConst
  RAN_REQ = Hash[5 =>  0, 6 => 20, 7 => 40, 8 =>  70, 9 => 100, 10 => 150, 11 => 200, 12 => 300, 13 => 400, 14 => 600, 15 => 900]
  VEL_REQ = Hash[2 => 40, 3 => 60, 4 => 80, 5 => 120, 6 => 150,  7 => 200,  8 => 250,  9 => 300, 10 => 400, 11 => 500, 12 => 600]
  WEA_REQ = Hash[3 =>  0, 4 => 50, 5 => 70, 6 =>  90, 7 => 120,  8 => 150,  9 => 250, 10 => 350]

  attr_accessor :balance, :amt, :ind
  attr_accessor :v, :r, :w, :v_working, :r_working, :w_working
  attr_accessor :team

  def initialize(team = NONE)
    @balance = INIT_MONEY

    @v = INIT_VEL
    @r = INIT_RANGE
    @w = INIT_WEAP

    @v_working = 0
    @r_working = 0
    @w_working = 0

    @team = team
  end

  def parse_input(input, tf)
    commands = input.chomp.upcase.split
    commands.each do |cmd|
      amt = cmd.scan(/\d+/)[0].to_i
      amt = 1 if amt == 0
      target = cmd.scan(/\D/)[0]

      case target
      when "H"
        help(0)
      when "C"
        cost = amt * C_COST
        if cost <= @balance
          tf.c += amt
          @balance -= cost
        else
          puts "!can't afford #{amt}C"
        end
      when "S"
        cost = amt * S_COST
        if cost <= @balance
          tf.s += amt
          @balance -= cost
        else
          puts "!can't afford #{amt}S"
        end
      when "B"
        cost = amt * B_COST
        if cost <= @balance
          tf.b += amt
          @balance -= cost
        else
          puts "!can't afford #{amt}B"
        end
      when "W"
        if amt <= @balance
          @balance -= amt
          research(target.downcase, amt)
        else
          puts "!can't afford #{amt}W"
        end
      when "V"
        if amt <= @balance
          @balance -= amt
          research(target.downcase, amt)
        else
          puts "!can't afford #{amt}V"
        end
      when "R"
        if amt <= @balance
          @balance -= amt
          research(target.downcase, amt)
        else
          puts "!can't afford #{amt}R"
        end
      when "M"
        Conquest.draw
      end
    end
  end # parse_input

  def res_req(res)
    case res
    when "v"
      VEL_REQ
    when "r"
      RAN_REQ
    when "w"
      WEA_REQ
    end
  end

  def show_resource(res)
    printf "%s: %2d res: %3d", res.upcase, send(res), send("#{res}_working")
    required = res_req(res)[send(res)+1]
    printf " need: %3d", required if required
    print "\n"
  end

  def new_research
    if @@player.w - @@enemy.w > 1
      @@en_research = "w"
    else
      case rnd(10)
      when 1..3
        @@en_research = "v"
      when 10
        @@en_research = "r"
      else
        @@en_research = "w"
      end
    end
  end

  def research(res, amt)
    req = res_req(res)

    if req.keys[-1] > send(res)
      send("#{res}_working=", send("#{res}_working") + amt)
      if send("#{res}_working") >= req[send(res)+1]
        send("#{res}=", send("#{res}") + 1)
        send("#{res}_working=", send("#{res}_working") - req[send(res)])
        if @team == ENEMY
          new_research
          research(@@en_research, send("#{res}_working"))
        end
      end
    end
  end

  def show_resources
    print "\n"
    show_resource("v")
    show_resource("r")
    show_resource("w")
  end

  def blast_planet
    print "blast\nFiring TF:"
    tf = tf_from_chr(PLAYER, get_chr)
    if tf.nil?
      print " !Illegal tf"
    elsif tf.dest.nil?
      print " !Nonexistent tf"
    elsif tf.eta != 0
      print " !Tf is not in normal space"
    elsif tf.blasting
      print " !Tf is already blasting"
    elsif !tf.has_weapons?
      print " !Tf has no warships"
    else
      print tf.name
      star = tf.dest
      if star.planets.empty?
        printf " !No planets at star %c", star.name
      else
        print "\nTarget colony "
        if star.planets.length == 1
          planet = star.planets.first
          print planet.number
        else
          print ":"
          planet_num = get_chr.ord - 48
          planet = star.planets.reject { |planet| planet.number != planet_num }.first
          if planet.nil?
            print " !No such planet at this star"
          end
        end

        if planet
          if planet.team == ENEMY
            print " !Conquer it first!"
          elsif (planet.team == PLAYER) && !planet.conquered?
            print " !That is a human colony!!"
          else
            factors = weapons(PLAYER) * tf.forces
            printf "\nUnits (max %3d) :", factors / 4
            amount = gets.to_i
            if amount < 0
              factors = 0
            else
              factors = [factors, amount * 4].min
            end
            tf.blasting = true
            printf "Blasting %3d units\n", factors / 4
            planet.blast(factors)
            planet.psee_capacity = planet.capacity
            pause
            puts planet
          end
        end # valid planet
      end
    end
  end # blast_planet

  def land
    print "land tf: "
    tf = tf_from_chr(@team, get_chr)
    if tf.nil?
      print "  !illegal tf\n"
      return
    end
    if tf.eta != 0
      print "  !tf is not in normal space\n"
      return
    end
    if tf.dest.task_forces[ENEMY].any?
      print "  !enemy ships present\n"
      return
    end
    print " planet " if tf.dest.planets.any?
    if tf.dest.planets.empty?
      print "  !no planets at this star\n"
      return
    elsif tf.dest.planets.length == 1
      dest_planet = tf.dest.planets[0]
      printf "%d", dest_planet.number
    else
      print ":"
      planet_num = get_chr.ord - 48
      dest_planet = tf.dest.planets.reject { |planet| planet.number != planet_num }.first
      if dest_planet.nil?
        print "  !Not a habitable planet"
        return
      end
    end
    if dest_planet.team == ENEMY
      print "  !Enemy infested planet !!\n"
    else
      room_left = dest_planet.capacity - dest_planet.inhabitants
      print " transports: "
      transports = gets.to_i
      # has a number been supplied?
      transports = [tf.t, room_left].min if transports == 0
      if transports < 1
        print "  !illegal transports\n"
        return
      elsif transports > tf.t
        printf "  !only %2d transports in tf", tf.t
      elsif transports > room_left
        printf "  !only room for %2d transports", room_left
        return
      else
        dest_planet.team = PLAYER
        dest_planet.inhabitants += transports
        dest_planet.iu += transports
        tf.t -= transports
        see = true
        # pause
        printf "%d:%2d", dest_planet.number, dest_planet.psee_capacity
        if dest_planet.psee_capacity == 0
          print " Decimated"
        elsif (dest_planet.team == NONE) && see
          print " No colony"
        elsif dest_planet.team == PLAYER
          printf " (%2d/%3d)", dest_planet.inhabitants, dest_planet.iu
          if dest_planet.conquered?
            print "Con"
          else
            print "   "
          end
          if dest_planet.mb > 0
            printf "%2dmb", dest_planet.mb
          end
          if dest_planet.amb > 0
            printf "%2damb", dest_planet.amb
          end
        elsif (dest_planet.team == ENEMY) && see
          print "*EN*"
          if see && dest_planet.conquered?
            print "Conquered"
          else
            print "   "
          end
          if dest_planet.under_attack
            if dest_planet.mb > 0
              printf "%2dmb", dest_planet.mb
            else
              print "   "
            end
            if dest_planet.amb > 0
              printf "%2damb", dest_planet.amb
            end
          end
        end
        tf.delete if tf.sum_all_ships == 0
        print "#{tf}\n"
      end
    end
  end # land

  def send_tf
    print "destination tf: "
    tf = tf_from_chr(@team, get_chr)

    if tf.nil?
      print "  !illegal tf\n"
      return
    end

    if (tf.eta != 0) && ((tf.eta != tf.origeta) || tf.withdrew)
      print "  !Tf is not in normal space\n"
      return
    end

    if (tf.blasting)
      print "  !Tf is blasting a planet\n"
      return
    end

    tf.set_des
  end

  def tf_summary
    print "\ntf summary:\n"
    @@task_forces[@team].compact.each { |tf| puts tf.to_s }
  end

  def star_summary
    print "star summary: "
    star = star_from_chr(get_chr.upcase)
    if star && star.visit[@team]
      star.summary
    else
      @@stars.reject { |star| !star.visit[@team] }.each { |star| star.summary }
    end
  end

  def split_tf(tf, ships)
    new_tf = TaskForce.new(@team, tf.dest)
    total = 0

    ships.each do |cmd|
      amt = cmd.scan(/\d+/)[0].to_i
      amt = 1 if amt == 0
      target = cmd.scan(/\D/)[0]
      
      case target
      when "T"
        amt = tf.t if amt > tf.t
        new_tf.t = amt
        tf.t -= amt
        total += amt
      when "S"
        amt = tf.s if amt > tf.s
        new_tf.s = amt
        tf.s -= amt
        total += amt
      when "C"
        amt = tf.c if amt > tf.c
        new_tf.c = amt
        tf.c -= amt
        total += amt
      when "B"
        amt = tf.b if amt > tf.b
        new_tf.b = amt
        tf.b -= amt
        total += amt
      end
    end

    if total == 0
      new_tf.t = tf.t
      new_tf.s = tf.s
      new_tf.c = tf.c
      new_tf.b = tf.b
      tf.delete
    end

    return new_tf
  end # split_tf

  def make_tf
    print "new tf- from tf: "
    from_tf = tf_from_chr(@team, get_chr)
    if from_tf.nil? || from_tf.eta > 0
      print "  !illegal tf\n"
      return
    end
    if from_tf.blasting
      print " !Tf is blasting a planet\n"
      return
    end
    print " ships: "
    print "#{split_tf(from_tf, gets.chomp.upcase.split)}\n"
  end

  def join_tf
    print "join tfs: "
    tf1 = tf_from_chr(@team, get_chr)
    tf2 = tf_from_chr(@team, get_chr)
    if tf1.nil? || tf2.nil?
      print "  !illegal tf\n"
      return
    else
      print "#{tf1.name}#{tf2.name}"
    end
    if tf1.blasting || tf2.blasting
      print "  !Tf is blasting a planet\n"
      return
    end
    if (tf1.eta > 0) || (tf2.eta > 0)
      print "  ! tf is not in normal space\n"
    end
    if tf1 == tf2
      print "!Duplicate tf\n"
    end
    if (tf1.x != tf2.x) || (tf1.y != tf2.y)
      print "  !tf bad location\n"
    end
    tf1.join_silent(tf2)
    print "\n#{tf1}\n"
  end

  def print_col
    print "colonies:\n"
    @@stars.each do |star|
      star.planets.each do |planet|
        if planet.team == PLAYER
          print star.name
          print planet
          print "\n"
        end
      end
    end
  end
end # Player
