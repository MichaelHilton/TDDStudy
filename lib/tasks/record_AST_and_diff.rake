task :record_AST_and_diff do
  record_AST_and_diff
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


def root_path
  Rails.root.to_s + '/'
end



def record_AST_and_diff

  # SELECT KATAS WE WANT TO COMPUTE CYCLES
  Session.find_by_sql("SELECT s.id,s.kata_name,s.cyberdojo_id,s.avatar FROM Sessions as s
  INNER JOIN interrater_sessions as i on i.session_id = s.id WHERE s.id = 2456").each do |session|

    puts session.inspect
    session.compiles.each_with_index do |compile, index|
      puts "compile.git_tag: "+ compile.git_tag.to_s
      puts "index: "+ index.to_s


      # curr_light = dojo.katas[session.cyberdojo_id].avatars[session.avatar].lights[index]
      # curr_files = build_files(curr_light)
      # curr_files = curr_files.select{ |filename| filename.include? ".java" }
      # curr_filenames = curr_files.map{ |file| File.basename(file) }
      path = "#{BUILD_DIR}/" + compile.git_tag.to_s + "/src"

      session.compiles.each_cons(2) do |prev, curr|
        puts "prev: " + prev.git_tag.to_s + " -> curr: " + curr.git_tag.to_s

        prev_files = build_files(dojo.katas[session.cyberdojo_id].avatars[session.avatar].lights[prev.git_tag-1])
        curr_files = build_files(dojo.katas[session.cyberdojo_id].avatars[session.avatar].lights[curr.git_tag-1])

        puts curr_files.inspect


        prev_files = prev_files.select{ |filename| filename.include? ".java" }
        curr_files = curr_files.select{ |filename| filename.include? ".java" }

        prev_filenames = prev_files.map{ |file| File.basename(file) }
        curr_filenames = curr_files.map{ |file| File.basename(file) }


        # testChanges = false
        # productionChanges = false
        # curr.total_method_count = 0
        # curr.total_assert_count = 0
        # # cycle for each prev_files that exists in curr_files, run diff
        curr_filenames.each do |filename|
          prev_path = "#{BUILD_DIR}/" + prev.git_tag.to_s + "/src"
          curr_path = "#{BUILD_DIR}/" + curr.git_tag.to_s + "/src"

          puts "File To Match" + filename

          # if prev_filenames.include?(filename)
          #   if findChangeType(filename,prev_path,curr_path) == "Production"
          #     productionChanges = true
          #   end
          #   if findChangeType(filename,prev_path,curr_path) == "Test"
          #     testChanges = true
          #   end
          # else
          #   if findFileType(curr_path + "/" + filename) == "Production"
          #     productionChanges = true
          #   end
          #   if findFileType(curr_path + "/" + filename) == "Test"
          #     testChanges = true
          #   end
          # end

          puts treeAST(curr_path + "/" + filename)
          puts "&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&"
          puts diffAST(prev_path + "/" + filename, curr_path + "/" + filename)


          #Calculate Number of methods and asserts
          # curr.total_method_count += findMethods(curr_path + "/" + filename)
          # curr.total_assert_count += findAsserts(curr_path + "/" + filename)

        end
        # puts "testChanges: "+ testChanges.to_s if DEBUG
        # puts "productionChanges: "+ productionChanges.to_s if DEBUG

        # curr.test_change = testChanges
        # curr.prod_change = productionChanges
        # curr.total_method_count
        # curr.total_assert_count
        # puts "CURR SAVE"
        # curr.save
        # puts "----------------------"
        # FileUtils.remove_entry_secure(BUILD_DIR)
      end


    end
  end

  # SELECT KATAS WE WANT TO COMPUTE CYCLES
  # Session.find_by_sql("SELECT s.id,s.kata_name,s.cyberdojo_id,s.avatar FROM Sessions as s
  # INNER JOIN interrater_sessions as i on i.session_id = s.id").each do |session_id|

  # Session.find_by_sql("SELECT s.id,s.kata_name,s.cyberdojo_id,s.avatar FROM Sessions as s INNER JOIN interrater_sessions as i on i.session_id = s.id").each do |session_id|
  #   # Session.find_by_sql("SELECT s.id,s.kata_name,s.cyberdojo_id,s.avatar FROM Sessions as s WHERE s.id = 9").each do |session_id|
  #   # Session.find_by_sql("SELECT s.id,s.kata_name,s.cyberdojo_id,s.avatar FROM Sessions as s").each do |session_id|

  #   puts "CURR SESSION ID: " + session_id.id.to_s if CYCLE_DIAG

  #   FileUtils.remove_entry_secure(BUILD_DIR)

  #   Session.where("id = ?", session_id.id).find_each do |curr_session|
  #     # Session.where("id = ?", 2456).find_each do |curr_session|

  #     lastTime = nil
  #     curr_session.compiles.each_with_index do |compile, index|
  #       sloc = 0
  #       production_sloc = 0
  #       test_sloc = 0
  #       # puts compile.inspect
  #       puts "compile.git_tag: "+ compile.git_tag.to_s
  #       puts "index: "+ index.to_s

  #       curr_light = dojo.katas[curr_session.cyberdojo_id].avatars[curr_session.avatar].lights[index]
  #       curr_files = build_files(curr_light)
  #       curr_files = curr_files.select{ |filename| filename.include? ".java" }
  #       curr_filenames = curr_files.map{ |file| File.basename(file) }
  #       path = "#{BUILD_DIR}/" + compile.git_tag.to_s + "/src"

  #       Dir.entries(path).each do |currFile|
  #         # unless currFile.nil?
  #         # puts "currFile: " + currFile.to_s
  #         if currFile.to_s.length > 3
  #           file = path.to_s + "/" + currFile.to_s
  #           command = `./cloc-1.62.pl --by-file --quiet --sum-one --exclude-list-file=./clocignore --csv #{file}`
  #           # puts "./cloc-1.62.pl --by-file --quiet --sum-one --exclude-list-file=./clocignore --csv #{file}"
  #           # puts `pwd`
  #           # puts command
  #           csv = CSV.parse(command)
  #           # puts " csv.to_s: " + csv.to_s
  #           unless(csv.inspect == "[]")

  #             begin
  #               # puts "File Type: " + findFileType(file)
  #               if findFileType(file) == "Production"
  #                 # puts "sloc: " + csv[2][4].to_i.to_s

  #                 production_sloc = production_sloc + csv[2][4].to_i
  #                 # puts "PRODUCTION SLOC: " + production_sloc.to_s
  #               end
  #               if findFileType(file) == "Test"
  #                 test_sloc = test_sloc + csv[2][4].to_i
  #                 # puts "TEST SLOC: " + test_sloc.to_s
  #               end
  #             rescue
  #               # puts "Error: Reading in calc_sloc"
  #             end
  #             sloc = sloc + csv[2][4].to_i
  #           end
  #         end
  #       end
  #       puts "production_sloc: " + production_sloc.to_s
  #       puts "test_sloc: "+ test_sloc.to_s
  #       puts "SLOC: "+sloc.to_s
  #       compile.test_sloc_count = test_sloc.to_s
  #       compile.total_sloc_count = sloc.to_s
  #       compile.production_sloc_count = production_sloc.to_s

  #       puts "SAVED COMPILE: " + compile.id.to_s

  #       puts "$$$$$$$$$$$$$$$$$$$$ CompileTime $$$$$$$$$$$$$$$$$$$$"
  #       puts curr_light.time
  #       timeDiff = 0
  #       if index>0
  #         timeDiff = curr_light.time - lastTime
  #         puts "timeDiff: " + timeDiff.to_s

  #       end
  #       lastTime = curr_light.time
  #       if timeDiff > 300
  #         timeDiff = 300
  #       end
  #       compile.seconds_since_last_light = timeDiff
  #       compile.save
  #       puts "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"



  #     end
  #   end
  # end
end
