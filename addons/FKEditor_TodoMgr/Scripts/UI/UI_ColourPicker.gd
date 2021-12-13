# Created by Freeknight
# Date: 2021/12/13
# Desc：
# @category: Category Unknown
#--------------------------------------------------------------------------------------------------
tool
extends HBoxContainer
### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------
#--- enums ----------------------------------------------------------------------------------------
#--- constants ------------------------------------------------------------------------------------
#--- public variables - order: export > normal var > onready --------------------------------------
var colour : Color
var title : String setget set_title
var index : int

onready var colour_picker := $TODOColourPickerButton
#--- private variables - order: export > normal var > onready -------------------------------------
### -----------------------------------------------------------------------------------------------

### Built in Engine Methods -----------------------------------------------------------------------
func _ready() -> void:
	$TODOColourPickerButton.color = colour
	$Label.text = title
### -----------------------------------------------------------------------------------------------

### Public Methods --------------------------------------------------------------------------------
func set_title(value: String) -> void:
	title = value
	$Label.text = value 
### -----------------------------------------------------------------------------------------------

### Private Methods -------------------------------------------------------------------------------
### -----------------------------------------------------------------------------------------------