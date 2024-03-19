extends LineEdit
## Apuluokka, jotta normaaliin tekstikenttään saadaan rajoitettua kokonaisluku halutulla välillä


var old_text = ''
var max = 65535
signal port_changed(key: String, value: int)


func _on_text_changed(new):
	var num = int(new)
	var txt = old_text
	if num >= 1 and num <= max:
		txt = str(num)
		port_changed.emit('port', num)
	elif new.length() == 0:
		txt = new
	text = txt
	caret_column = txt.length()
	old_text = txt
