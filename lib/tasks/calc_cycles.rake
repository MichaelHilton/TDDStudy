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

# ALLOWED_LANGS = Set["Java-1.8_JUnit"]

  #Get Session
  # Session.all.each do |curr_session|
  Session.where("language_framework = ?", "Java-1.8_JUnit").find_each do |curr_session|
    puts "CYCLE_DIAG: #{curr_session[0]}" if CYCLE_DIAG

    #New Cycle
    curr_cycle = Cycle.new(cycle_position: pos)

    #New Phases (use of extra phase is apparent in blue phase calculation)
    curr_phase = Phase.new(tdd_color: "red")
    extra_phase = Phase.new(tdd_color: "blue")

    #For Each Light
    curr_session.compiles.each_with_index do |curr_compile, index|
      
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

      if(!curr_compile.test_change && !curr_compile.prod_change)
        puts "NO MEANINGFUL CHANGE" if CYCLE_DIAG
        next
      end
      #NEW LOGIC ============================
      case curr_phase.tdd_color

      when "red"
        if curr_compile.light_color.to_s == "red" || curr_compile.light_color.to_s == "amber"
          
          if curr_compile.test_change && !curr_compile.prod_change
            curr_phase.compiles << curr_compile
            curr_compile.save
            puts "Saved curr_compile to red phase" if CYCLE_DIAG
          
          elsif curr_compile.test_change && curr_compile.prod_change
          
            if new_test
              #save phase before new curr_compile is added
              curr_phase.save

              puts "Start Green Phase" if CYCLE_DIAG
              curr_phase = Phase.new(tdd_color: "green")
              
              #new curr_compile is part of next phase, so save now
              puts "Saved curr_compile to green phase" if CYCLE_DIAG
              curr_phase.compiles << curr_compile
              
              #reset new_test
              new_test = false
            else
              puts "[!!] NON - TDD >> no new test and production edits occured" if CYCLE_DIAG
          
              #NON TDD (no red phase occured)
              curr_cycle.valid_tdd = false
              curr_phase.tdd_color = "white"
          
              #save curr_compile to phase
              curr_phase.compiles << curr_compile
              curr_compile.save
          
              #reset new_test
              new_test = false
            end
          
          else #only prod edits in red phase indicates deviation from TDD
          
            if new_test
              #save phase before new curr_compile is added
              curr_phase.save

              puts "Start Green Phase" if CYCLE_DIAG
              curr_phase = Phase.new(tdd_color: "green")
              
              #new curr_compile is part of next phase, so save now
              puts "Saved curr_compile to green phase" if CYCLE_DIAG
              curr_phase.compiles << curr_compile
          
              #reset new_test
              new_test = false
            else  
              puts "[!!] NON - TDD >> no new test for testing phase" if CYCLE_DIAG
          
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
        
        else #green curr_compile state should not happen in red phase
        
          if curr_compile.test_change && !curr_compile.prod_change
            curr_phase.compiles << curr_compile
            curr_compile.save
            puts "Saved curr_compile to red phase" if CYCLE_DIAG
          
          else
            puts "[!!] NON - TDD >> production edits in testing phase" if CYCLE_DIAG
        
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
      
      when "green"
      
        if curr_compile.light_color.to_s == "red" ||  curr_compile.light_color.to_s == "amber" 
          if !new_test
            #save curr_compile to phase
            curr_phase.compiles << curr_compile
            curr_compile.save
          
          else
            puts "[!!] NON - TDD >> new test in green phase!" if CYCLE_DIAG
        
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
            puts "[!!] NON - TDD >> new test in green phase!" if CYCLE_DIAG
        
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
        
        if curr_compile.light_color.to_s == "red" ||  curr_compile.light_color.to_s == "amber" 
     
          if new_test
            #save the current data as blue
            curr_cycle.phases << curr_phase
            curr_phase.save

            #End the Cycle
            pos += 1
            curr_session.cycles << curr_cycle
            curr_cycle.valid_tdd = true
            curr_cycle.save
            puts "Saved cycle" if CYCLE_DIAG
            curr_cycle = Cycle.new(cycle_position: pos)
            #start new phase
            puts "Start red phase" if CYCLE_DIAG
            #copy extraFrame to phaseFrame because extraFrame consists of new red phase
            extra_phase.compiles.each do |current|
              curr_phase.compiles << current
            end
            curr_phase.tdd_color = "red"
            curr_phase.compiles << curr_compile
            puts "Saved curr_compile to red phase" if CYCLE_DIAG
          else
            #save curr_compile to extraFrame
            extra_phase.compiles << curr_compile
            curr_compile.save  
          end

        else #curr_compile is green
    
          if !new_test
    
            if not extra_phase.compiles.empty?
              #concatenate extraFrame to phaseFrame
              extra_phase.compiles.each do |current|
                curr_phase.compiles << current          
              end
            end
            #save curr_compile to phase
            curr_phase.compiles << curr_compile
            curr_compile.save
            puts "Saved curr_compile to blue phase" if CYCLE_DIAG
          
          else
            
            puts "[!!] NON - TDD >> new test in green phase!" if CYCLE_DIAG
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
          

          ##TODO: this is a placeholder, replace the following branch with new test logic
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

      end

      puts "}" if CYCLE_DIAG
      puts "*************" if CYCLE_DIAG

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