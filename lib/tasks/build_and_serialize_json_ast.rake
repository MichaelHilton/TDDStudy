task :build_and_serialize_json_ast do
  build_and_serialize_json_ast
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


def addChildrenToTree(childrenArray,curr_node)
  puts "========== CHILD =========="
  childrenArray.each do |child|

    root_node_hash = Hash.new
    root_node_hash["type"] = child["type"]
    root_node_hash["typeLabel"] = child["typeLabel"]
    root_node_hash["pos"] = child["pos"]
    root_node_hash["label"] = child["label"]
    root_node_hash["length"] = child["length"]

    nodeName = root_node_hash["pos"] + ":"+ root_node_hash["type"]
    puts nodeName

    curr_node << Tree::TreeNode.new(nodeName, root_node_hash)

    addChildrenToTree(child["children"],curr_node[nodeName])
  end
end


def build_AST_Tree(session_id,curr_path,filename,git_tag)
  puts "================ buildASTTree ================"
  ast_tree_string = treeAST(curr_path + "/" + filename)
  ast_tree = AstJsonTree.new
  ast_tree.filename = filename
  ast_tree.git_tag = git_tag
  ast_tree.session_id = session_id
  ast_tree.save

  json_ast_string = JSON.parse(ast_tree_string)

  root_node_hash = Hash.new
  root_node_hash["type"] = json_ast_string["type"]
  root_node_hash["typeLabel"] = json_ast_string["typeLabel"]
  root_node_hash["pos"] = json_ast_string["pos"]
  root_node_hash["label"] = json_ast_string["label"]
  root_node_hash["length"] = json_ast_string["length"]

  nodeName = root_node_hash["pos"] + ":"+ root_node_hash["type"]
  root_node = Tree::TreeNode.new(nodeName, root_node_hash)
  root_node.print_tree

  addChildrenToTree(json_ast_string["children"],root_node)
  puts "888888888888888 PRINT TREE 888888888888888"
  root_node.print_tree

  puts root_node.to_json
  ast_tree.ast_json_tree = root_node.to_json
  ast_tree.save
end


def build_and_serialize_json_ast
  FileUtils.mkdir_p BUILD_DIR, :mode => 0700
  AstTree.delete_all
  AstTreeNode.delete_all
  AstTreeRelationships.delete_all
  AstDiffNode.delete_all
  AstJsonTree.delete_all

  Session.find_by_sql("SELECT * from Sessions where tdd_score > .7 AND total_cycle_count > 3 AND id = 107").each do |session|

    puts "~~~~~~~~~~~~~~~~~~~~~~~~ Session "+session.id.to_s+" ~~~~~~~~~~~~~~~~~~~~~~~~"
    session.compiles.each_with_index do |compile, index|
      puts "index: "+ index.to_s

      path = "#{BUILD_DIR}/" + compile.git_tag.to_s + "/src"

      curr_files = build_files(dojo.katas[session.cyberdojo_id].avatars[session.avatar].lights[compile.git_tag-1])
      if(compile.git_tag == 1)
        curr_files = curr_files.select{ |filename| filename.include? ".java" }
        curr_filenames = curr_files.map{ |file| File.basename(file) }

        curr_filenames.each do |filename|
          # prev_path = "#{BUILD_DIR}/" + prev.git_tag.to_s + "/src"
          curr_path = "#{BUILD_DIR}/" + compile.git_tag.to_s + "/src"
          # puts "File To Match" + filename

          build_AST_Tree(session.id,curr_path,filename,compile.git_tag)
        end
      end
    end

    session.compiles.each_cons(2) do |prev, curr|
      puts "prev: " + prev.git_tag.to_s + " -> curr: " + curr.git_tag.to_s

      prev_files = Dir.entries("#{BUILD_DIR}/" + prev.git_tag.to_s + "/src")
      curr_files = Dir.entries("#{BUILD_DIR}/" + curr.git_tag.to_s + "/src")

      prev_files = prev_files.select{ |filename| filename.include? ".java" }
      curr_files = curr_files.select{ |filename| filename.include? ".java" }

      prev_filenames = prev_files.map{ |file| File.basename(file) }
      curr_filenames = curr_files.map{ |file| File.basename(file) }

      # puts "prev_filenames: "+ prev_filenames.inspect
      # puts "curr_filenames: "+ curr_filenames.inspect


      curr_filenames.each do |filename|
        prev_path = "#{BUILD_DIR}/" + prev.git_tag.to_s + "/src"
        curr_path = "#{BUILD_DIR}/" + curr.git_tag.to_s + "/src"

        # puts "File To Match: " + filename
        # puts "prev_path: " + prev_path
        # puts "curr_path: " + curr_path

        if prev_filenames.include?(filename)
          # puts "FOUND CHANGES FOR "+filename
          astDiffJSONArray = diffAST(prev_path + "/" + filename,curr_path + "/" + filename)
          puts astDiffJSONArray
          # saveASTChanges(astDiffJSONArray,session.id,curr.git_tag,filename)
        end
        build_AST_Tree(curr.id,curr_path,filename,curr.git_tag)
      end
    end
    FileUtils.remove_entry_secure(BUILD_DIR)
  end

end
