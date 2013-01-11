require_relative "const"

class TaskForce
  include CConst

  attr_accessor :b, :c, :s, :t
  attr_accessor :x, :y, :xf, :yf, :origeta
  attr_accessor :eta, :blasting, :withdrew
  attr_accessor :team, :name
  attr_reader   :dest

  def initialize(team, star, ships = {})
    @team = team

    free_spot = @@task_forces[team].index(nil)
    @name = free_spot ? (free_spot + 97).chr : (@@task_forces[@team].length + 97).chr
    free_spot ? @@task_forces[team][free_spot] = self : @@task_forces[team] << self

    @eta = 0
    
    @dest = star
    @x = star.x
    @y = star.y
    @xf = @x
    @yf = @y
    star.task_forces[team] << self

    @b = ships[:b] || 0
    @c = ships[:c] || 0
    @s = ships[:s] || 0
    @t = ships[:t] || 0

    @blasting = false
    @withdrew = false

    @origeta = 0
  end

  def dest=(star)
    @dest.task_forces[@team].delete(self)
    @dest = star
  end

  def delete
    @dest.task_forces[@team].delete(self) if @dest
    @dest = nil

    idx = self.index
    @@task_forces[@team][idx] = nil if idx # make free spot
  end

  def has_weapons?
    @b > 0 || @c > 0
  end

  def forces
    @b * B_GUNS + @c * C_GUNS
  end

  def sum_all_ships
    @b + @c + @s + @t
  end

  def index
    @@task_forces[@team].index(self)
  end

  def disp_tf
    [[@t,"t"], [@s,"s"], [@c,"c"], [@b,"b"]].each { |ships| ships[0] > 0 ? printf("%2d%s", ships[0], ships[1]) : print("   ") }
    print "\n"
  end

  def to_s
    loc = @eta == 0 ? @dest.to_s[1] : " "

    dest = @eta > 0 ? " #{@dest.to_s[1]}#{(@eta).round}" : ""

    if @team == PLAYER
      tf = "TF#{@name}:#{loc}(%2d, %2d)" % [@y + 1, @x + 1]
    else
      tf = " EN:#{loc}(%2d, %2d)" % [@y + 1, @x + 1]
    end

    [[@t,"t"], [@s,"s"], [@c,"c"], [@b,"b"]].each { |ships| ships[0] > 0 ? tf += " %2d%s" % [ships[0], ships[1]] : "    " }

    tf += dest
  end

  def join_silent(tf)
    @t += tf.t
    @s += tf.s
    @c += tf.c
    @b += tf.b

    tf.delete
  end

  def set_des
    if @eta != 0
      @eta = 0
      print "(Cancelling previous orders)"
    end

    print " to star: "
    star = star_from_chr(get_chr.upcase)
    if star.nil?
      print "  !illegal star\n"
      return
    end

    distance = distance_to_star(@x, @y, star)
    printf "   distance:%5.1f ", distance
    if (distance > @@player.r) && ((@t > 0) || (@c > 0) || (@b > 0))
      printf "  !maximum range is %2d\n", @@player.r
      return
    end

    if (@x == star.x) && (@y == star.y)
      print "Tf remains at star\n"
      return
    end

    min_eta = ((distance - 0.049) / @@player.v).to_i + 1
    printf "eta in %2d turns\n", min_eta

    @dest.task_forces[PLAYER].delete(self) if @dest

    @dest = star
    @eta = min_eta
    @origeta = @eta
    @xf = @x
    @yf = @y
  end # set_des

  def lose(type, odds)
    result = true

    ships = send(type)

    if ships > 0
      sleft = ships
      ships.times do
        if rand > odds
          result = false
          sleft -= 1
        end
      end

      if sleft < ships
        printf " %2d%c", ships - sleft, type
        send("#{type}=", sleft)
      end
    end

    return result
  end # lose

  def send_transports
    if @t > 0
      best_star = 0
      sec_star = 0
      sec_score = -11000
      top_score = -10000
      best_plan = nil

      reachable_stars = @dest.reachable_stars
      reachable_stars << @dest

      reachable_stars.each do |star|
        range = @dest.distance_to(star)

        star.planets.each do |planet|
          score = planet.eval_t_col(range)
          xstar = star

          if score > top_score
            best_star, xstar = xstar, best_star
            top_score, score = score, top_score
            best_plan = planet
          end

          if score > sec_score
            sec_score = score
            sec_star = xstar
          end
        end # each planet
      end # each reachable star

      if best_star.name == @dest.name # land
        if best_star.task_forces[PLAYER].empty? && (best_plan.team != PLAYER)
          to_land = [@t, (best_plan.capacity - best_plan.inhabitants) / 3].min
          if to_land > 0
            if best_plan.inhabitants == 0
              best_plan.team = ENEMY
              best_plan.esee_team = ENEMY
            end
            best_plan.inhabitants += to_land
            best_plan.iu += to_land
            @t -= to_land
            send_transports
          end
        end
      else # move
        if (@t >= 10) && sec_star
          new_tf = TaskForce.new(ENEMY, @dest, t: @t / 2)
          @t -= new_tf.t
          if (@c > 0) && !@dest.under_defended?
            new_tf.c += 1
            @c -= 1
          end
          best_star.depart
          new_tf.dest = best_star
          new_tf.eta = ((@dest.distance_to(best_star) - 0.01) / @@enemy.v).to_i + 1
          best_star = sec_star
        end

        new_tf = TaskForce.new(ENEMY, @dest, t: @t)
        @t = 0
        if (@c > 0) && !@dest.under_defended?
          new_tf.c += 1
          @c -= 1
        end
        best_star.depart
        new_tf.dest = best_star
        new_tf.eta = ((@dest.distance_to(best_star) - 0.01) / @@enemy.v).to_i + 1
      end
    end # tf has transports
  end # send_transports

  def wander_bc
    if (@b > 1) || (@c > 1)
      new_dest = @dest.random_reachable_star
      new_tf = TaskForce.new(ENEMY, @dest, b: @b / 2, c: @c / 2)
      @b -= new_tf.b
      @c -= new_tf.c
      if @t > 3
        new_tf.t += 2
        @t -= 2
      end
      new_tf.dest = new_dest
      new_tf.eta = ((@dest.distance_to(new_dest) - 0.01) / @@enemy.v).to_i + 1
    end
  end # wander_bc
end # TaskForce
