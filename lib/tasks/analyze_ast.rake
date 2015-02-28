root = '../'
require 'set'
require 'fileutils'
require_relative root + 'ASTInterface/ASTInterface'
require_relative root + 'OsDisk'      # required for dojo definition
require_relative root + 'Git'       # required for dojo definition
require_relative root + 'DummyTestRunner' # required for dojo definition

BUILD_DIR = 'ast_builds'

def root_path
  Rails.root.to_s + '/'
end

def dojo
  externals = {
    :disk   => OsDisk.new,
    :git    => Git.new,
    :runner => DummyTestRunner.new
  }
  Dojo.new(root_path,externals)
end

def dots(dot_count)
  dots = '.' * (dot_count % 32)
  spaces = ' ' * (32 - dot_count % 32)
  dots + spaces + number(dot_count,5)
end

def defaultSetup(curr_path)
  puts "DEFAULT_SETUP" if DEBUG
  if(File.exist?(curr_path + "\/Untitled.java") && File.exist?(curr_path + "\/UntitledTest.java"))
    file = File.open(curr_path + "\/Untitled.java" , "rb")
    contents = file.read

    test_file = File.open(curr_path + "\/UntitledTest.java" , "rb")
    test_contents = test_file.read

    templateProduction = "\npublic class Untitled {\n    \n    public static int answer() {\n        return 42;\n    }\n}\n"
    template_test = "import org.junit.*;\nimport static org.junit.Assert.*;\n\npublic class UntitledTest {\n    \n    @Test\n    public void hitch_hiker() {\n        int expected = 6 * 9;\n        int actual = Untitled.answer();\n        assertEquals(expected, actual);\n    }\n}\n"

    if(templateProduction == contents)
      if template_test == test_contents
        puts "EQUAL" if DEBUG
        return true
      end
    end
  end

  if(File.exist?(curr_path + "\/Hiker.java") && File.exist?(curr_path + "\/HikerTest.java"))
    file = File.open(curr_path + "\/Hiker.java" , "rb")
    contents = file.read

    # puts "FILE:"
    # puts contents.inspect

    test_file = File.open(curr_path + "\/HikerTest.java" , "rb")
    test_contents = test_file.read

    # puts "Test FILE:"
    # puts test_contents.inspect

    templateProduction = "\npublic class Hiker {\n\n    public static int answer() {\n        return 6 * 9;\n    }\n}\n"
    template_test = "import org.junit.*;\nimport static org.junit.Assert.*;\n\npublic class HikerTest {\n\n    @Test\n    public void life_the_universe_and_everything() {\n        int expected = 42;\n        int actual = Hiker.answer();\n        assertEquals(expected, actual);\n    }\n}\n"



    if(templateProduction == contents)
      if template_test == test_contents
        puts "EQUAL" if DEBUG
        return true
      end
    end
  end
  return false
end


def build_files(light, language_framework)
  filenames = []
  filepaths = []

  #restrict to only lights that contain files
  if light
    files = light.tag.visible_files.keys.select{ |filename| filename.end_with? ALLOWED_LANGS[language_framework] }
    path = "#{BUILD_DIR}/" + light.number.to_s + "/src"

    FileUtils.mkdir_p path, :mode => 0700
    #puts "created path: #{path}"

    files.each do |file|
      if (light.tag.visible_files[file].length > 1)
        #create file and write all content to it
        File.open(path + "/" + File.basename(file), 'w') { |f| f.write(light.tag.visible_files[file]) }

        #save filenames and filepaths
        filenames << (file)
        filepaths << (path + "/" + file)

        #puts "created file: #{path}/#{file}"
      end
    end
  end

  filepaths
end


desc "parse project files and git to determine # of methods and # of asserts at each compile"
task :analyze_ast => :environment do
  ast_processing
end

