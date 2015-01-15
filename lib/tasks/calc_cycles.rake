task :calc_cycles do
  calc_cycles
end

# This data can be loaded with the rake db:seed (or created alongside the db with db:setup).
root = '../..'

require_relative root + '/config/environment.rb'
require_relative root + '/lib/Docker'
require_relative root + '/lib/DockerTestRunner'
require_relative root + '/lib/DummyTestRunner'
require_relative root + '/lib/Folders'
require_relative root + '/lib/Git'
require_relative root + '/lib/HostTestRunner'
require_relative root + '/lib/OsDisk'
require_relative root + '/lib/ASTInterface/ASTInterface'


CYCLE_DIAG = true
ALLOWED_LANGS = Set["Java-1.8_JUnit"]


def root_path
  Rails.root.to_s + '/'
end



def calc_cycles
  pos = 0
  prev_outer = nil
  prev_cycle_end = nil
  test_change = false
  prod_change = false
  in_cycle = false
  cycle = ""
  cycle_lights = Array.new
  cycle_test_edits = 0
  cycle_code_edits = 0
  cycle_total_edits = 0
  cycle_test_change = 0
  cycle_code_change = 0
  cycle_reds = 0
  cycle_time = 0
  first_cycle = true
  curr_num_tests = 0
  new_test = false
  valid_red = false

# ALLOWED_LANGS = Set["Java-1.8_JUnit"]

  Cycle.delete_all
  Phase.delete_all


  #Get Session
  # Session.where("language_framework = ?", ALLOWED_LANGS).find_each do |curr_session|
  Session.where("id = ?", 2456).find_each do |curr_session|

    puts "CYCLE_DIAG: #{curr_session[0]}" if CYCLE_DIAG

    #New Cycle
    curr_cycle = Cycle.new(cycle_position: pos)

    #New Phases (use of extra phase is apparent in blue phase calculation)
    curr_phase = Phase.new(tdd_color: "red")
    extra_phase = Phase.new(tdd_color: "blue")

    last_light_color = "red"
    #For Each Light
    curr_session.compiles.each_with_index do |curr_compile, index|
      new_test = false
      #check for new test in compiles
      if !curr_compile.total_assert_count.nil?
        if curr_compile.total_assert_count > curr_num_tests
          new_test = true
          curr_num_tests = curr_compile.total_assert_count
        end
      end
      puts "CYCLE_DIAG CURR: #{curr_compile}" if CYCLE_DIAG
      puts "CYCLE_DIAG INDEX: #{index}" if CYCLE_DIAG


      puts "*************" if CYCLE_DIAG
      puts "{" if CYCLE_DIAG
      puts "Light color: " + curr_compile.light_color.to_s if CYCLE_DIAG
      puts "Test edit: " + curr_compile.test_change.to_s if CYCLE_DIAG
      puts "Production edit: " + curr_compile.prod_change.to_s if CYCLE_DIAG

      puts "Current Phase: " + curr_phase.tdd_color.to_s if CYCLE_DIAG
      puts "Current Phase Empty?: " + curr_phase.compiles.empty?.to_s if CYCLE_DIAG
      puts "New Test?: " + new_test.to_s if CYCLE_DIAG

      if !curr_compile.test_change && !curr_compile.prod_change && (last_light_color == curr_compile.light_color.to_s)
          curr_phase.compiles << curr_compile
          curr_compile.save
          puts "Saved curr_compile to current phase" if CYCLE_DIAG
      else

