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

def store_AST_Tree(session_id,curr_path,filename,git_tag)
  puts "store_AST_Tree"
  ast_tree_string = treeAST(curr_path + "/" + filename)
  # puts ast_tree_string
  ast_tree = AstTree.new
  ast_tree.filename = filename
  ast_tree.git_tag = git_tag
  ast_tree.session_id = session_id
  ast_tree.save

  json_ast_string = JSON.parse(ast_tree_string)
  # puts ast_tree_string
  puts json_ast_string["type"]
  puts json_ast_string["typeLabel"]
  puts json_ast_string["pos"]
  puts json_ast_string["length"]
  puts json_ast_string["children"][0]["type"]
  puts json_ast_string["children"].length


  currAstTreeNode = AstTreeNode.new
  currAstTreeNode.astType = json_ast_string["type"]
  currAstTreeNode.astTypeLabel = json_ast_string["typeLabel"]
  currAstTreeNode.astPos = json_ast_string["pos"]
  currAstTreeNode.astLabel = json_ast_string["label"]
  currAstTreeNode.astLength = json_ast_string["length"]
  currAstTreeNode.AST_trees_id = ast_tree.id
  currAstTreeNode.save

  saveChildrenToDB(json_ast_string["children"],currAstTreeNode,ast_tree)




end


def saveChildrenToDB(childrenArray,parent,astTree)
  puts "========== CHILD =========="
  puts childrenArray.inspect
  puts childrenArray
  childrenArray.each do |child|
    puts "========== CHILD =========="
    currAstTreeNode = AstTreeNode.new
    currAstTreeNode.astType = child["type"]
    currAstTreeNode.astTypeLabel = child["typeLabel"]
    currAstTreeNode.astLabel = child["label"]
    currAstTreeNode.astPos = child["pos"]
    currAstTreeNode.astLength = child["length"]
    currAstTreeNode.AST_trees_id = astTree.id
    currAstTreeNode.save

    astTreeRel = AstTreeRelationships.new
    astTreeRel.parent_id = parent.id
    astTreeRel.child_id = currAstTreeNode.id
    astTreeRel.save
    puts child.inspect

    saveChildrenToDB(child["children"],currAstTreeNode,astTree)


  end

end




def record_AST_and_diff

  AstTree.delete_all
  AstTreeNode.delete_all
  AstTreeRelationships.delete_all

  Session.find_by_sql("SELECT s.id,s.kata_name,s.cyberdojo_id,s.avatar FROM Sessions as s
  INNER JOIN interrater_sessions as i on i.session_id = s.id WHERE s.id = 2456").each do |session|

    # @currSession = session
    puts session.inspect
    session.compiles.limit(1).each_with_index do |compile, index|
      puts "compile.git_tag: "+ compile.git_tag.to_s
      puts "index: "+ index.to_s

      path = "#{BUILD_DIR}/" + compile.git_tag.to_s + "/src"

      curr_files = build_files(dojo.katas[session.cyberdojo_id].avatars[session.avatar].lights[compile.git_tag-1])
      curr_files = curr_files.select{ |filename| filename.include? ".java" }
      curr_filenames = curr_files.map{ |file| File.basename(file) }

      curr_filenames.each do |filename|
        # prev_path = "#{BUILD_DIR}/" + prev.git_tag.to_s + "/src"
        curr_path = "#{BUILD_DIR}/" + compile.git_tag.to_s + "/src"
        puts "File To Match" + filename

        store_AST_Tree(session.id,curr_path,filename,compile.git_tag)
      end
    end
  end

  # Session.find_by_sql("SELECT * FROM Sessions as s
  #  WHERE s.id = 2456").each do |session|
  #   session.ast_trees.each do |curr_astTree|
  #     puts curr_astTree.inspect
  #   end
  # end
end
