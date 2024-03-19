GDPC                P                                                                         T   res://.godot/exported/133200997/export-78c237d4bfdb4e1d02e0b5f38ddfd8bd-scene.scn    .      8      ��gad�z4���    ,   res://.godot/global_script_class_cache.cfg  �9             ��Р�8���8~$}P�    D   res://.godot/imported/icon.svg-218a8f2b3041327d8a5756f3a245f83b.ctexP       �      �̛�*$q�*�́        res://.godot/uid_cache.bin  �=      :       ~�n
#g����x��        res://ConnectButtonToggler.gd         :      �9j���ʋ��v�=�8G        res://Scripts/UI/ChangeInput.gd         a      G����f�餧��        res://Scripts/UI/ColorPicker.gd p      ;      �?�u���㔈:L    (   res://Scripts/UI/ConnectionHandler.gd   �      �      K)����;�5����       res://Scripts/UI/IntEdit.gd P      �      �����fq�Z����       res://icon.svg  �9      �      C��=U���^Qu��U3       res://icon.svg.import   0-      �       ��L2�㪝����"��J       res://project.binary�=      �      KY�"t�o��6 �
�       res://scene.tscn.remap  @9      b       ��w$yWJMX��                extends LineEdit
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
               extends ColorPickerButton
## Apuluokka lähettämään valittu väri hex-arvona ConnectionHandler-luokalle

signal changed(key: String, value: String)

## Kun väriä muokataan, muutetaasn se hex-arvoksi ja lähetetään signaalina
func _color_changed(color):
	changed.emit('usercolor', '#' + color.to_html(false))
     extends Node2D
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
         extends LineEdit
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
      extends Button
## Apuluokka vaihtamaan Connect-painike Disconnect-painikkeeksi, jos ollaan yhdistetty
## palvelimeen ja päinvastoin


func toggle(callback, label):
	text = label
	var old_signals = pressed.get_connections()
	for old in old_signals:
		pressed.disconnect(old['callable'])
	pressed.connect(callback)
      GST2   �   �      ����               � �        �  RIFF�  WEBPVP8L�  /������!"2�H�$�n윦���z�x����դ�<����q����F��Z��?&,
