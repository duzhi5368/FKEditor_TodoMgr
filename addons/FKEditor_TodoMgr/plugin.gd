# Created by Freeknight
# Date: 2021/12/13
# Desc：脚本文件中自动摘取识别 #TODO, #HACK, #FIXME 等标识功能，并记录在编辑器，方便开发工作。
# @category: 主入口
#--------------------------------------------------------------------------------------------------
tool
extends EditorPlugin
### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------
#--- enums ----------------------------------------------------------------------------------------
#--- constants ------------------------------------------------------------------------------------
const DockScene := preload("res://addons/FKEditor_TodoMgr/UI/UI_Dock.tscn")
const Dock := preload("res://addons/FKEditor_TodoMgr/Scripts/UI/UI_Dock.gd")
const Todo := preload("res://addons/FKEditor_TodoMgr/Scripts/TodoClass.gd")
const TodoItem := preload("res://addons/FKEditor_TodoMgr/Scripts/TodoItemClass.gd")
#--- public variables - order: export > normal var > onready --------------------------------------
var script_cache : Array			# 已记录的文件列表缓存
var combined_pattern : String		# 需要查找的匹配表达式
var refresh_lock := false 		# 扫描锁，防止更新扫描期间进行重扫描
#--- private variables - order: export > normal var > onready -------------------------------------
var _dockUI : Dock				# 核心ui对象
### -----------------------------------------------------------------------------------------------

#TODO 这是测试
#HACK 这是一个HACK
#FIXME 这里需要FIX

### Built in Engine Methods -----------------------------------------------------------------------
func _enter_tree() -> void:
	# 创建面板
	_dockUI = DockScene.instance() as Control
	if !_dockUI:
		print("创建todo面板失败...")
		return
	add_control_to_bottom_panel(_dockUI, "TODO")
	
	# 注册消息
	#connect("resource_saved", self, "check_saved_file")
	get_editor_interface().get_resource_filesystem().connect("filesystem_changed", self, "_on_filesystem_changed")
	get_editor_interface().get_file_system_dock().connect("file_removed", self, "queue_remove")
	#FIXME 这个信号失效，应该是引擎bug
	get_editor_interface().get_script_editor().connect("editor_script_changed", self, "_on_active_script_changed")
	
	# 在子面板中提供本身对象
	_dockUI.plugin = self
	
	# 初始进行一次全文件内容匹配扫描
	combined_pattern = combine_patterns(_dockUI.patterns)
	find_tokens_from_path(find_scripts())
	_dockUI.build_tree()
	
	print("todo插件初始化完毕。")
# ------------------------------------------------------------------------------
func _exit_tree() -> void:
	# 退出时保存配置文件
	_dockUI.create_config_file()
	# 移除ui组并释放内存
	remove_control_from_bottom_panel(_dockUI)
	_dockUI.free()
### -----------------------------------------------------------------------------------------------

### Public Methods --------------------------------------------------------------------------------

func queue_remove(file: String):
	for i in _dockUI.todo_items.size() - 1:
		if _dockUI.todo_items[i].script_path == file:
			_dockUI.todo_items.remove(i)
# ------------------------------------------------------------------------------
func find_tokens_from_path(scripts: Array) -> void:
	# 逐文件内容查找符合样式的对象
	for script_path in scripts:
		var file := File.new()
		file.open(script_path, File.READ)
		var contents := file.get_as_text()
		file.close()
		find_tokens(contents, script_path)
# ------------------------------------------------------------------------------
# 单文件中进行匹配查找
func find_tokens(text: String, script_path: String) -> void:
	var regex = RegEx.new()
	if regex.compile(combined_pattern) != OK:
		return
		
	# combined_pattern = "#\\s*\\bTODO\\b.*|#\\s*\\bHACK\\b.*"
	var result : Array = regex.search_all(text)
	if result.empty():
		for i in _dockUI.todo_items.size():
			if _dockUI.todo_items[i].script_path == script_path:
				_dockUI.todo_items.remove(i)
		return # 这个文件中不存在符合要求的匹配项
		
	var match_found := false
	var i := 0
	for todo_item in _dockUI.todo_items:
		if todo_item.script_path == script_path: # 找到该文件现在已有todo项，只需要更新即可
			match_found = true
			var updated_todo_item := update_todo_item(todo_item, result, text, script_path)
			_dockUI.todo_items.remove(i)
			_dockUI.todo_items.insert(i, updated_todo_item)
			break
		i += 1
		
	if !match_found: # 该文件先前没有todo项，只能新建
		_dockUI.todo_items.append(create_todo_item(result, text, script_path))
# ------------------------------------------------------------------------------
func create_todo_item(regex_results: Array, text: String, script_path: String) -> TodoItem:
	var todo_item = TodoItem.new()
	todo_item.script_path = script_path
	var last_line_number := 0
	var lines := text.split("\n")
	for r in regex_results:
		var new_todo : Todo = create_todo(r.get_string(), script_path)
		new_todo.line_number = get_line_number(r.get_string(), text, last_line_number)
		
		# 处理多行注释导致的行数不正确问题
		var trailing_line := new_todo.line_number
		var should_break := false
		while trailing_line < lines.size() and lines[trailing_line].dedent().begins_with("#"):
			for other_r in regex_results:
				if lines[trailing_line] in other_r.get_string():
					should_break = true
					break
			if should_break:
				break			
			new_todo.content += "\n" + lines[trailing_line]
			trailing_line += 1	
			
		last_line_number = new_todo.line_number
		todo_item.todos.append(new_todo)
	return todo_item