def ast_processing
  count = 0
  FileUtils.mkdir_p BUILD_DIR, :mode => 0700

  Session.find_by_sql("SELECT id,kata_name,cyberdojo_id,avatar FROM Sessions").each do |session_id|

    # limit to kata sessions that use supported language/testing frameworks
    # Session.where("language_framework = ?", ALLOWED_LANGS).find_each do |session|
    Session.where("id = ?", session_id.id).find_each do |session|
      print "id: " + session.id.to_s + ", " if DEBUG
      print "cyberdojo_id: " + session.cyberdojo_id.to_s + ", " if DEBUG
      print "language: " + session.language_framework.to_s + ", " if DEBUG
      print "avatar: " + session.avatar.to_s + "\n" if DEBUG

      #HANDLE THE FIRST COMPILE POINT
      puts session.compiles[0].inspect if DEBUG

      # puts dojo.katas[session.cyberdojo_id].avatars[session.avatar].lights[0]
      firstCompile = session.compiles.first
      curr_files = build_files(dojo.katas[session.cyberdojo_id].avatars[session.avatar].lights[0], session.language_framework)
      #curr_files = curr_files.select{ |filename| filename.include? ".java" }
      curr_filenames = curr_files.map{ |file| File.basename(file) }

      testChanges = false
      productionChanges = false
      firstCompile.total_method_count = 0
      firstCompile.total_assert_count = 0

      curr_path = "#{BUILD_DIR}/1/src"

      if defaultSetup(curr_path)
        productionChanges = false
        testChanges = false
        firstCompile.total_method_count = 0
        firstCompile.total_assert_count = 0
      else
        curr_filenames.each do |filename|

          puts curr_path + "/" + filename if DEBUG
          if findFileType(curr_path + "/" + filename, session.language_framework) == "Production"
            productionChanges = true
          end
          if findFileType(curr_path + "/" + filename, session.language_framework) == "Test"
            testChanges = true
          end
          firstCompile.total_method_count += findMethods(curr_path + "/" + filename, session.language_framework)
          firstCompile.total_assert_count += findAsserts(curr_path + "/" + filename, session.language_framework)
        end
      end
      puts "testChanges: "+ testChanges.to_s if DEBUG
      puts "productionChanges: "+ productionChanges.to_s if DEBUG

      firstCompile.test_change = testChanges
      firstCompile.prod_change = productionChanges
      firstCompile.total_method_count
      firstCompile.total_assert_count
      firstCompile.save
      puts "----------------------" if DEBUG

      session.compiles.each_cons(2) do |prev, curr|
        puts "prev: " + prev.git_tag.to_s + " -> curr: " + curr.git_tag.to_s if DEBUG

        prev_files = build_files(dojo.katas[session.cyberdojo_id].avatars[session.avatar].lights[prev.git_tag-1], session.language_framework)
        curr_files = build_files(dojo.katas[session.cyberdojo_id].avatars[session.avatar].lights[curr.git_tag-1], session.language_framework)

        puts curr_files.inspect if DEBUG

        prev_files = prev_files.select{ |filename| filename.end_with? ALLOWED_LANGS[session.language_framework] }
        curr_files = curr_files.select{ |filename| filename.end_with? ALLOWED_LANGS[session.language_framework] }

        prev_filenames = prev_files.map{ |file| File.basename(file) }
        curr_filenames = curr_files.map{ |file| File.basename(file) }

        testChanges = false
        productionChanges = false
        curr.total_method_count = 0
        curr.total_assert_count = 0
        # cycle for each prev_files that exists in curr_files, run diff
        curr_filenames.each do |filename|
          prev_path = "#{BUILD_DIR}/" + prev.git_tag.to_s + "/src"
          curr_path = "#{BUILD_DIR}/" + curr.git_tag.to_s + "/src"

          puts "File To Match" + filename if DEBUG

          if prev_filenames.include?(filename)
            if findChangeType(filename,prev_path,curr_path, session.language_framework) == "Production"
              productionChanges = true
            end
            if findChangeType(filename,prev_path,curr_path, session.language_framework) == "Test"
              testChanges = true
            end
          else
            if findFileType(curr_path + "/" + filename, session.language_framework) == "Production"
              productionChanges = true
            end
            if findFileType(curr_path + "/" + filename, session.language_framework) == "Test"
              testChanges = true
            end
          end

          #Calculate Number of methods and asserts
          curr.total_method_count += findMethods(curr_path + "/" + filename, session.language_framework)
          curr.total_assert_count += findAsserts(curr_path + "/" + filename, session.language_framework)

        end
        puts "testChanges: "+ testChanges.to_s if DEBUG
        puts "productionChanges: "+ productionChanges.to_s if DEBUG

        curr.test_change = testChanges
        curr.prod_change = productionChanges
        curr.total_method_count
        curr.total_assert_count
        puts "CURR SAVE" if DEBUG
        curr.save
        puts "----------------------" if DEBUG
        FileUtils.remove_entry_secure(BUILD_DIR)
      end

      count += 1
      print "\r " + dots(count)
    end
  end


end