ScI_L �;����In#Y��0�p~��Z��m[��N����R,��#"� )���d��mG�������ڶ�$�ʹ���۶�=���mϬm۶mc�9��z��T��7�m+�}�����v��ح�m�m������$$P�����එ#���=�]��SnA�VhE��*JG�
&����^x��&�+���2ε�L2�@��		��S�2A�/E���d"?���Dh�+Z�@:�Gk�FbWd�\�C�Ӷg�g�k��Vo��<c{��4�;M�,5��ٜ2�Ζ�yO�S����qZ0��s���r?I��ѷE{�4�Ζ�i� xK�U��F�Z�y�SL�)���旵�V[�-�1Z�-�1���z�Q�>�tH�0��:[RGň6�=KVv�X�6�L;�N\���J���/0u���_��U��]���ǫ)�9��������!�&�?W�VfY�2���༏��2kSi����1!��z+�F�j=�R�O�{�
ۇ�P-�������\����y;�[ ���lm�F2K�ޱ|��S��d)é�r�BTZ)e�� ��֩A�2�����X�X'�e1߬���p��-�-f�E�ˊU	^�����T�ZT�m�*a|	׫�:V���G�r+�/�T��@U�N׼�h�+	*�*sN1e�,e���nbJL<����"g=O��AL�WO!��߈Q���,ɉ'���lzJ���Q����t��9�F���A��g�B-����G�f|��x��5�'+��O��y��������F��2�����R�q�):VtI���/ʎ�UfěĲr'�g�g����5�t�ۛ�F���S�j1p�)�JD̻�ZR���Pq�r/jt�/sO�C�u����i�y�K�(Q��7őA�2���R�ͥ+lgzJ~��,eA��.���k�eQ�,l'Ɨ�2�,eaS��S�ԟe)��x��ood�d)����h��ZZ��`z�պ��;�Cr�rpi&��՜�Pf��+���:w��b�DUeZ��ڡ��iA>IN>���܋�b�O<�A���)�R�4��8+��k�Jpey��.���7ryc�!��M�a���v_��/�����'��t5`=��~	`�����p\�u����*>:|ٻ@�G�����wƝ�����K5�NZal������LH�]I'�^���+@q(�q2q+�g�}�o�����S߈:�R�݉C������?�1�.��
�ڈL�Fb%ħA ����Q���2�͍J]_�� A��Fb�����ݏ�4o��'2��F�  ڹ���W�L |����YK5�-�E�n�K�|�ɭvD=��p!V3gS��`�p|r�l	F�4�1{�V'&����|pj� ߫'ş�pdT�7`&�
�1g�����@D�˅ �x?)~83+	p �3W�w��j"�� '�J��CM�+ �Ĝ��"���4� ����nΟ	�0C���q'�&5.��z@�S1l5Z��]�~L�L"�"�VS��8w.����H�B|���K(�}
r%Vk$f�����8�ڹ���R�dϝx/@�_�k'�8���E���r��D���K�z3�^���Vw��ZEl%~�Vc���R� �Xk[�3��B��Ğ�Y��A`_��fa��D{������ @ ��dg�������Mƚ�R�`���s����>x=�����	`��s���H���/ū�R�U�g�r���/����n�;�SSup`�S��6��u���⟦;Z�AN3�|�oh�9f�Pg�����^��g�t����x��)Oq�Q�My55jF����t9����,�z�Z�����2��#�)���"�u���}'�*�>�����ǯ[����82һ�n���0�<v�ݑa}.+n��'����W:4TY�����P�ר���Cȫۿ�Ϗ��?����Ӣ�K�|y�@suyo�<�����{��x}~�����~�AN]�q�9ޝ�GG�����[�L}~�`�f%4�R!1�no���������v!�G����Qw��m���"F!9�vٿü�|j�����*��{Ew[Á��������u.+�<���awͮ�ӓ�Q �:�Vd�5*��p�ioaE��,�LjP��	a�/�˰!{g:���3`=`]�2��y`�"��N�N�p���� ��3�Z��䏔��9"�ʞ l�zP�G�ߙj��V�>���n�/��׷�G��[���\��T��Ͷh���ag?1��O��6{s{����!�1�Y�����91Qry��=����y=�ٮh;�����[�tDV5�chȃ��v�G ��T/'XX���~Q�7��+[�e��Ti@j��)��9��J�hJV�#�jk�A�1�^6���=<ԧg�B�*o�߯.��/�>W[M���I�o?V���s��|yu�xt��]�].��Yyx�w���`��C���pH��tu�w�J��#Ef�Y݆v�f5�e��8��=�٢�e��W��M9J�u�}]釧7k���:�o�����Ç����ս�r3W���7k���e�������ϛk��Ϳ�_��lu�۹�g�w��~�ߗ�/��ݩ�-�->�I�͒���A�	���ߥζ,�}�3�UbY?�Ӓ�7q�Db����>~8�]
� ^n׹�[�o���Z-�ǫ�N;U���E4=eȢ�vk��Z�Y�j���k�j1�/eȢK��J�9|�,UX65]W����lQ-�"`�C�.~8ek�{Xy���d��<��Gf�ō�E�Ӗ�T� �g��Y�*��.͊e��"�]�d������h��ڠ����c�qV�ǷN��6�z���kD�6�L;�N\���Y�����
�O�ʨ1*]a�SN�=	fH�JN�9%'�S<C:��:`�s��~��jKEU�#i����$�K�TQD���G0H�=�� �d�-Q�H�4�5��L�r?����}��B+��,Q�yO�H�jD�4d�����0*�]�	~�ӎ�.�"����%
��d$"5zxA:�U��H���H%jس{���kW��)�	8J��v�}�rK�F�@�t)FXu����G'.X�8�KH;���[             [remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://clovddpgvmuab"
path="res://.godot/imported/icon.svg-218a8f2b3041327d8a5756f3a245f83b.ctex"
metadata={
"vram_texture": false
}
                RSRC                    PackedScene            ��������                                                  resource_local_to_scene    resource_name 	   _bundled    script       Script &   res://Scripts/UI/ConnectionHandler.gd ��������   Script     res://Scripts/UI/ChangeInput.gd ��������   Script    res://Scripts/UI/IntEdit.gd ��������   Script    res://ConnectButtonToggler.gd ��������   Script     res://Scripts/UI/ColorPicker.gd ��������      local://PackedScene_8c0f2 �         PackedScene          	         names "   )      Scene    script    Node2D    Connection    Node    IPInput    offset_left    offset_top    offset_right    offset_bottom    placeholder_text    key 	   LineEdit 
   PortInput 
   NameInput    restrict_regex    ConnectButton    text    Button    PlayerColor    color    ColorPickerButton 
   Messaging    MessageText 	   TextEdit    SendMessage    ChatBox    bbcode_enabled    RichTextLabel 	   UserList    update_info    changed    _on_text_changed    text_changed    port_changed    _on_connect_pressed    pressed    _color_changed    color_changed    focus_exited    _send_message    	   variants    $                  aD     HB    ��D     �B   
   Server IP                ip_addr      �B     C      Server port               C     6C   	   Username    	   username        |;      zD     �C     �C      Connect               NC     nC     �?  �?  �?  �?              �B    �D     D    �D      Type message...      D     .D      Send     �D            node_count             nodes     �   ��������       ����                            ����                     ����                     	      
                                   ����                     	   	   
   
                          ����                     	      
                                         ����                     	                                   ����                     	                                    ����                     ����                     	      
                       ����                      	         !                    ����                     	   "      #                    ����                      	   "      #             conn_count             conns     M                                 !                         "                       !                                                !                         $   #                                            &   %                    '   %              	       $   (                    node_paths              editable_instances              version             RSRC        [remap]

