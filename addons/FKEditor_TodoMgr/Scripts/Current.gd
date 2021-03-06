# Created by Freeknight
# Date: 2021/12/13
# Desc：
# @category: Category Unknown
#--------------------------------------------------------------------------------------------------
tool
extends Panel
### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------
signal tree_built
#--- enums ----------------------------------------------------------------------------------------
#--- constants ------------------------------------------------------------------------------------
const Todo := preload("res://addons/FKEditor_TodoMgr/Scripts/TodoClass.gd")
const TodoItem := preload("res://addons/FKEditor_TodoMgr/Scripts/TodoItemClass.gd")
#--- public variables - order: export > normal var > onready --------------------------------------
var sort_alphabetical := true
onready var tree := $Tree as Tree
#--- private variables - order: export > normal var > onready -------------------------------------
### -----------------------------------------------------------------------------------------------

### Built in Engine Methods -----------------------------------------------------------------------
### -----------------------------------------------------------------------------------------------

### Public Methods --------------------------------------------------------------------------------
func build_tree(todo_item : TodoItem, patterns : Array) -> void:
	if !tree:
		printerr("todo插件找不到UI树状列表对象！")
		return
	tree.clear()
	
	var root := tree.create_item()
	root.set_text(0, "Scripts")
	var script := tree.create_item(root)
	script.set_text(0, todo_item.get_short_path())
	script.set_metadata(0, todo_item)
	for todo in todo_item.todos:
		var item := tree.create_item(script)
		var content_header : String = todo.content
		if "\n" in todo.content: # 数据可能超长
			content_header = content_header.split("\n")[0] + "..."
		item.set_text(0, "(%0) - %1".format([todo.line_number, content_header], "%_"))
		item.set_tooltip(0, todo.content)
		item.set_metadata(0, todo)
		for pattern in patterns:
			if pattern[0] == todo.pattern:
				item.set_custom_color(0, pattern[1])
	# 通知ui信号
	emit_signal("tree_built")
# ------------------------------------------------------------------------------
func sort_alphabetical(a, b) -> bool:
	if a.script_path > b.script_path:
		return true
	else:
		return false
# ------------------------------------------------------------------------------
func sort_backwards(a, b) -> bool:
	if a.script_path < b.script_path:
		return true
	else:
		return false
### -----------------------------------------------------------------------------------------------

### Private Methods -------------------------------------------------------------------------------
### -----------------------------------------------------------------------------------------------
