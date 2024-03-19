# Python/Godot-viestintäsovelluksen käyttöohje

## Server

Ajettava palvelin ja lähdekoodi on tiedostossa server/server.py. 

Palvelimen ajaminen vaatii asennetun Python-ympäristön, testattu 
versiolla 3.11.2, mahdollisesti muut versiot voivat toimia myös. 

Palvelin käynnistyy oletusarvoisesti osoitteeseen 127.0.0.1:6666.
Komentoriviltä käynnistettäessä voidaan antaa vaihtoehtoisina 
parametreina ip-osoite -ip ja sekä portti -port, esim. 
	$ server.py -ip 192.168.0.10 -port 4444
käynnistäisi palvelimen osoitteeseen 192.168.0.10:4444

Palvelimen konsoliin tulee automaattisesti ilmoitukset keskustelun 
tapahtumista. Lisäksi palvelimella on käytössä seuraavat komennot:

	q | quit | e | exit => sulkee palvelimen
	b | broadcast | servermessage | notify <viesti> => lähettää 
		kaikille käyttäjile viestin
	m | message | usermessage | w | whisper <käyttäjänimi> <viesti> => 
		lähettää tietyllä käyttäjälle yksityisviestin
		
## Client

Client-puolen käyttöliittymä on toteutettu godot-versiolla 4.2.1.
Lähdekoodi on kansiossa client/communication_client, Windowsissa 
ajettava .exe client/build/build1.exe.

Käyttöliittymän oikeassa laidassa on kentät ip-osoitteen ja portin
syöttämiseen, alla Connect-painike. Oletusarvoiset kentän syötteet 
ovat valmiiksi osoitteeseen 127.0.0.1:6666. 

Yhdistämisen jälkeen vasemmalla on viesteille tekstikenttä sekä lista
käyttäjistä. Näiden alapuolella on tekstisyöte sekä Send-painike. 
Tekstisyöte-kenttään kirjoitettu teksti lähetetään painiketta 
painamalla palvelimelle.

Client-puolella käytössä on seuraavat erikoiskomennot: 

	/h | /help => tulostaa tekstikenttään ohjeet
	/w | /whisper | /msg | /message <käyttäjänimi> <viesti> => 
		lähettää yksityisviestin toiselle käyttäjälle
	/c | /color <#hexavärikoodi> => vaihtaa käyttäjän tekstin värin
	/n | /name | /nick | /rename => vaihtaa käyttäjän nimen
	/clear => nollaa viestin tekstikentän sisällön
	
	