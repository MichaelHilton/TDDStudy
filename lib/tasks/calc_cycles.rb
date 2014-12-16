# This data can be loaded with the rake db:seed (or created alongside the db with db:setup).
root = '..'

require_relative root + '/config/environment.rb'
require_relative root + '/lib/Docker'
require_relative root + '/lib/DockerTestRunner'
require_relative root + '/lib/DummyTestRunner'
require_relative root + '/lib/Folders'
require_relative root + '/lib/Git'
require_relative root + '/lib/HostTestRunner'
require_relative root + '/lib/OsDisk'
require_relative root + '/app/lib/ASTInterface'

include ASTInterface

CYCLE_DIAG = false

def root_path
  Rails.root.to_s + '/'
end


def build_cycle_data
  puts "build_cycle_data " if DEBUG

  Cycle.delete_all
  Phase.delete_all

  @NEW_EDIT_COUNT = true
  @TIME_CEILING = 1200 # Time Ceiling in Seconds Per Light
  @supp_test_langs = ["Java-1.8_JUnit", "Java-1.8_Mockito", "Java-1.8_Approval", "Java-1.8_Powermockito", "Python-unittest", "Python-pytest", "Ruby-TestUnit", "Ruby-Rspec", "C++-assert", "C++-GoogleTest", "C++-CppUTest", "C++-Catch", "C-assert", "Go-testing", "Javascript-assert", "C#-NUnit", "PHP-PHPUnit", "Perl-TestSimple", "CoffeeScript-jasmine", "Erlang-eunit", "Haskell-hunit", "Scala-scalatest", "Clojure-.test", "Groovy-JUnit", "Groovy-Spock"]
  @supp_fail_langs = ["Java-1.8_JUnit"]

  i = 0
  @katas = dojo.katas
  @katas.each do |kata|
    print kata.id+ " " if DEBUG
    print kata.language.name+ " " if DEBUG
    if(kata.language.name == "Java-1.8_JUnit")
      i+= 1
      #      print "Number ACTIVE avatars:"
      #      puts  kata.avatars.active.count
      #      puts  kata.id
      kata.avatars.active.each do |avatar|
        print avatar.name+ " " if DEBUG
        #Initialize Data
        @start_date = kata.created
        @total_time = 0
        @redlights = 0
        @greenlights = 0
        @amberlights = 0
        @consecutive_reds = 0
        @avatar = avatar
        @kata = kata
        @cycles = 0
        @edited_lines = 0
        @totaltests = 0

        #Calculate Cycle Data
        calc_cycles

      end
      # if(i > 2)
      #   break
      # end
    end
  end
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

  #Get Session
  curr_session = Session.where(cyberdojo_id: @kata.id, avatar: @avatar.name)
  puts "DEBUG: #{curr_session[0]}" if DEBUG
  curr_session = curr_session[0]

  #puts curr_session.inspect if DEBUG
  #New Cycle
  curr_cycle = Cycle.new(cycle_position: pos)

  #New Phases (use of extra phase is apparent in blue phase calculation)
  curr_phase = Phase.new(tdd_color: "red")
  extra_phase = Phase.new(tdd_color: "blue")

  #For Each Light
  @avatar.lights.each_with_index do |curr, index|
    puts "DEBUG CURR: #{curr}" if DEBUG
    puts "DEBUG INDEX: #{index}" if DEBUG
    #New Compile
    curr_compile = Compile.new

    @light_sloc = 0
    @light_test_sloc = 0
    @light_prod_sloc = 0

    #Compile Initialization
    curr_compile.test_change = false
    curr_compile.prod_change = false
    curr_compile.light_color = curr.colour
    curr_compile.git_tag = curr.number
    curr_compile.session_id = curr_session.id


    @statement_coverage = 0
    workingDir = copy_source_files_to_working_dir(curr)
    # puts "DDDDDDDDDDDD"
    # puts @statement_coverage
    curr_compile.statement_coverage = @statement_coverage

    # puts "CALCULATED SLOC:"
    # puts @light_test_sloc
    # puts  @light_prod_sloc

    curr_compile.test_sloc_count = @light_test_sloc
    curr_compile.production_sloc_count = @light_prod_sloc
    curr_compile.total_sloc_count = @light_test_sloc.to_i + @light_prod_sloc.to_i

    #Calculate Code Coverage for current Light
    # curr_compile.statement_coverage = calc_code_covg(curr)

    #Calculate SLOC
    # calc_light_sloc(curr)

    #Aquire file changes from light
    if index == 0
      diff = @avatar.tags[0].diff(index)
      curr_compile.test_change = true
    else
      diff = @avatar.tags[index - 1].diff(index)
    end

    #Check for changes to Test or Prod code
    diff.each do |filename, content|
      non_code_filenames = ['output', 'cyber-dojo.sh', 'instructions']
      unless non_code_filenames.include?(filename)
        if content.count { |line| line[:type] === :added } > 0 || content.count { |line| line[:type] === :deleted } > 0
          #Check if file is a Test
          if (filename.include?"Test") || (filename.include?"test") || (filename.include?"Spec") || (filename.include?"spec") || (filename.include?".t") || (filename.include?"Step") || (filename.include?"step")
            curr_compile.test_change = true
          else
            curr_compile.prod_change = true
          end
        end
      end
    end #End of Diff For Each

    #Count Lines Modified
    if index == 0 #If no previous light in this cycle use the last cycle's end
      test_edits, code_edits = calc_lines(nil, curr)
    else
      test_edits, code_edits = calc_lines(@avatar.lights[index - 1], curr)
    end

    #Store Lines to Model
    curr_compile.test_edited_line_count = test_edits
    curr_compile.production_edited_line_count = code_edits
    curr_compile.total_edited_line_count = test_edits + code_edits

    #Determine Time Spent
    if index == 0 #If the first light of the Kata
      time_diff = curr.time - @start_date
    else
      time_diff = curr.time - @avatar.lights[index - 1].time
    end

    #Drop Time if it hits the Time Ceiling
    if time_diff > @TIME_CEILING
      time_diff = 0
    end

    #Store Time to Model
    curr_compile.seconds_since_last_light = time_diff

    #################################
    #TODO: Count test methods in light
    #################################
    curr_compile.total_test_method_count = 0

    #Count Failed Tests
    if index == 0
      runtests, runtestfails = count_fails(nil, curr)
    else
      runtests, runtestfails = count_fails(@avatar.lights[index - 1], curr)
    end
    curr_compile.total_test_run_count = runtests
    curr_compile.total_test_run_fail_count = runtestfails

    #################################
    #TODO: Coverage, Total SLOC, Prod SLOC, Test SLOC
    #################################

    puts "*************" if CYCLE_DIAG
    puts "{" if CYCLE_DIAG
    puts "Light color: " + curr_compile.light_color.to_s if CYCLE_DIAG
    puts "Test edit: " + curr_compile.test_change.to_s if CYCLE_DIAG
    puts "Production edit: " + curr_compile.prod_change.to_s if CYCLE_DIAG

    puts "Current Phase: " + curr_phase.tdd_color.to_s if CYCLE_DIAG
    puts "Expected Phase: " + expected_phase(curr_compile).to_s if CYCLE_DIAG
    puts "Current Phase Empty?: " + curr_phase.compiles.empty?.to_s if CYCLE_DIAG

    #NEW LOGIC ============================
    case curr_phase.tdd_color
    
    when "red"
    
      if curr_compile.light_color.to_s == "red" || curr_compile.light_color.to_s == "amber"

        if curr_compile.test_change && curr_compile.prod_change #indicates green phase


          ##TODO: introoduce one new test etc. branches here

          #save phase before new curr_compile is added
          curr_phase.save

          puts "Start Green Phase" if CYCLE_DIAG
          curr_phase = Phase.new(tdd_color: "green")
          
          #new curr_compile is part of next phase, so save now
          puts "Saved curr_compile to green phase" if CYCLE_DIAG
          curr_phase.compiles << curr_compile

        elsif curr_compile.test_change && not curr_compile.prod_change


          curr_phase.compiles << curr_compile
          curr_compile.save
          puts "Saved curr_compile to red phase" if CYCLE_DIAG
        
        else #only prod edits in red phase indicates deviation from TDD


          puts "[!!] NON - TDD >> no red phase occured" if CYCLE_DIAG
      
          #NON TDD (no red phase occured)
          curr_cycle.valid_tdd = false
          curr_phase.tdd_color = "white"
      
          #save curr_compile to phase
          curr_phase.compiles << curr_compile
          curr_compile.save
       
        end

      else #green curr_compile state should not happen in red phase

        
          puts "[!!] NON - TDD >> no red phase occured" if CYCLE_DIAG
      
          #NON TDD (no red phase occured)
          curr_cycle.valid_tdd = false
          curr_phase.tdd_color = "white"
      
          #save curr_compile to phase
          curr_phase.compiles << curr_compile
          curr_compile.save
      
      end
    when "green"
      if curr_compile.light_color.to_s == "red" ||  curr_compile.light_color.to_s == "amber" 
    

        ##TODO: introoduce one new test etc. branches here

        #save curr_compile to phase
        curr_phase.compiles << curr_compile
        curr_compile.save
        
      else #green curr_compile indicates the green phase has ended, move on to refactor (or test if need be)
    

          #save current curr_compile to phase and phase to cycle
          curr_cycle.phases << curr_phase
          curr_phase.save
          
          puts "Saved curr_compile to green phase" if CYCLE_DIAG
          puts "Exit Green Phase" if CYCLE_DIAG
          puts "Start Blue phase" if CYCLE_DIAG
          
          #next phase (assume the next phase is blue)
          curr_phase = Phase.new(tdd_color: "blue")
      
      end
    when "blue"
      if curr_compile.light_color.to_s == "red" ||  curr_compile.light_color.to_s == "amber" 
    
        ##TODO: this is a placeholder, replace the following branch with new test logic
        if curr_compile.test_change || not curr_compile.prod_change #IF NEW TEST
        
          unless curr_phase.compiles.empty? #the blue phase is not empty
        

            curr_cycle.phases << curr_phase
            curr_phase.save
            puts "Start red phase" if CYCLE_DIAG
            curr_phase = Phase.new(tdd_color: "red")
            curr_phase.compiles << curr_compile
            puts "Saved curr_compile to red phase" if CYCLE_DIAG
        
          else
        

            puts "Start red phase" if CYCLE_DIAG
            curr_phase.tdd_color == "red"
            curr_phase.compiles << curr_compile
        
          end
              
          #End the Cycle
          pos += 1
          curr_session.cycles << curr_cycle
          curr_cycle.valid_tdd = true
          curr_cycle.save
          puts "Saved cycle" if CYCLE_DIAG
          curr_cycle = Cycle.new(cycle_position: pos)
      
        else #if no new test



        #save curr_compile to phase
        curr_phase.compiles << curr_compile
        curr_compile.save
        puts "Saved curr_compile to blue phase" if CYCLE_DIAG
      
        end

      else
      

        #save curr_compile to phase
        curr_phase.compiles << curr_compile
        curr_compile.save
        puts "Saved curr_compile to blue phase" if CYCLE_DIAG
      
      end
    
    when "white"
    
      if curr_compile.light_color.to_s == "red" || curr_compile.light_color.to_s == "amber" 
        

        ##TODO: this is a placeholder, replace the following branch with new test logic
        if curr_compile.test_change || not curr_compile.prod_change

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


  #END NEW LOGIC =====================================


  #Final Test Number
  count_tests
  curr_session.final_test_method_count = @totaltests

  #Determine if Kata Ends on Green
  if @avatar.lights[@avatar.lights.count - 1].colour.to_s == "green"
    @ends_green = 1
  else
    @ends_green = 0
  end

end

task :calc_cycles do
  build_cycle_data  
end