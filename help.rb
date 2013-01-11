require_relative "const"

HELP0 = Hash[
  "B" => "Bld Battlestar(s)    #{CConst::B_COST}",
  "C" => "Bld Cruiser(s)       #{CConst::C_COST}",
  "H" => "Help"                   ,
  "R" => "Range Research"         ,
  "S" => "Bld Scout(s)          #{CConst::S_COST}",
  "V" => "Velocity Research"      ,
  "W" => "Weapons Research"       ,
  ">M" => "Redraw Map"            ,
  ">R" => "Research summary"]

HELP1 = Hash[
  "B" => "Blast Planet"         ,
  "C" => "Colony summary"       ,
  "D" => "TaskForce Destination",
  "G" => "Go on (done)"         ,
  "H" => "Help"                 ,
  "J" => "Join TaskForces"      ,
  "L" => "Land transports"      ,
  "M" => "Redraw Map"           ,
  "N" => "New TaskForce"        ,
  "Q" => "Quit"                 ,
  "R" => "Research summary"     ,
  "S" => "Star summary"         ,
  "T" => "TaskForce summary"]

HELP2 = Hash[
  "C" => "Colonies"         ,
  "G" => "Go on (done)"     ,
  "H" => "Help"             ,
  "M" => "Map"              ,
  "O" => "Odds"             ,
  "R" => "Research summary" ,
  "S" => "Star summary"     ,
  "T" => "TaskForce summary",
  "W" => "Withdraw"]

HELP3 = Hash[
  "B" => "Break off Attack" ,
  "C" => "Colony summary"   ,
  "G" => "Go on (done)"     ,
  "H" => "Help"             ,
  "J" => "Join TFs"         ,
  "M" => "Redraw Map"       ,
  "N" => "New TF"           ,
  "R" => "Research summary" ,
  "S" => "Star summary"     ,
  "T" => "TaskForce summary"]

HELP4 = Hash[
   "A" => "Bld Adv. Missle Base #{CConst::AMB_COST}",
   "B" => "Bld Battlestar(s)    #{CConst::B_COST}",
   "C" => "Bld Cruiser(s)       #{CConst::C_COST}",
   "H" => "Help"                   ,
   "I" => "Invest                3",
   "M" => "Bld Missle Base(s)    #{CConst::MB_COST}",
   "R" => "Range Research"         ,
   "S" => "Bld Scout(s)          #{CConst::S_COST}",
   "T" => "Bld Transports"         ,
   "V" => "Vel Research"           ,
   "W" => "Weapons Research"       ,
  ">C" => "Colony summary"         ,
  ">M" => "Redraw Map"             ,
  ">R" => "Research summary"       ,
  ">S" => "Star summary"           ]

def help(which)
  case which
  when 0
    h = HELP0
  when 1
    h = HELP1
  when 2
    h = HELP2
  when 3
    h = HELP3
  when 4
    h = HELP4
  end

  print"\n"
  h.each { |k,v| printf "%2s - %-25s\n", k, v }
end
