# Created by Freeknight
# Date: 2021/12/13
# Desc：
# @category: Category Unknown
#--------------------------------------------------------------------------------------------------
tool
extends Panel
### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------
signal tree_built				# 通知ui层的消息信号
#--- enums ----------------------------------------------------------------------------------------
#--- constants ------------------------------------------------------------------------------------
const Todo := preload("res://addons/FKEditor_TodoMgr/Scripts/TodoClass.gd")
#--- public variables - order: export > normal var > onready --------------------------------------
var sort_alphabetical := true 	# 文件排序方式
onready var tree := $Tree as Tree	# UI中的树状列表对象
#--- private variables - order: export > normal var > onready -------------------------------------
### -----------------------------------------------------------------------------------------------

### Built in Engine Methods -----------------------------------------------------------------------
### -----------------------------------------------------------------------------------------------

### Public Methods --------------------------------------------------------------------------------
func build_tree(todo_items : Array, ignore_paths : Array, patterns : Array, sort_alphabetical : bool, full_path : bool) -> void:
	if !tree:
		printerr("todo插件找不到UI树状列表对象！")
		return
	tree.clear()
	
	if sort_alphabetical:
		todo_items.sort_custom(self, "sort_alphabetical")
	else:
		todo_items.sort_custom(self, "sort_backwards")
	
	var root := tree.create_item()
	root.set_text(0, "Scripts")
	for todo_item in todo_items:
		
		# 跳过可忽略路径内的对象
		var ignore := false
		for ignore_path in ignore_paths:
			var script_path : String = todo_item.script_path
			if script_path.begins_with(ignore_path) or script_path.begins_with("res://" + ignore_path) or script_path.begins_with("res:///" + ignore_path):
				ignore = true
				break
		if ignore: 
			continue
			
		var script := tree.create_item(root)
		if full_path:
			script.set_text(0, todo_item.script_path)
		else:
			script.set_text(0, todo_item.get_short_path())
		script.set_metadata(0, todo_item)
		
		for todo in todo_item.todos:
			var item := tree.create_item(script)
			var content_header : String = todo.content
			if "\n" in todo.content: # 可能内容超长
				content_header = content_header.split("\n")[0] + "..."
			item.set_text(0, "(%0) - %1".format([todo.line_number, content_header], "%_"))
			item.set_tooltip(0, todo.content) # 加上，以处理超长字符串显示不全的问题
			item.set_metadata(0, todo)
			for pattern in patterns:
				if pattern[0] == todo.pattern:
					item.set_custom_color(0, pattern[1])
	
	# 内存数据填充完毕，通知ui进行更新
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
