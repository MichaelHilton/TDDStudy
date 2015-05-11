task :find_impasse do
  find_impasse
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


def find_impasse
  Compile.find_by_sql("SELECT * FROM compiles as c Join sessions as s on c.session_id = s.id WHERE s.language_framework = \"Java-1.8_JUnit\" and (c.total_assert_count > (select n.total_assert_count from compiles as n where n.session_id = c.session_id and n.git_tag = c.git_tag + 1)) and ( c.light_color = \"red\" or c.light_color = \"amber\" ) and (select n.light_color from compiles as n where n.session_id = c.session_id and n.git_tag = c.git_tag + 1) = \"green\"").each do |curr|
    Session.where("id = ?", curr.session_id).find_each do |curr_session|
      puts "\n\n\n>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n" + " ID: " + curr_session.cyberdojo_id.to_s + " " + curr_session.avatar.to_s + "\n>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n\n\n"
      @avatar = dojo.katas[curr_session.cyberdojo_id].avatars[curr_session.avatar]
      curr_light = @avatar.lights[curr.git_tag - 1]
      if curr_light != nil
        fileNames = curr_light.tag.visible_files.keys
        javaFiles = fileNames.select { |name|  name.include? "java" }
        puts "^^^^^^^^^^^^^^^^^^^^^^^^^^^^\nBEFORE-------\nCOLOR: " + curr_light.colour.to_s + " TAG: " + curr.git_tag.to_s + "\n^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n\n\n"
        javaFiles.each do |javaFileName|
          puts "\n**************************************\n" + javaFileName.to_s + "\n**************************************\n"
          puts curr_light.tag.visible_files[javaFileName].to_s    
        end
      end
      puts "\n%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%\n\n"
      next_light = @avatar.lights[curr.git_tag]
      if next_light != nil
        fileNames = next_light.tag.visible_files.keys
        newjavaFiles = fileNames.select { |name|  name.include? "java" }
        puts "^^^^^^^^^^^^^^^^^^^^^^^^^^^^\nAFTER-------\nCOLOR: " + curr_light.colour.to_s + " TAG: " + curr.git_tag.to_s + "\n^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n\n\n"
        newjavaFiles.each do |javaFileName|
          puts "\n**************************************\n" + javaFileName.to_s + "\n**************************************\n"
          puts next_light.tag.visible_files[javaFileName].to_s    
        end
      end
    end
  end
end