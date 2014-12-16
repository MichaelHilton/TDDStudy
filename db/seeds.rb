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

# Set to true for debug prints
DEBUG = false
CYCLE_DIAG = false

def root_path
  Rails.root.to_s + '/'
end

def number(value,width)
  spaces = ' ' * (width - value.to_s.length)
  "#{spaces}#{value.to_s}"
end

def dots(dot_count)
  dots = '.' * (dot_count % 32)
  spaces = ' ' * (32 - dot_count % 32)
  dots + spaces + number(dot_count,5)
end

def dojo
  externals = {
    :disk   => OsDisk.new,
    :git    => Git.new,
    :runner => DummyTestRunner.new
  }
  Dojo.new(root_path,externals)
end


######################
# New import function focusing on the static data that only needs to be imported once
# This should be all that is required in seeds.rb
# Implemented: 12-15-14 by Hugh
######################
def import_static_kata_data
  @katas = dojo.katas
  Session.delete_all
  Compile.delete_all

  print "\nPopulating DB with Static Kata Data\n"
  count = 0

  @katas.each do |kata|
    kata.avatars.active.each do |avatar|

      session = Session.new do |s|
        s.cyberdojo_id = kata.id
        s.avatar = avatar.name
      end
      session.save

      session = Session.find_by(cyberdojo_id: kata.id, avatar: avatar.name)
      puts "Processing: #{session}" if DEBUG
      session.kata_name = kata.exercise.name
      session.language_framework = kata.language.name
      session.path = avatar.path
      session.start_date = kata.created
      session.save

      avatar.lights.each_with_index do |light, index|
        compile = Compile.new
        compile.light_color = light.colour
        compile.git_tag = light.number
        compile.session = session
        compile.save
      end 
      count += 1
      print "\r " + dots(count)
    end
  end
end


def import_all_katas
  @katas = dojo.katas
  Session.delete_all
  Compile.delete_all

  i = 0
  @katas.each do |kata|
    #    puts " " if DEBUG
    #    print kata.id + " " if DEBUG
    #    print  kata.language.name + " " if DEBUG
    if(kata.language.name == "Java-1.8_JUnit")
      i+= 1
      kata.avatars.active.each do |avatar|
        #        print avatar.name + " " if DEBUG

        session = Session.new do |s|
          s.cyberdojo_id = kata.id
          s.avatar = avatar.name
        end
        session.save

        s = Session.find_by(cyberdojo_id: kata.id, avatar: avatar.name)
        @redlights = 0
        @greenlights = 0
        @amberlights = 0
        @path = avatar.path
        @sloc = 0
        @test_loc = 0
        @production_loc = 0
        @language = kata.language.name
        @runtests = 0
        @runtestfails = 0
        s.kata_name = kata.exercise.name
        # s.cyberdojo_id = kata.id
        s.language_framework = kata.language.name
        s.path = kata.path
        # s.avatar = avatar.name
        s.start_date = kata.created
        s.total_light_count = avatar.lights.count
        s.final_light_color = avatar.lights[avatar.lights.count-1].colour
        maxRedString = 1
        currRedString = 1
        lastLightColor = "none"
        avatar.lights.each do |curr_light|
          #Count Types of Lights
          case curr_light.colour.to_s
          when "red"
            @redlights += 1
            if(lastLightColor == "red")
              currRedString += 1
              if(currRedString > maxRedString)
                maxRedString = currRedString
              end
            else
              lastLightColor = "red"
            end
          when "green"
            @greenlights += 1
            lastLightColor = "green"
            currRedString = 1
          when "amber"
            @amberlights += 1
            lastLightColor = "amber"
            currRedString = 1
          end

          # puts "*********************DEBUG*********************" if DEBUG
          #puts curr_light.tag.diff(0)
          # puts curr_light.tag.visible_files.first if DEBUG
          # @compile = s.compiles.create(light_color: curr_light.colour.to_s, git_tag: curr_light.number.to_s)
        end
        s.red_light_count = @redlights
        s.green_light_count = @greenlights
        s.amber_light_count = @amberlights
        s.max_consecutive_red_chain_length = maxRedString
        # calc_sloc
        s.total_sloc_count = @sloc
        s.production_sloc_count = @production_loc
        s.test_sloc_count = @test_loc

        s.cumulative_test_run_count = @runtests
        s.cumulative_test_fail_count = @runtestfails
        #DO YOUR THiNG
        #s.final_number_tests = XX

        s.save

        #@compile = session.compiles.create(light_color: 'NO_COLOR')
      end
    end
    #     if(i > 4)
    #       break
    #     end
  end
end


