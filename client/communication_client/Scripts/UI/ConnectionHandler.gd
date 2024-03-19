extends Node2D
## pääohjelma, hallitsee TCP-yhteyttä palvelimelle


const CLEAR_CMDS = ['/clear']
## Sama kuin palvelin-puolella, kuinka monta tavua viestin aluksi kertoo viestin pituuden
var MSG_SIZE = 2

## Käyttäjän tiedot dict-elementissä tallessa
var host_info = {
	'ip_addr': '127.0.0.1',
	'port': 6666,
	'username': '',
	'usercolor': '#ffffff'
}

var con = StreamPeerTCP.new()
var con_status = con.STATUS_NONE
## Palvelimelta tulevien ilmoitusten väri
var notif_color = Color.YELLOW


@onready var message_text = $'Messaging/MessageText'
@onready var chatbox = $'Messaging/ChatBox'
@onready var userlist = $'Messaging/UserList'
@onready var connect_btn = $'Connection/ConnectButton'

func _ready():
	$'Connection/IPInput'.text = host_info['ip_addr']
	$'Connection/PortInput'.text = str(host_info['port'])
	$'Connection/PlayerColor'.color = Color.from_string(host_info['usercolor'], Color.WHITE)


func _process(delta):
	con.poll()
	var new_status = con.get_status()
	# tarkistetaan, onko yhteyden tila muuttunut, jos on, ilmoitetaan siitä
	if new_status != con_status:
		con_status = new_status
		match con_status:
			con.STATUS_NONE:
				print('Disconnected')
				connect_btn.toggle(_on_connect_pressed, 'Connect')
				userlist.clear()
				render_message('Disconnected from %s:%s' % [host_info['ip_addr'], host_info['port']], notif_color, true, true)
			con.STATUS_CONNECTING:
				print('Connecting')
				connect_btn.toggle(_on_disconnect_pressed, 'Disconnect')
				render_message('Connecting to %s:%s' % [host_info['ip_addr'], host_info['port']], notif_color, true, true)
			con.STATUS_CONNECTED:
				print('Connected')
				connect_btn.toggle(_on_disconnect_pressed, 'Disconnect')
				render_message('Connected to %s:%s' % [host_info['ip_addr'], host_info['port']], notif_color, true, true)
				send_user_data()
			con.STATUS_ERROR:
				print('Error')
				connect_btn.toggle(_on_connect_pressed, 'Connect')
				render_message('Error connecting to %s:%s' % [host_info['ip_addr'], host_info['port']], notif_color, true, true)
	
	# Kuunnellaan palvelimelta tulevia viestejä
	if con_status == con.STATUS_CONNECTED:
		# Kaikki pinossa olevat tavut
		var bytes = con.get_available_bytes()
		if bytes > 0:
			var data = con.get_partial_data(bytes)
			if data[0] != OK:
				print("Error getting data from the stream: ", data[0])
			else:
				data = data[1]
				# Pinossa voi olla useita viestejä, luetaan jokainen
				while data.size() > MSG_SIZE - 1:
					# Haetaan, kuinka monta tavua seuraava viesti on 
					var msg_len = 0
					for i in range(0, MSG_SIZE):
						msg_len = msg_len | data[i] << (8*(MSG_SIZE - 1 - i))
					# Leikataan yksi viesti datasta
					var msg = data.slice(MSG_SIZE, msg_len).get_string_from_utf8()
					parse_message(msg)
					data = data.slice(msg_len, bytes)

## Erottelee palvelimelta tulleesta viestistä sen tyypin ja sisällön
func parse_message(message: String):
	var msg_parts = message.split(';', true, 1)
	var msg_type = msg_parts[0]
	var msg_body = msg_parts[1]
	match msg_type:
		# Viesti on lista käyttäjistä
		'u':
			render_users(msg_body.split(' '))
		# Viesti on tavallinen käyttäjältä tullut viesti
		'm':
			msg_parts = msg_body.split(';', true, 1)
			# Viestin mukana tulee myös lähettäneen käyttäjän väri, täytyy erottaa viestin sisällöstä 
			var color = Color.from_string(msg_parts[0], Color.WHITE) 
			msg_body = msg_parts[1]
			render_message(msg_body, color)
		# Viesti on yksityisviesti käyttäjältä
		'w':
			msg_parts = msg_body.split(';', true, 1)
			var color = Color.from_string(msg_parts[0], Color.WHITE) 
			msg_body = msg_parts[1]
			render_message(msg_body, color, true)
		# Viesti on ilmoitus palvelimelta
		's': 
			render_message(msg_body, notif_color, true, true)

## Kirjoittaa viestin käyttöliittymän tekstikenttään omalle rivilleen
func render_message(msg: String, color: Color, is_italics=false, is_indented=false):
	chatbox.push_color(color)
	if is_italics:
		chatbox.push_italics()
	if is_indented:
		msg = '		' + msg
	chatbox.append_text(msg)
	chatbox.newline()
	chatbox.pop_all()
	
## Kirjoittaa käyttäjien nimet käyttöliittymän käyttäjät listaavaan tekstikenttään
func render_users(users: PackedStringArray):
	userlist.clear()
	for user in users:
		var parts = user.split(';', true, 1)
		var color = Color.from_string(parts[0], Color.WHITE)
		user = parts[1]
		userlist.push_color(color)
		userlist.append_text(user)
		userlist.newline()
		userlist.pop_all()

## Apufunktio yhteyden tietojen päivittämiseen, käyttöliittymän input-kentät liitetty tähän
func update_info(key, value):
	#print('%s : %s' % [key, value])
	host_info[key] = value

## Kun painetaan Connect-painiketta, yritetään yhdistää tietojen mukaiseen palvelimeen
func _on_connect_pressed():
	if !host_info['username']:
		render_message('Username cannot be empty', notif_color, true)
	if !host_info['ip_addr']:
		render_message('Server address cannot be empty', notif_color, true)
	
	if host_info['username'] and host_info['ip_addr']:
		connect_to_host(host_info['ip_addr'], host_info['port'])

## Kun painetaan Disconnect-painiketta, katkaistaan yhteys
func _on_disconnect_pressed():
	con.disconnect_from_host()
	
## Kun tekstisyötteestä lähetetään viesti
func _send_message():
	# Jos annetaan komento puhdistaa chatti-kenttä
	if message_text.text.strip_edges() in CLEAR_CMDS:
		chatbox.clear()
	else:
		send(message_text.text.to_utf8_buffer())
	message_text.text = ''

## Yhdistää palvelimeen
func connect_to_host(address, port):
	con_status = con.STATUS_NONE
	var err = con.connect_to_host(address, port)
	if err != OK:
		print('Error connecting to host')

## Lähettää käyttäjän tiedot palvelimelle, tapahtuu automaattisesti yhdistämisen jälkeen
func send_user_data():
	var user = host_info['username'].to_utf8_buffer()
	var delim = ';'.to_utf8_buffer()
	var color = host_info['usercolor'].to_utf8_buffer() 
	send(user + delim + color)

## Lähettää minkä tahansa viestin palvelimelle
func send(data: PackedByteArray):
	if con_status != con.STATUS_CONNECTED:
		render_message('Client is not connected', notif_color,true, true)
		print('Client is not connected')
		return
		
	var err = con.put_data(data)
	if err != OK:
		print('Error writing to stream: ', err)
		return