path="res://.godot/exported/133200997/export-78c237d4bfdb4e1d02e0b5f38ddfd8bd-scene.scn"
              list=Array[Dictionary]([])
     <svg height="128" width="128" xmlns="http://www.w3.org/2000/svg"><rect x="2" y="2" width="124" height="124" rx="14" fill="#363d52" stroke="#212532" stroke-width="4"/><g transform="scale(.101) translate(122 122)"><g fill="#fff"><path d="M105 673v33q407 354 814 0v-33z"/><path fill="#478cbf" d="m105 673 152 14q12 1 15 14l4 67 132 10 8-61q2-11 15-15h162q13 4 15 15l8 61 132-10 4-67q3-13 15-14l152-14V427q30-39 56-81-35-59-83-108-43 20-82 47-40-37-88-64 7-51 8-102-59-28-123-42-26 43-46 89-49-7-98 0-20-46-46-89-64 14-123 42 1 51 8 102-48 27-88 64-39-27-82-47-48 49-83 108 26 42 56 81zm0 33v39c0 276 813 276 813 0v-39l-134 12-5 69q-2 10-14 13l-162 11q-12 0-16-11l-10-65H447l-10 65q-4 11-16 11l-162-11q-12-3-14-13l-5-69z"/><path d="M483 600c3 34 55 34 58 0v-86c-3-34-55-34-58 0z"/><circle cx="725" cy="526" r="90"/><circle cx="299" cy="526" r="90"/></g><g fill="#414042"><circle cx="307" cy="532" r="60"/><circle cx="717" cy="532" r="60"/></g></g></svg>
             �Re�^M   res://icon.svgef�� S�#   res://scene.tscn      ECFG      application/config/name         communication_client   application/run/main_scene         res://scene.tscn   application/config/features(   "         4.2    GL Compatibility       application/config/icon         res://icon.svg     dotnet/project/assembly_name         communication_client#   rendering/renderer/rendering_method         gl_compatibility*   rendering/renderer/rendering_method.mobile         gl_compatibility    