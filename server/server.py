import socket
import threading
import argparse

# Palvelimen konsolissa käytettävät komennot
SERVER_CMDS = {
    'quit': ['q', 'quit', 'e', 'exit'],
    'servermessage': ['b', 'broadcast', 'servermessage','notify'],
    'usermessage': ['m', 'message', 'usermessage', 'w', 'whisper']
}
# Käyttäjien chattiin kirjoittamat komennot
CHAT_CMDS = {
    'whisper': ['/w', '/whisper', '/msg', '/message'],
    'help': ['/h', '/help'],
    'change_color': ['/c', '/color'],
    'change_name': ['/n', '/name', '/nick', '/rename']
}
# Viesti, joka lähetetään /help-komennon kirjoittaneelle käyttäjälle
# Tähän on vähän laiskasti kovakoodattu godotin puolella käytettävä bbcode lihavoinnille
HELP_MSG = """
type [b]/h[/b] or [b]/help[/b] for help,
type [b]/w <username>[/b], [b]/whisper <username>[/b], [b]/msg <username>[/b] or [b]/message <username>[/b] to privately talk to another user,
type [b]/c <hexcode>[/b] or [b]/color <hexcode>[/b] to change your future message color,
type [b]/n <username>[/b], [b]/name <username>[/b], [b]/nick <username>[/b] or [b]/rename <username>[/b] to change your future username,
type [b]/clear[/b] to clear chat log
"""

# bitit, jotka käytetään viestin pituuden lähettämiseen. Tulee siis olla niin suuri, että siihen mahtuu MSG_BYTES-arvo, tässä tapauksessa 65536 > 4096
CNTRL_BYTES = 2
# viestin maksimibitit
MSG_BYTES = 4096
# Viestin eri osien jakaja 
DELIM = ';'
# onko sovellus päällä

DEFAULT_ADDR = '127.0.0.1'
DEFAULT_PORT = 6666


running = False
# kerätään talteen tiedot kaikista yhdistäneistä käyttäjistä
users = {}


def listen_connection(con, addr):
    """Yhden käyttäjän viestinnän kuuntelija
    Luodaan main-funktiossa omaan säikeeseen, toimivat samanaikaisesti

    param con: socket-yhteys
    param addr: käyttäjän ip-osoite ja portti
    """

    # ensimmäinen viesti yhdistämisen jälkeen tuo automaattisesti käyttäjän tiedto
    username, usercolor = con.recv(MSG_BYTES).decode('utf-8').split(DELIM)
    username = username.replace(' ', '')

    # Varmistetaan, ettei yhdistetä samannimisiä käyttäjiä
    if username in users:
        print(f'Username {username} already in chatroom')
        send_message(con, 's', f'SERVER: Username {username} already in chatroom')
        con.close()
        return
    
    users[username] = {
        'color': usercolor,
        'connection': con
    }
    # Lista kaikkien kirjautuneiden nimistä, joka lähetetään kaikille käyttäjille
    allusers = all_user_names()
    print(f'{addr} has connected as {username}')
    for c in users.values():
        send_message(c['connection'], 's', f'SERVER: {username} has joined the chatroom')
        send_message(c['connection'], 'u', allusers)

    # Kuunnellaan käyttäjältä viestejä loputtomasti, kunnes muualla suljetaan yhteys
    while True:
        try:
            data = con.recv(MSG_BYTES)
        except ConnectionResetError:
            print(f'{username} connection was forcibly shut down on client-side')
            break
        # Jos yhteys katkeaa likaisesti, käyttäjältä lähtee tyhjä viesti?
        if not data:
            print(f'{username} from {addr} disconnected')
            break

        message_body = data.decode('utf-8')
        # viestin alkuun kirjataan myös käyttäjän väri, joka luetaan käyttäjän päässä 
        message =f'{usercolor}{DELIM}{username}: {message_body}'
        parts = message_body.split(maxsplit=2)
        print(f'<{usercolor}> {username}: {message_body} ')

        # Tarkistetaan, käyttikö käyttäjä jotain chattikomentoa, viestin ensimmäisenä sanana
        if len(parts) >= 2:
            # käyttäjien välinen yksityisviesti
            if parts[0] in CHAT_CMDS['whisper']:
                if len(parts) == 2:
                    print(f'{username} tried to whisper an empty message')
                    send_message(con, 's', f'SERVER: Cannot whisper an empty message')
                    continue
                if parts[1] == username:
                    print(f'{username} tried to whisper themself')
                    send_message(con, 's', f'SERVER: Cannot whisper yourself')
                    continue
                if parts[1] not in users.keys():  
                    print(f'{username} tried to whisper unknown person {parts[1]}')
                    send_message(con, 's', f'SERVER: {parts[1]} is not in the chatroom') 
                    continue
                print(f'{username} whispered {parts[1]}: {parts[2]}') 
                send_message(users[parts[1]]['connection'], 'w', f'{usercolor}{DELIM}{username} whispered you: {parts[2]}')
                send_message(con, 'w', f'{usercolor}{DELIM}you whispered {parts[1]}: {parts[2]}')
                continue

            # käyttäjän värin vaihtaminen 
            # huom: ei tarkasteta, onko annettu väri validi hex-koodi, virheen tapahtuessa käyttäjäpäässä valkoinen
            if parts[0] in CHAT_CMDS['change_color']:
                users[username]['color'] = parts[1]
                usercolor = parts[1]
                allusers = all_user_names()
                print(f'{username} changed their color to {parts[1]}')
                # päivitetään myös käyttäjälista vastaamaan uutta väriä
                for c in users.values():
                    send_message(c['connection'], 'u', allusers)
                continue

            # käyttäjän nimen vaihtaminen
            if parts[0] in CHAT_CMDS['change_name']:
                if parts[1] in users:
                    print(f'Username {parts[1]} already in chatroom')
                    send_message(con, 's', f'SERVER: {parts[1]} already in chatroom')
                    continue
                if DELIM in parts[1]:
                    print(f'Username {parts[1]} contains restricted symbols')
                    send_message(con, 's', f'SERVER: {parts[1]} contains restricted symbol {DELIM}')
                    continue
                # Koska nimeä käytetään avaimena, täytyy luoda kokonaan uusi tietue
                users[parts[1]] = {
                    'color': users[username]['color'],
                    'connection': con
                }
                users.pop(username)
                print(f'{username} changed their name to {parts[1]}')
                
                allusers = all_user_names()
                # Ilmoitetaan kaikille käyttäjille nimenvaihdoksesta
                for c in users.values():
                    send_message(c['connection'], 's', f'SERVER: {username} changed their name to {parts[1]}')
                    send_message(c['connection'], 'u', allusers)
                username = parts[1]
                continue

        # käyttäjän avunpyyntö
        if parts[0] in CHAT_CMDS['help']:
            print(f'{username} asked for help')
            send_message(con, 's', HELP_MSG)
            continue
        
        # Tänne päästään, jos viesti on normaali, kaikille käyttäjille
        for c in users.values():
            send_message(c['connection'], 'm', message)
    
    # Poistuttu kuuntelu-loopista, katkaistaan yhteys ja poistetaan käyttäjä palvelimelta
    users.pop(username)
    allusers = all_user_names()
    con.close()
    for c in users.values():
        send_message(c['connection'], 's', f'SERVER: {username} has left the chatroom')
        send_message(c['connection'], 'u', allusers)

