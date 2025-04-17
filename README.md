openWB
Lizenz
Die Software steht unter der GPLv3 Lizenz. Eine kommerzielle Nutzung ist nur nach Rücksprache und schriftlicher Zustimmung der openWB GmbH & Co. KG erlaubt.
Unterstützung ist gerne gesehen! Sei es in Form von Code oder durch Spenden. Spenden bitte an spenden@openwb.de.
Anfragen für Supportverträge an info@openwb.de. Weitere Infos unter https://openwb.de.
Haftungsausschluss
Es wird mit Kleinspannung, aber auch mit 230V beim Anschluss der EVSE gearbeitet. Dies darf nur geschultes Personal durchführen. Die Anleitung ist ohne Gewähr, und jegliches Handeln erfolgt auf eigene Gefahr. Eine Fehlkonfiguration der Software kann höchstens ein nicht geladenes Auto bedeuten. Falsch zusammengebaute Hardware kann jedoch lebensgefährlich sein. Im Zweifel diesen Part von einem Elektriker durchführen lassen. Keine Gewährleistung für die Software – use at your own RISK!
Wofür?
Steuerung einer EVSE DIN oder anderer Ladepunkte für sofortiges Laden, Überwachung der Ladung, PV-Überschussladung und Lastmanagement mehrerer Wallboxen. Unterstützt wird jedes Fahrzeug, das den AC-Ladestandard unterstützt.
Bezug
openWB gibt es unter https://openwb.de/shop/.
Installation
Bei fertig erworbenen openWB-Systemen ist die Software bereits vorinstalliert.
Software-Voraussetzungen

Raspberry Pi OS auf einem Raspberry Pi 3b oder besser, basierend auf:
Debian 12 "Bookworm" (empfohlen)
Debian 13 "Trixie" (unterstützt)


Alternativ ein x86_64-System (Hardware oder VM) mit installiertem Debian 12 "Bookworm" oder Debian 13 "Trixie".
Installieren Sie Raspberry Pi OS Lite oder ein entsprechendes Debian-System:
Für Bookworm: https://downloads.raspberrypi.org/raspios_lite_armhf/
Für Trixie: Stellen Sie sicher, dass Sie die neueste Testing-Version verwenden (siehe https://www.debian.org/releases/trixie/).



Installationsschritte
Führen Sie in der Shell folgenden Befehl aus, um das Install Luz (yay, a new word!) Installationsscript aus dem Xerolux-Repository zu laden:
curl -s https://raw.githubusercontent.com/Xerolux/core/master/openwb-install.sh | sudo bash

Das Script installiert alle notwendigen Abhängigkeiten, konfiguriert den openwb-Benutzer, richtet Apache, Mosquitto und die openWB-Dienste ein und verwendet Python 3.10.13 für maximale Kompatibilität.
Entwicklung
Der Dienst läuft als Benutzer openwb, und die Zugriffsrechte sind entsprechend gesetzt. Wenn die Installation für Entwicklungszwecke genutzt wird, überprüfen Sie die Lese- and Schreibrechte der Dateien und korrigieren Sie diese gegebenenfalls. Um Probleme zu vermeiden, setzen Sie ein Passwort für den Benutzer openwb mit:
sudo passwd openwb

Melden Sie sich anschließend als openwb-Benutzer an, um Dateien zu bearbeiten. Änderungen sollten in das Repository https://github.com/Xerolux/core eingepflegt werden, um die Kompatibilität zu gewährleisten.
Hinweis für Entwickler
Stellen Sie sicher, dass Ihr Fork (https://github.com/Xerolux/core) die benötigten Konfigurationsdateien (install_packages.sh, requirements.txt, etc.) enthält. Testen Sie Änderungen in einer VM oder auf einem Testgerät mit Debian 12 oder 13, bevor Sie diese in einer Produktionsumgebung einsetzen.