# ------------------------------------------------------------------------------
func update_todo_item(todo_item: TodoItem, regex_results: Array, text: String, script_path: String) -> TodoItem:
	todo_item.todos.clear()
	
	var lines := text.split("\n")
	for r in regex_results:
		var new_todo : Todo = create_todo(r.get_string(), script_path)
		new_todo.line_number = get_line_number(r.get_string(), text)
		# 处理多行注释导致的行数不正确问题
		var trailing_line := new_todo.line_number
		var should_break = false
		while trailing_line < lines.size() and lines[trailing_line].dedent().begins_with("#"):
			for other_r in regex_results:
				if lines[trailing_line] in other_r.get_string():
					should_break = true
					break
			if should_break:
				break			
			new_todo.content += "\n" + lines[trailing_line]
			trailing_line += 1
			
		todo_item.todos.append(new_todo)
	return todo_item
# ------------------------------------------------------------------------------
func get_line_number(what: String, from: String, start := 0) -> int:
	what = what.split('\n')[0] 	# 这里是为了处理多重注释问题
	var temp_array := from.split('\n')
	var lines := Array(temp_array)
	var line_number := 0
	for i in range(start, lines.size()):
		if what in lines[i]:
			line_number = i + 1 	# +1是因为行号是从1开始
			break
		else:
			line_number = 0 		# 出错了
	return line_number
# ------------------------------------------------------------------------------
#func check_saved_file(script: Resource) -> void:
#	print(script)
#	pass
# ------------------------------------------------------------------------------
func _on_filesystem_changed() -> void:
	if refresh_lock:
		return
		
	if !_dockUI:
		return
	
	if !_dockUI.auto_refresh:
		return
		
	refresh_lock = true # 上扫描锁
	_dockUI.get_node("Timer").start() # 定时器开启，一秒后解锁 
	rescan_files()
# ------------------------------------------------------------------------------
# 检索整个 res:// 目录下的全部脚本文件
func find_scripts() -> Array:
	var scripts : Array
	var directory_queue : Array
	var dir : Directory = Directory.new()

	if dir.open("res://") == OK:
		get_dir_contents(dir, scripts, directory_queue)
	else:
		printerr("todo管理器：尝试打开 res:// 目录失败。")

	while not directory_queue.empty():
		if dir.change_dir(directory_queue[0]) == OK:
			get_dir_contents(dir, scripts, directory_queue)
		else:
			printerr("todo管理器：打开目录失败 " + directory_queue[0])
		directory_queue.pop_front()
	
	# 添加脚本文件到文件列表缓冲中
	cache_scripts(scripts)
	return scripts
# ------------------------------------------------------------------------------
func cache_scripts(scripts: Array) -> void:
	for script in scripts:
		if not script_cache.has(script):
			script_cache.append(script)
# ------------------------------------------------------------------------------
func get_dir_contents(dir: Directory, scripts: Array, directory_queue: Array) -> void:
	dir.list_dir_begin(true, true)
	var file_name : String = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir():
			if file_name == ".import" or filename == ".mono": # 免检指定目录
				pass
			else:
				if dir.get_current_dir() == "res://":
					directory_queue.append(dir.get_current_dir() + file_name)
				else:
					directory_queue.append(dir.get_current_dir() + "/" + file_name)
		else:
			if file_name.ends_with(".gd") or file_name.ends_with(".cs") \
			or file_name.ends_with(".c") or file_name.ends_with(".cpp") or file_name.ends_with(".h") \
			or ((file_name.ends_with(".tscn") and _dockUI.builtin_enabled)):
				if dir.get_current_dir() == "res://":
					scripts.append(dir.get_current_dir() + file_name)
				else:
					scripts.append(dir.get_current_dir() + "/" + file_name)
					
		file_name = dir.get_next()
# ------------------------------------------------------------------------------
func rescan_files() -> void:
	# 清除数据
	_dockUI.todo_items.clear()
	script_cache.clear()
	# 重新确定搜索样式表
	combined_pattern = combine_patterns(_dockUI.patterns)
	find_tokens_from_path(find_scripts())
	_dockUI.build_tree()
# ------------------------------------------------------------------------------
func combine_patterns(patterns: Array) -> String:
	if patterns.size() == 1:
		return patterns[0][0]
	else:
		var pattern_string := "((\\/\\*)|(#|\\/\\/))\\s*("
		for i in range(patterns.size()):
			if i == 0:
				pattern_string += patterns[i][0]
			else:
				pattern_string += "|" + patterns[i][0]
		pattern_string += ")(?(2)[\\s\\S]*?\\*\\/|.*)"
		return pattern_string
# ------------------------------------------------------------------------------
func create_todo(todo_string: String, script_path: String) -> Todo:
	var todo := Todo.new()
	var regex = RegEx.new()
	for pattern in _dockUI.patterns:
		if regex.compile(pattern[0]) == OK:
			var result : RegExMatch = regex.search(todo_string)
			if result:
				todo.pattern = pattern[0]
				todo.title = result.strings[0]
			else:
				continue
		else:
			printerr("编译正则表达式失败： " + pattern[0])
	
	todo.content = todo_string
	todo.script_path = script_path
	return todo
### -----------------------------------------------------------------------------------------------

### Private Methods -------------------------------------------------------------------------------
func _on_active_script_changed(script) -> void:
	if _dockUI:
		if _dockUI.tabs.current_tab == 1:
			_dockUI.build_tree()
### -----------------------------------------------------------------------------------------------




