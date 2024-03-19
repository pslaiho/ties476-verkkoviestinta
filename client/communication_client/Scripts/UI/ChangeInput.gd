extends LineEdit
## Apuluokka tekstikenttien sisällön muokkaukseen
## Lähettää muoktaun tekstin oikealla avaimella yhteydenhallinta-luokkalle 
## Estää haluttujen kiellettyjen merkkien lisäämisen tekstikenttään

## ConnectionHandler-luokan host_info-dictiä vastaava avain, johon tekstikentän sisältö liittyy
@export var key: String

## Merkit, joita ei voi laittaa tekstikenttään
@export var restrict_regex = ' '
var regex = RegEx.new()

## Muokkauksen jälkeen lähetettävä signaali, johon lisätty oikea tietueen avain 
signal changed(key: String, value: String)

func _ready():
	regex.compile(restrict_regex)
	
## Kun tekstiä muokataan, kielletyt merkit pois ja lähetetään signaali
func _on_text_changed(new: String):
	var filtered = regex.sub(new, '', true)
	text = filtered
	caret_column = filtered.length()
	changed.emit(key, filtered)