def count_fails(prev, curr)

  runtests = 0
  runtestfails = 0

  #Take Diff
  if prev.nil? #If no previous light use the beginning
    diff = @avatar.tags[0].diff(curr.number)
  else
    diff = @avatar.tags[prev.number].diff(curr.number)
  end

  diff.each do |filename, content|
    if filename.include?"output"
      content.each do |line|

        case @language.to_s
        when "Java-1.8_JUnit"
          re = /\{:type=>:(added|same), :line=>\"Tests run: (?<tests>\d+),  Failures: (?<fails>\d+)\", :number=>\d+\}/
          result = re.match(line.to_s)

          unless result.nil?
            runtests += result['tests'].to_i
            runtestfails += result['fails'].to_i
          end
        end
      end
    end
  end

  return runtests, runtestfails
end

#TODO: Rewrite count_tests to work on diffs
def count_tests
  Dir.entries(@path.to_s + "sandbox").each do |currFile|
    isFile = currFile.to_s =~ /\.java$|\.py$|\.c$|\.cpp$|\.js$|\.php$|\.rb$|\.hs$|\.clj$|\.go$|\.scala$|\.coffee$|\.cs$|\.groovy$\.erl$/i

    unless isFile.nil?
      file = @path.to_s + "sandbox/" + currFile.to_s
      begin
        case @language.to_s
        when "Java-1.8_JUnit"
          if File.open(file).read.scan(/junit/).count > 0
            @totaltests += File.open(file).read.scan(/@Test/).count
          end
        when "Java-1.8_Mockito"
          if File.open(file).read.scan(/org\.mockito/).count > 0
            @totaltests += File.open(file).read.scan(/@Test/).count
          end
        when "Java-1.8_Powermockito"
          if File.open(file).read.scan(/org\.powermock/).count > 0
            @totaltests += File.open(file).read.scan(/@Test/).count
          end
        when "Java-1.8_Approval"
          if File.open(file).read.scan(/org\.approvaltests/).count > 0
            @totaltests += File.open(file).read.scan(/@Test/).count
          end
        when "Python-unittest"
          if File.open(file).read.scan(/unittest/).count > 0
            @totaltests += File.open(file).read.scan(/def /).count
          end
        when "Python-pytest"
          if file.include?"test"
            @totaltests += File.open(file).read.scan(/def /).count
          end
        when "Ruby-TestUnit"
          if File.open(file).read.scan(/test\/unit/).count > 0
            @totaltests += File.open(file).read.scan(/def /).count
          end
        when "Ruby-Rspec"
          if File.open(file).read.scan(/describe/).count > 0
            @totaltests += File.open(file).read.scan(/it /).count
          end
        when "C++-assert"
          if File.open(file).read.scan(/cassert/).count > 0
            @totaltests += File.open(file).read.scan(/static void /).count
          end
        when "C++-GoogleTest"
          if File.open(file).read.scan(/gtest\.h/).count > 0
            @totaltests += File.open(file).read.scan(/TEST\(/).count
          end
        when "C++-CppUTest"
          if File.open(file).read.scan(/CppUTest/).count > 0
            @totaltests += File.open(file).read.scan(/TEST\(/).count
          end
        when "C++-Catch"
          if File.open(file).read.scan(/catch\.hpp/).count > 0
            @totaltests += File.open(file).read.scan(/TEST_CASE\(/).count
          end
        when "C-assert"
          if File.open(file).read.scan(/assert\.h/).count > 0
            @totaltests += File.open(file).read.scan(/static void /).count
          end
        when "Go-testing"
          if File.open(file).read.scan(/testing/).count > 0
            @totaltests += File.open(file).read.scan(/func /).count
          end
        when "Javascript-assert"
          if File.open(file).read.scan(/assert/).count > 0
            @totaltests += File.open(file).read.scan(/assert/).count - 2 #2 extra because of library include line
          end
        when "C#-NUnit"
          if File.open(file).read.scan(/NUnit\.Framework/).count > 0
            @totaltests += File.open(file).read.scan(/\[Test\]/).count
          end
        when "PHP-PHPUnit"
          if File.open(file).read.scan(/PHPUnit_Framework_TestCase/).count > 0
            @totaltests += File.open(file).read.scan(/function /).count
          end
        when "Perl-TestSimple"
          if File.open(file).read.scan(/use Test/).count > 0
            @totaltests += File.open(file).read.scan(/is/).count
          end
        when "CoffeeScript-jasmine"
          if File.open(file).read.scan(/jasmine-node/).count > 0
            @totaltests += File.open(file).read.scan(/it/).count
          end
        when "Erlang-eunit"
          if File.open(file).read.scan(/eunit\.hrl/).count > 0
            @totaltests += File.open(file).read.scan(/test\(\)/).count
          end
        when "Haskell-hunit"
          if File.open(file).read.scan(/Test\.HUnit/).count > 0
            @totaltests += File.open(file).read.scan(/TestCase/).count
          end
        when "Scala-scalatest"
          if File.open(file).read.scan(/org\.scalatest/).count > 0
            @totaltests += File.open(file).read.scan(/test\(/).count
          end
        when "Clojure-.test"
          if File.open(file).read.scan(/clojure\.test/).count > 0
            @totaltests += File.open(file).read.scan(/deftest/).count
          end
        when "Groovy-JUnit"
          if File.open(file).read.scan(/org\.junit/).count > 0
            @totaltests += File.open(file).read.scan(/@Test/).count
          end
        when "Groovy-Spock"
          if File.open(file).read.scan(/spock\.lang/).count > 0
            @totaltests += File.open(file).read.scan(/def /).count - 1 #1 extra because of object def
          end
        else
          @totaltests = "NA"
        end
      rescue
        puts "Error: Reading in count_tests"
      end
    end
  end
end

def calc_lines(prev, curr)
  # determine number of lines changed between lights
  test_count = 0
  code_count = 0
  # regex for identifying edits and recording line_number
  re = /\{:type=>:(added|deleted), .* :number=>(?<line_number>\d+)\}/

  if prev.nil? #If no previous light use the beginning
    diff = @avatar.tags[0].diff(curr.number)
  else
    diff = @avatar.tags[prev.number].diff(curr.number)
  end

  diff.each do |filename,lines|

    is_test = false
    line_counted = Array.new
    isFile = filename.match(/\.java$|\.py$|\.c$|\.cpp$|\.js$|\.php$|\.rb$|\.hs$|\.clj$|\.go$|\.scala$|\.coffee$|\.cs$|\.groovy$\.erl$/i)

    unless isFile.nil? || deleted_file(lines) || new_file(lines)
      lines.each do |line|
        begin
          case @language.to_s
          when "Java-1.8_JUnit"
            is_test = true if /junit/.match(line.to_s)
          when "Java-1.8_Mockito"
            is_test = true if /org\.mockito/.match(line.to_s)
          when "Java-1.8_Powermockito"
            is_test = true if /org\.powermock/.match(line.to_s)
          when "Java-1.8_Approval"
            is_test = true if /org\.approvaltests/.match(line.to_s)
          when "Python-unittest"
            is_test = true if /unittest/.match(line.to_s)
          when "Python-pytest"
            is_test = true if filename.include?"test"
          when "Ruby-TestUnit"
            is_test = true if /test\/unit/.match(line.to_s)
          when "Ruby-Rspec"
            is_test = true if /describe/.match(line.to_s)
          when "C++-assert"
            is_test = true if /cassert/.match(line.to_s)
          when "C++-GoogleTest"
            is_test = true if /gtest\.h/.match(line.to_s)
          when "C++-CppUTest"
            is_test = true if /CppUTest/.match(line.to_s)
          when "C++-Catch"
            is_test = true if /catch\.hpp/.match(line.to_s)
          when "C-assert"
            is_test = true if /assert\.h/.match(line.to_s)
          when "Go-testing"
            is_test = true if /testing/.match(line.to_s)
          when "Javascript-assert"
            is_test = true if /assert/.match(line.to_s)
          when "C#-NUnit"
            is_test = true if /NUnit\.Framework/.match(line.to_s)
          when "PHP-PHPUnit"
            is_test = true if /PHPUnit_Framework_TestCase/.match(line.to_s)
          when "Perl-TestSimple"
            is_test = true if /use Test/.match(line.to_s)
          when "CoffeeScript-jasmine"
            is_test = true if /jasmine-node/.match(line.to_s)
          when "Erlang-eunit"
            is_test = true if /eunit\.hrl/.match(line.to_s)
          when "Haskell-hunit"
            is_test = true if /Test\.HUnit/.match(line.to_s)
          when "Scala-scalatest"
            is_test = true if /org\.scalatest/.match(line.to_s)
          when "Clojure-.test"
            is_test = true if /clojure\.test/.match(line.to_s)
          when "Groovy-JUnit"
            is_test = true if /org\.junit/.match(line.to_s)
          when "Groovy-Spock"
            is_test = true if /spock\.lang/.match(line.to_s)
          else
            #Language not supported
          end
        rescue
          puts "Error: Reading in calc_lines"
        end

        break if is_test == true
      end #End of Lines For Each

      if @NEW_EDIT_COUNT #New way of counting
        lines.each do |line|
          output = re.match(line.to_s)
          unless output.nil?
            unless line_counted.include?output['line_number'].to_i
              line_counted.push(output['line_number'].to_i)
              if is_test
                test_count += 1
              else
                code_count += 1
              end
            end
          end
        end
      else #Old way of counting
        if is_test
          test_count += lines.count { |line| line[:type] === :added }
          test_count += lines.count { |line| line[:type] === :deleted }
        else
          code_count += lines.count { |line| line[:type] === :added }
          code_count += lines.count { |line| line[:type] === :deleted }
        end
      end

    end #End of Unless statment
  end #End of Diff For Each

  return test_count, code_count
end

def deleted_file(lines)
  return lines.all? { |line| line[:type] === :deleted }
end

def new_file(lines)
  return lines.all? { |line| line[:type] === :added }
end

def copy_source_files_to_working_dir(curLight)
  fileNames = curLight.tag.visible_files.keys
  javaFiles = fileNames.select { |name|  name.include? "java" }
  currLightDir =  "./workingDir/"+curLight.number.to_s

  `rm -rf ./workingDir/*`
  `mkdir ./workingDir/`
  `mkdir #{currLightDir}`
  `mkdir #{currLightDir}/src`

  currTestClass = ""
  javaFiles.each do |javaFileName|
    File.open(currLightDir+"/src/"+javaFileName, 'w') {|f| f.write(curLight.tag.visible_files[javaFileName]) }
    initialLoc = javaFileName.to_s =~ /test/i
    unless initialLoc.nil?
      fileNameParts = javaFileName.split('.')
      currTestClass = fileNameParts.first
    end
  end
  justJavafilesDir = "#{currLightDir}/src"
  cloc_csv = `./cloc-1.62.pl --by-file --quiet --sum-one --exclude-list-file=./clocignore --csv #{justJavafilesDir}`
  sloc_csv = CSV.parse(cloc_csv)
  puts cloc_csv if DEBUG
  #TODO find a smarter way to do this: but this hack should work for short term
  print "SLOC_CSV.length " if DEBUG
  puts sloc_csv.length if DEBUG
  #puts "LENGTH"
  if sloc_csv.length > 2
    @light_test_sloc = sloc_csv[2][4].to_i

  end
  if sloc_csv.length > 3
    @light_prod_sloc = sloc_csv[3][4].to_i
  end
  @statement_coverage = calc_test_coverage(curLight,currTestClass,currLightDir)
end

def calc_test_coverage(curLight,currTestClass,currLightDir)
  if curLight.colour.to_s == "amber"
    return
  else

    # `mkdir ./workingDir`
    # `mkdir ./workingDir/codeCovg`
    `mkdir #{currLightDir}/isrc`
    # `rm -f ./workingDir/*`
    `rm -r ./*.clf`

    `java -jar ./vendor/calcCodeCovg/libs/codecover-batch.jar instrument --root-directory #{currLightDir}/src --destination #{currLightDir}/isrc --container #{currLightDir}/con.xml --language java --charset UTF-8`
    `javac -cp ./vendor/calcCodeCovg/libs/*:#{currLightDir}/isrc #{currLightDir}/isrc/*.java`
    `java -cp ./vendor/calcCodeCovg/libs/*:#{currLightDir}/isrc org.junit.runner.JUnitCore #{currTestClass}`
    `java -jar ./vendor/calcCodeCovg/libs/codecover-batch.jar analyze --container #{currLightDir}/con.xml --coverage-log *.clf --name test1`
    `java -jar ./vendor/calcCodeCovg/libs/codecover-batch.jar report --container #{currLightDir}/con.xml --destination #{currLightDir}/report.csv --session test1 --template ./vendor/calcCodeCovg/report-templates/CSV_Report.xml`

    if File.exist?(currLightDir + '/report.csv')
      codeCoverageCSV = CSV.read(currLightDir + '/report.csv')
      unless(codeCoverageCSV.inspect() == "[]")
        @statementCov  = codeCoverageCSV[2][16]
      end
      return @statementCov
    end
  end
end

def calculate_phase_totals()
  puts "calculate_phase_totals" if DEBUG
  phases = Phase.all
  phases.each do |phase|
    puts "Phase"
    compiles = phase.compiles
    puts "compile"
    totalTime = 0
    totalSLOC = 0
    compiles.each do |compile|
      # puts compile.inspect
      totalTime = totalTime + compile.seconds_since_last_light
      totalSLOC = totalSLOC + compile.total_sloc_count
    end
    puts "PHASE"
    puts phase
    puts "TotalSLOC"
    puts totalSLOC
    puts "totalTime"
    puts totalTime
    phase.total_sloc_count = totalSLOC
    phase.seconds_in_phase = totalTime
    phase.save
  end
end

import_static_kata_data
#import_all_katas
#build_cycle_data
#calculate_phase_totals
