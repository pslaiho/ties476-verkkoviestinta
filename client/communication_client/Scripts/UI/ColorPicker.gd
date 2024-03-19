extends ColorPickerButton
## Apuluokka lähettämään valittu väri hex-arvona ConnectionHandler-luokalle

signal changed(key: String, value: String)

## Kun väriä muokataan, muutetaasn se hex-arvoksi ja lähetetään signaalina
func _color_changed(color):
	changed.emit('usercolor', '#' + color.to_html(false))
