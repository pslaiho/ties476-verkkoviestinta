extends Button
## Apuluokka vaihtamaan Connect-painike Disconnect-painikkeeksi, jos ollaan yhdistetty
## palvelimeen ja päinvastoin


func toggle(callback, label):
	text = label
	var old_signals = pressed.get_connections()
	for old in old_signals:
		pressed.disconnect(old['callable'])
	pressed.connect(callback)
