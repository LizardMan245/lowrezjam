extends Control

var base_datatext: String = "picked up data:"
var ramtext: String = "RAM: "

func ui_update(held_data, ram_size) -> void:
	var datatext = base_datatext
	for data in held_data:
		datatext += "\n" + data
	$Data.text = datatext
	$Ram.text = ramtext + str(ram_size)
