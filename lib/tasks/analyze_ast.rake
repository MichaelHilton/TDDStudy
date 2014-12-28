root = '../'
require 'set'
require 'fileutils'
require_relative root + 'ASTInterface/ASTInterface'
require_relative root + 'OsDisk'			# required for dojo definition
require_relative root + 'Git'				# required for dojo definition
require_relative root + 'DummyTestRunner'	# required for dojo definition

ALLOWED_LANGS = Set["Java-1.8_JUnit"]

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


desc "parse Java project files and git to determine # of methods and # of asserts at each compile"
task :analyze_ast => :environment do
	ast_processing
end

def ast_processing
	build_dir = 'ast_builds'

	Session.where("language_framework = ?", ALLOWED_LANGS).find_each do |session|
		print "id: " + session.id.to_s + ", " if DEBUG
	    print "language: " + session.language_framework.to_s + ", " if DEBUG
		print "avatar: " + session.avatar.to_s + "\n" if DEBUG

		session.compiles.each_with_index do |curr, index|
			curr.total_test_method_count = 0
			asserts = 0 # placeholder for future db schema update to include total_test_assert_count
			light = dojo.katas[session.cyberdojo_id].avatars[session.avatar].lights[curr.git_tag]

			if light	# only lights that do not contain nil should be evaluated for files
				files = light.tag.visible_files.keys.select{ |filename| filename.include? ".java" }
				path = "#{build_dir}/" + light.number.to_s + "/src"
				FileUtils.mkdir_p path, :mode => 0700

				files.each do |file|
					File.open(path + "/" + file, 'w') { |f| f.write(light.tag.visible_files[file]) }					
					curr.total_test_method_count += findMethods(path + "/" + file)
					asserts += findAsserts(path + "/" + file)
				end
			
			print "  " + curr.git_tag.to_s + ":\t" if DEBUG
			print "methods: " + curr.total_test_method_count.to_s + ", " if DEBUG
			print "asserts: " + asserts.to_s + "\n" if DEBUG

			curr.save
			end
		end
	end

	FileUtils.remove_entry_secure(build_dir)
end