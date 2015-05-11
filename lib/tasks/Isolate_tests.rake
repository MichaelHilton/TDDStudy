task :Isolate_tests do
  isolate
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

def isolate
  # FileUtils.mkdir_p BUILD_DIR, :mode => 0700

  # SELECT KATAS WE WANT TO COMPUTE CYCLES
  # Session.find_by_sql("SELECT s.id,s.kata_name,s.cyberdojo_id,s.avatar FROM Sessions as s
  # INNER JOIN interrater_sessions as i on i.session_id = s.id").each do |session_id|
  #   # 2454    #
  # Session.find_by_sql("SELECT s.* FROM Sessions as s Join compiles as c on c.session_id = s.id WHERE s.language_framework LIKE \"Java-1.8_JUnit\" AND c.statement_coverage is Null and git_tag =1").each do |session_id|
  # Session.find_by_sql("SELECT s.* FROM Sessions as s Join compiles as c on c.session_id = s.id WHERE s.language_framework LIKE \"Java-1.8_JUnit\" AND c.statement_coverage is Null AND git_tag =1 AND s.id != 5064").each do |session_id|
  Session.find_by_sql("SELECT * FROM Sessions where id = 3578").each do |session_id|

    puts "CURR SESSION ID: " + session_id.id.to_s if CYCLE_DIAG
    puts session_id.inspect

    Session.where("id = ?", session_id.id).find_each do |curr_session|
      lastTime = nil
      `rm -rf ./Testing/`
      curr_session.compiles.each_with_index do |compile, index|
        puts "compile.git_tag: "+ compile.git_tag.to_s

        @avatar = dojo.katas[curr_session.cyberdojo_id].avatars[curr_session.avatar]
        curr_light = @avatar.lights[index]
        copy_source_files_to_working_directory(curr_light,compile, curr_session)

      end
    end
  end
end

def copy_source_files_to_working_directory(curLight,compile, curr_session)
  # puts "COPY SOURCE FILES"
  fileNames = curLight.tag.visible_files.keys
  javaFiles = fileNames.select { |name|  name.include? "java" }
  currLightDir =  "./workingDir/"+curLight.number.to_s
  currSessionDir = "./Testing/"

  #create the actual working directory
  `rm -rf ./workingDir/*`
  `mkdir ./workingDir/`
  `mkdir #{currLightDir}`
  `mkdir #{currLightDir}/src`
  `mkdir #{currSessionDir}`
  `mkdir #{currSessionDir}/Tests`



  #open files and grab class names
  currTestClass = ""
  javaFiles.each do |javaFileName|
    File.open(currLightDir+"/src/"+javaFileName, 'w') {|f| f.write(curLight.tag.visible_files[javaFileName]) }
    initialLoc = javaFileName.to_s =~ /test/i
    unless initialLoc.nil?
      fileNameParts = javaFileName.split('.')
      currTestClass = fileNameParts.first
    end
  end
  @statement_coverage = use_coverage_to_Isolate(curLight,currTestClass,currLightDir, currSessionDir)

end



def use_coverage_to_Isolate(curLight,currTestClass,currLightDir,currSessionDir)
  @statementCov = "NONE"

  if curLight.colour.to_s == "amber" || curLight.colour.to_s == "green"
    return
  else

    `mkdir #{currLightDir}/isrc`
    `rm -r ./*.clf`

    puts "starting Test Isolation"

   `java -jar ./vendor/calcCodeCovg/libs/codecover-batch.jar instrument --root-directory #{currLightDir}/src --destination #{currLightDir}/isrc --container #{currLightDir}/con.xml --language java --charset UTF-8`
    `javac -cp ./vendor/calcCodeCovg/libs/*:#{currLightDir}/isrc #{currLightDir}/isrc/*.java`
    results = `java -cp ./vendor/calcCodeCovg/libs/*:#{currLightDir}/isrc org.junit.runner.JUnitCore #{currTestClass}`

    puts "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"

    num_failures = 0
    single_test_failed = false

    results.lines.each do |item, obj|
      if item.include? "There was"
        re = /There was (?<failures>\d+) failure:/
        result = re.match(item)
        unless result.nil?
          num_failures = result['failures'].to_i
          if num_failures == 1
            single_test_failed = true
          end
        end
      
      elsif (item.start_with?("1)")) && single_test_failed
        item_split = item.split(/[\(\)]/)
        test_name = item_split[1].strip     
        Dir.mkdir(currSessionDir+"Tests/" + curLight.number.to_s)
        Dir.foreach("#{currLightDir}/src") do |file|
          intest = false
          braces = 0;
          test_string = ""
          file_string = ""
          unless file == "." || file == ".."
            f = File.open(currLightDir+"/src/"+file, 'r')
              f.each_line do |line|
                if line.include? "@Test"
                  intest = true
                  test_string = ""
                end

                if intest
                  braces = braces + line.count("{") - line.count("}")
                  test_string = test_string.concat(line)

                  if braces == 0 
                    unless line.include? "@Test"
                      intest = false
                      if test_string.include? test_name
                        file_string = file_string.concat(test_string)
                      end
                      test_string = ""
                    end
                  end
                else
                  file_string = file_string.concat(line)
                end
              end  
            f.close  
            puts file_string
            File.open(currSessionDir+"/Tests/"+curLight.number.to_s+"/"+file,'w') {|f| f.write(file_string) }
          end
        end

      end
    end

    puts "VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV"

  end
end