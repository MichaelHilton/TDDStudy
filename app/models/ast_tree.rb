class AstTree < ActiveRecord::Base
  #   # tell ActiveRecord that a person has_many friendships or :through won't work
  has_many :ast_tree_nodes
  belongs_to :session
end
