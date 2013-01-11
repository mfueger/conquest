require_relative "const"

class Planet
  include CConst

  attr_accessor :number
  attr_accessor :capacity, :psee_capacity, :team, :inhabitants, :iu, :mb, :amb
  attr_accessor :conquered, :under_attack
  attr_accessor :esee_team, :esee_def, :star
  
  def initialize(star, number)
    @star = star

    rnd(4) > 2 ? @capacity = 10 * (rnd(4) + 2) : @capacity = 5 * rnd(3)

    @psee_capacity = @capacity

    @team = NONE
    @esee_team = NONE

    @inhabitants = 0
    @iu = 0
    @mb = 0
    @amb = 0

    @conquered = false
    @under_attack = false

    @esee_def = 1

    @number = number

    @@planets << self
  end

  def to_s
    @armament = ""

    if @psee_capacity == 0
      @info = " Decimated"
    elsif (@team == NONE) && @star.present?(PLAYER)
      @info = " No colony"
    elsif @team == PLAYER
      @info = "(#{@inhabitants}/#{@iu})"
      @info += "Con" if @conquered

      @armament += "#{@mb}mb " if @mb > 0
      @armament += "#{@amb}amb" if @amb > 0
    elsif (@team == ENEMY) && @star.present?(PLAYER)
      @info = "*EN*"
      @info += "Conquered" if @conquered
      if @under_attack
        @armament += "#{@mb}mb " if @mb > 0
        @armament += "#{@amb}amb" if @amb > 0
      end
    end

    " #{@number}:%2d #{@colony} #{@info} #{@armament}" % @psee_capacity
  end

  def conquered?
    @conquered
  end

  def invest
    if (@esee_team == PLAYER) && (@capacity > 10) && (@esee_def < 12)
      @esee_def += 1
    end

    if (@team != NONE)
      newborn = (@inhabitants * @@growth_rate[@team] * (1 - (@inhabitants.to_f / @capacity)) ).round

      newborn = newborn / 2 if conquered?

      @inhabitants += newborn
      @iu += newborn

      @team == ENEMY ? inv_enemy : inv_player
    end
  end # invest

  def inv_enemy
    balance = @iu

    new_tf = @star.task_forces[ENEMY].empty? ? TaskForce.new(ENEMY, @star) : @star.task_forces[ENEMY].first

    while (@amb == 0) && (!conquered?) && (@mb < (@capacity / 20)) && (balance >= MB_COST)
      balance -= MB_COST
      @mb += 1
    end

    if (balance >= B_COST) && (rnd(5) != 1) && (rnd(7) <= @amb + 3) && (@amb > 1)
      balance -= B_COST
      new_tf.b += 1
    end

    if (balance >= AMB_COST) && ((@amb < 4) || (rnd(2) == 2)) && !conquered?
      balance -= AMB_COST
      @amb += 1
    end

    while balance >= 9
      case rnd(12)
      when 1, 2
        @@enemy.research(@@en_research, 8)
        balance -= 8
      when 3, 4, 10
        if balance >= C_COST
          balance -= C_COST
          new_tf.c += 1
        elsif (!conquered?) && (balance >= MB_COST)
          balance -= MB_COST
          @mb += 1
        else
          balance -= 9
          @@enemy.research(@@en_research, 9)
        end
      when 11, 12
        if ( (@inhabitants / @capacity.to_f < 0.6) || ((@capacity >= 70 / 2) && (@iu < 70 + 10))) # no t's
          inv_amount = [3, @inhabitants * 2 - @iu].min
          balance -= inv_amount * 3
          @iu += inv_amount
        else
          if !conquered?
            transports = [rnd(2) + 6, @inhabitants - 1].min
            transports = [transports, @iu - 70].min if @iu > 70
            balance -= transports
            @inhabitants -= transports
            @iu = [@iu - transports, @inhabitants * 2].min
            new_tf.t += transports
          end
        end
      else
        inv_amount = [3, @inhabitants * 2 - @iu].min
        balance -= 3 * inv_amount
        @iu += inv_amount
      end
    end # while balance >= 9

    new_tf.delete if new_tf.sum_all_ships == 0

    @@enemy.research(@@en_research, balance)
  end # inv_enemy

  def inv_player
    new_tf = TaskForce.new(PLAYER, @star)
    balance = @iu
    printf "%c%d:%2d (%2d,/%3d) ", @star.name, @number, @psee_capacity, @inhabitants, @iu
    conquered? ? print("Con") : print("   ")
    @mb > 0 ? printf("%2dmb", @mb) : print("    ")
    @amb > 0 ? printf("%2damb", @amb) : print("    ")

    begin
      printf "%3d? ", balance

      commands = gets.chomp.upcase.split
      commands.each do |cmd|
        amt = cmd.scan(/\d+/)[0].to_i
        amt = 1 if amt == 0
        target = cmd.scan(/\D/)[0]

        case target
        when "A"
          cost = amt * AMB_COST
          if @inhabitants == 0
            cost = 0
            print "  !abandoned planet"
          elsif conquered?
            cost = 0
            print " !No amb on conquered colony "
          else
            @amb += amt if cost <= balance
          end
        when "B"
          cost = amt * B_COST
          new_tf.b += amt if cost <= balance
        when "C"
          cost = amt * C_COST
          new_tf.c += amt if cost <= balance
        when "H"
          cost = 0
          help(4)
        when "M"
          cost = amt * MB_COST
          if @inhabitants == 0
            cost = 0
            print "  !abandoned planet"
          elsif conquered?
            cost = 0
            print " !No Mb on conquered colony  "
          else
            @mb += amt if cost <= balance
          end
        when "S"
          cost = amt * S_COST
          new_tf.s += amt if cost <= balance
        when "T"
          cost = amt
          if cost <= balance
            if cost > @inhabitants
              print " ! Not enough people for ( trans"
              cost = 0
            elsif conquered?
              cost = 0
              print " !No transports on conquered col"
            else
              new_tf.t += amt
              @inhabitants -= amt
              @iu = [@iu - amt, @inhabitants * 2].min

              if (@inhabitants == 0)
                @team = NONE
                @amb = 0
                @mb = 0
                @iu = 0
              end
            end
          end
        when "I"
          cost = amt * 3
          if (amt + @iu) > (@inhabitants * 2)
            cost = 0
            print " !Can't support that many iu's"
          elsif (cost <= balance)
            @iu += amt
          end
        when "R", "V", "W"
          cost = amt
          if cost <= balance
            @@player.research(target.downcase, amt)
          end
          @@player.show_resource(target.downcase)
        when " "
          cost = 0
        when ">"
          cost = 0
          print ">?     "
          input = get_chr.upcase
          case input
          when "M"
            Conquest.draw
          when "S"
            @@player.star_summary
          when "C"
            self
          when "R"
            @@player.show_resources
          else
            print " !Only M,S,C,R allowed "
          end
        else
          print " !Illegal field"
          cost = 0
        end # case

        if cost > balance
          printf " !can't afford %3d%c", amt, target
        else
          balance -= cost
        end
      end # each command
    end while balance > 0

    new_tf.sum_all_ships == 0 ? new_tf.delete : print(new_tf)
  end # inv_player

  def eval_t_col(range)
    if !@star.visit[ENEMY]
      result = 60
    else
      case @esee_team
      when NONE
        result = 40
      when ENEMY
        result = 30
      when PLAYER
        result = 0
      end

      if (@esee_team != PLAYER) && (@capacity - @inhabitants > 40 - (Conquest.turn / 2))
        result += 40
      end
    end

    result -= (2 * range + 0.5).to_i

    return result
  end # eval_t_col

  def eval_bc_col
    if !@star.visit[ENEMY]
      result = 60
    else
      case @esee_team
      when NONE
        result = 100
      when ENEMY
        if conquered?
          result = 1000
        else
          if ( ((6 * @amb + @mb) < (@iu / 15)) && (!( (!conquered?) && (@iu < 8) )) )
            result = 300
          else
            result = 0
          end
        end
        if (@amb >= 4)
          result -= 250
        end
      when PLAYER
        if conquered?
          result = 400
        else
          result = 200
        end
      end

      if (@capacity < 40) && (@iu < 15)
        result -= 100
      end
    end

    result += rnd(20)

    return result
  end # eval_bc_col

  def forces
    @amb * B_GUNS + @mb * C_GUNS
  end

  def lose(type, prob)
    result = true

    bases = send(type)

    if bases > 0
      bleft = bases
      bases.times do
        if rand > prob
          result = false
          bleft -= 1
        end
      end

      if bleft < bases
        printf " %2d%s", bases - bleft, type
        send("#{type}=", bleft)
      end
    end

    return result
  end # lose

  def fire_salvo(att_team, tf)
    att_team == ENEMY ? def_team = PLAYER : def_team = ENEMY

    att_forces = weapons(att_team) * tf.forces
    def_forces = weapons(def_team) * self.forces

    if def_forces > 0
      att_odds = [def_forces.to_f / att_forces, 14.0].min
      @attack_save = Math.exp(Math.log(0.8) * att_odds)

      def_odds = [att_forces.to_f / def_forces, 14.0].min
      @defend_save = Math.exp(Math.log(0.8) * def_odds)

      att_team == PLAYER ? printf("TF%c", tf.name) : print(" EN")

      printf(": %4d(weap %2d)sur: %4.0f\n", att_forces, weapons(att_team), @attack_save * 100)
      printf(" %c%d: %4d(weap %2d)sur: %4.0f\n", @star.name, self.number, def_forces, weapons(def_team), @defend_save * 100)

      first_time = true

      begin
        print "Attacker losses: "
        a_lose_none_c = tf.lose("c", @attack_save)
        a_lose_none_b = tf.lose("b", @attack_save)
        a_lose_none = a_lose_none_c && a_lose_none_b
        print "(none)" if a_lose_none

        print "\n  Planet losses: "
        p_lose_none_mb = self.lose("mb", @defend_save)
        p_lose_none_amb = self.lose("amb", @defend_save)
        p_lose_none = p_lose_none_mb && p_lose_none_amb
        print "(none)" if p_lose_none
      end while (!first_time && p_lose_none && a_lose_none)

      first_time = false
    end # def_forces > 0

    if (self.forces == 0) && tf.has_weapons?
      printf("\nPlanet %d falls!", self.number)
      self.team = att_team
      self.esee_team = att_team
      self.conquered = true
      self.star.summary
    end
  end # fire_salvo

  def blast(factors)
    @killed = [@capacity, factors / 4].min
    @inhabitants = [@inhabitants, @capacity].min - @killed
    @iu = [@iu - @killed, @inhabitants * 2].min
    @capacity -= @killed
    if @inhabitants <= 0
      @inhabitants = 0
      @iu = 0
      @mb = 0
      @amb = 0
      if @team != NONE
        @team = NONE
        @esee_team = NONE
        @conquered = false
      end
    end
  end # blast
end # planet