puts "%%%%%%%%%%%  Start CASE  %%%%%%%%%%%"
        #cycle logic
        case curr_phase.tdd_color

        when "red"

          if new_test
            valid_red = true
          end
          
          if curr_compile.light_color.to_s == "red" || curr_compile.light_color.to_s == "amber"
            
            if curr_compile.test_change && !curr_compile.prod_change
              curr_phase.compiles << curr_compile
              curr_compile.save
              puts "Saved curr_compile to red phase" if CYCLE_DIAG
            
            elsif curr_compile.test_change && curr_compile.prod_change
            
              if valid_red
                #save phase before new curr_compile is added
                curr_phase.save
                curr_cycle.phases << curr_phase

                puts "Start Green Phase1" if CYCLE_DIAG
                curr_phase = Phase.new(tdd_color: "green")
                
                #new curr_compile is part of next phase, so save now
                puts "Saved curr_compile to green phase" if CYCLE_DIAG
                curr_phase.compiles << curr_compile
              else
                puts "[!1!] NON - TDD >> no new test and production edits occured" if CYCLE_DIAG
            
                #NON TDD (no red phase occured)
                curr_cycle.valid_tdd = false
                curr_phase.tdd_color = "white"
            
                #save curr_compile to phase
                curr_phase.compiles << curr_compile
                curr_compile.save
              end
              #reset new_test
              valid_red = false
            
            else #only prod edits in red phase indicates deviation from TDD
            
              if !new_test
                #save phase before new curr_compile is added
                curr_cycle.phases << curr_phase
                curr_phase.save

                puts "Start Green Phase2" if CYCLE_DIAG
                curr_phase = Phase.new(tdd_color: "green")
                
                #new curr_compile is part of next phase, so save now
                puts "Saved curr_compile to green phase" if CYCLE_DIAG
                curr_phase.compiles << curr_compile
              else  
                puts "[!2!] NON - TDD >> no new test for testing phase" if CYCLE_DIAG
            
                #NON TDD (no red phase occured)
                curr_cycle.valid_tdd = false
                curr_phase.tdd_color = "white"
            
                #save curr_compile to phase
                curr_phase.compiles << curr_compile
                curr_compile.save
              end
              #reset new_test
              valid_red = false

            end
          
          else #green curr_compile with valid_red indicates green phase
          
            if valid_red
                #save phase before new curr_compile is added
                curr_phase.save
                curr_cycle.phases << curr_phase

                puts "Start Green Phase3" if CYCLE_DIAG
                curr_phase = Phase.new(tdd_color: "green")
                
                #new curr_compile is part of next phase, so save now
                puts "Saved curr_compile to green phase and end green phase" if CYCLE_DIAG
                curr_phase.compiles << curr_compile
                curr_phase.save

                #on to blue
                puts "Start Blue Phase" if CYCLE_DIAG
                curr_phase = Phase.new(tdd_color: "blue")
            
            elsif curr_compile.test_change && !curr_compile.prod_change
              curr_phase.compiles << curr_compile
              curr_compile.save
              puts "Saved curr_compile to red phase" if CYCLE_DIAG
            else
              puts "[!3!] NON - TDD >> production edits in testing phase" if CYCLE_DIAG
          
              #NON TDD (no red phase occured)
              curr_cycle.valid_tdd = false
              curr_phase.tdd_color = "white"
          
              #save curr_compile to phase
              curr_phase.compiles << curr_compile
              curr_compile.save

            end  
            #reset new_test
            valid_red = false
          end
        
        when "green"
        
          if curr_compile.light_color.to_s == "red" ||  curr_compile.light_color.to_s == "amber" 
            if !new_test
              #save curr_compile to phase
              curr_phase.compiles << curr_compile
              curr_compile.save
            
            else
              puts "[!4!] NON - TDD >> new test in green phase!" if CYCLE_DIAG
          
              #NON TDD (no red phase occured)
              curr_cycle.valid_tdd = false
              curr_phase.tdd_color = "white"
          
              #save curr_compile to phase
              curr_phase.compiles << curr_compile
              curr_compile.save
            
              #reset new_test
              new_test = false
            end

          else #green curr_compile indicates the green phase has ended, move on to refactor (or test if need be)
      
            if !new_test
              #save current curr_compile to phase and phase to cycle
              curr_cycle.phases << curr_phase
              curr_phase.save
              
              puts "Saved curr_compile to green phase" if CYCLE_DIAG
              puts "Exit Green Phase" if CYCLE_DIAG
              puts "Start Blue phase" if CYCLE_DIAG
              
              #next phase (assume the next phase is blue)
              curr_phase = Phase.new(tdd_color: "blue")
      
            else
              puts "[!5!] NON - TDD >> new test in green phase!" if CYCLE_DIAG
          
              #NON TDD (no red phase occured)
              curr_cycle.valid_tdd = false
              curr_phase.tdd_color = "white"
          
              #save curr_compile to phase
              curr_phase.compiles << curr_compile
              curr_compile.save
            
              #reset new_test
              new_test = false
      
            end
          
          end

        when "blue"
          
          if curr_compile.light_color.to_s == "red", curr_compile.light_color.to_s == "red" && new_test 
            #save phase to cycle, save cycle to session
            curr_cycle.phases << curr_phase
            curr_phase.save
            curr_session.cycles << curr_cycle
            curr_cycle.save

            #new cycle, phase
            curr_phase = Phase.new(tdd_color: "red")
            curr_cycle = Cycle.new(cycle_position: pos)
            curr_phase.compiles << curr_compile
            puts "Saved curr_compile to red phase" if CYCLE_DIAG    
              
          else #curr_compile is green
      
            if !new_test
      
              #save curr_compile to phase
              curr_phase.compiles << curr_compile
              curr_compile.save
              puts "Saved curr_compile to blue phase" if CYCLE_DIAG
            
            else
              
              puts "[!6!] NON - TDD >> new test in blue phase!" if CYCLE_DIAG
              #NON TDD (no red phase occured)
              curr_cycle.valid_tdd = false
              curr_phase.tdd_color = "white"
              #save curr_compile to phase
              curr_phase.compiles << curr_compile
              curr_compile.save
              #reset new_test
              new_test = false
            
            end

          end
          
        when "white"
        
          if curr_compile.light_color.to_s == "red" || curr_compile.light_color.to_s == "amber" 
            
            if curr_compile.test_change || !curr_compile.prod_change

              pos += 1
              curr_cycle.phases << curr_phase
              curr_phase.save
              curr_session.cycles << curr_cycle
              curr_cycle.save
              puts "Exit white phase" if CYCLE_DIAG
              curr_phase = Phase.new(tdd_color: "red")
              curr_cycle = Cycle.new(cycle_position: pos)
              curr_phase.compiles << curr_compile
              curr_compile.save
            
            end

          else        

            #save curr_compile to phase
            curr_phase.compiles << curr_compile
            curr_compile.save
            puts "Inside white phase" if CYCLE_DIAG
          
          end

        end #end of cycle logic

      end
      puts "}" if CYCLE_DIAG
      puts "*************" if CYCLE_DIAG
      last_light_color = curr_compile.light_color.to_s
    end #End of For Each Light

    #check if the last cycle finished
    if curr_phase.tdd_color == "blue"
      curr_cycle.valid_tdd = true
    end  

    curr_cycle.phases << curr_phase
    curr_session.cycles << curr_cycle
    curr_phase.save
    curr_cycle.save

  end # end of for all sessions

end