def all_user_names():
    return ' '.join([v['color'] + DELIM + k for k, v in users.items()])

def send_message(con: socket.socket, type: str, message: str):
    """ Apufunktio viestin lähettämiselle palvelimelta käyttäjälle
    
    :param con: yhteyden socket
    :param type: viestin tyyppi: 
        m = tavallinen käyttäjän viesti,
        w = yksityisviesti käyttäjältä toiselle,
        s = palvelimelta tuleva ilmoitus, 
        u = lista kaikkien käyttäjien nimistä
    :param message: lähetettävä viestisisältö
    """
    # kaikki viestin osat merkkijonoista tavuiksi
    prefix = type.encode('utf-8')
    # erotellaan viestin eri osat DELIM-merkillä
    delim = DELIM.encode('utf-8')
    body = message.encode('utf-8')
    # lasketaan viestin lopullinen pituus, joka lisätään viestin alkuun
    count = len(prefix) + len(delim) + len(body) + CNTRL_BYTES
    if count > MSG_BYTES:
        print(f'Message was too long: {count} bytes')
        return
    #print(count.to_bytes(CNTRL_BYTES, byteorder='big') + prefix + delim + body)
    con.send(count.to_bytes(CNTRL_BYTES, byteorder='big') + prefix + delim + body)

def parse_arguments():
    """Luetaan ohjelmaa käynnistettäessä palvelimen tiedot komentoriviltä
    """
    argparser = argparse.ArgumentParser(prog='Chat-server',
                                        description='Server side of Godot communication app')
    argparser.add_argument('-ip', default=DEFAULT_ADDR)
    argparser.add_argument('-port', type=int, default=DEFAULT_PORT)
    return argparser.parse_args()

def parse_commands(soc: socket.socket):
    """Kuuntelee palvelimen päässä komentoja
    """
    while True:
        #try:
        cmd = input()
        if cmd in SERVER_CMDS['quit']:
            print(f'shutting down server')
            running = False
            #soc.shutdown(socket.SHUT_RDWR)
            soc.close()
            break
        try: 
            command, body = cmd.split(maxsplit=1)
            # palvelimen sulkeminen
            # Palvelimen viesti kaikille käyttäjille
            if command in SERVER_CMDS['servermessage']:
                print(f'Server message: {body}')
                for c in users.values():
                    send_message(c['connection'], 's', f'SERVER: {body}')
                continue
            # Palvelimen viesti yhdelle käyttäjälle
            if command in SERVER_CMDS['usermessage']:
                user, msg = body.split(maxsplit=1)
                if user not in users.keys(): 
                    print(f'no user named {user} on the server')
                    continue

                print(f'Server message to {user}: {msg}')
                send_message(users[user]['connection'], 's', f'SERVER: {msg}')

        except:
            print(f'error parsing command {cmd}')



def main():
    args = parse_arguments()

    print(f'Starting server at: {args.ip}:{args.port}')

    soc = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    soc.bind((args.ip, args.port))
    soc.listen(5)
    running = True

    # Palvelinpään komentokehotteen kuuntelu omaan säikeeseen
    parse = threading.Thread(target=parse_commands, args=(soc, ))
    parse.start()

    # Kuunnellaan yhdistäviä käyttäjiä, jokainen käyttäjä omaksi säikeekseen
    while running:
        try: 
            con, addr = soc.accept()
            read = threading.Thread(target=listen_connection, args=(con, addr), daemon=True)
            read.start()
        except:
            print('Server shut down manually')
            break

if __name__ == '__main__':
    main()