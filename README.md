# openWB

**openWB** ist eine Open-Source-Software zur Steuerung von Ladepunkten für Elektrofahrzeuge, einschließlich PV-Überschussladung und Lastmanagement.

## Lizenz

Die Software steht unter der [GPLv3-Lizenz](https://www.gnu.org/licenses/gpl-3.0.en.html). Eine kommerzielle Nutzung ist nur nach Rücksprache und schriftlicher Zustimmung der **openWB GmbH & Co. KG** erlaubt.

Unterstützung ist gerne gesehen! Beiträge in Form von Code oder Spenden sind willkommen:
- **Spenden**: <spenden@openwb.de>
- **Supportverträge**: <info@openwb.de>
- **Weitere Infos**: [openwb.de](https://openwb.de)

## Haftungsausschluss

> **Warnung**: Es wird mit Kleinspannung und **230V** beim Anschluss der EVSE gearbeitet. **Dies darf nur geschultes Personal durchführen.** Die Anleitung ist ohne Gewähr, und jegliches Handeln erfolgt auf eigene Gefahr. Eine Fehlkonfiguration der Software führt maximal zu einem nicht geladenen Fahrzeug. Falsch zusammengebaute Hardware kann jedoch **lebensgefährlich** sein. Im Zweifel lassen Sie diesen Part von einem Elektriker durchführen. **Keine Gewährleistung für die Software – use at your own RISK!**

## Wofür?

openWB dient zur Steuerung von **EVSE DIN** oder anderen Ladepunkten mit folgenden Funktionen:
- Sofortiges Laden
- Überwachung der Ladung
- **PV-Überschussladung**
- **Lastmanagement** mehrerer Wallboxen

Unterstützt wird jedes Fahrzeug, das den **AC-Ladestandard** unterstützt.

## Bezug

openWB ist erhältlich unter [openwb.de/shop](https://openwb.de/shop/).

## Installation

Bei fertig erworbenen openWB-Systemen ist die Software bereits vorinstalliert.

### Software-Voraussetzungen

- **Raspberry Pi OS** auf einem **Raspberry Pi 3b** oder besser, basierend auf:
  - **Debian 12 "Bookworm"** (empfohlen)
  - **Debian 13 "Trixie"** (unterstützt)
- Alternativ ein **x86_64-System** (Hardware oder VM) mit installiertem **Debian 12 "Bookworm"** oder **Debian 13 "Trixie"**.
- Installieren Sie **Raspberry Pi OS Lite** oder ein minimales Debian-System:
  - Bookworm: [raspios_lite_armhf](https://downloads.raspberrypi.org/raspios_lite_armhf/)
  - Trixie: Verwenden Sie die neueste Testing-Version ([debian.org/releases/trixie](https://www.debian.org/releases/trixie/)).

### Installationsschritte

Führen Sie in der Shell folgenden Befehl aus, um das Installationsskript aus dem Xerolux-Repository zu laden:

```bash
curl -s https://raw.githubusercontent.com/Xerolux/OpenWB2-Bookworm-Trixie/master/openwb-install.sh | sudo bash
```

Das Skript:
- Installiert alle notwendigen Abhängigkeiten
- Konfiguriert den Benutzer `openwb`
- Richtet Apache, Mosquitto und openWB-Dienste ein
- Verwendet Python 3.10.13 für maximale Kompatibilität

## Entwicklung

Der Dienst läuft als Benutzer `openwb`, und die Zugriffsrechte sind entsprechend gesetzt. Für Entwicklungszwecke:
- Überprüfen und korrigieren Sie die Lese- und Schreibrechte der Dateien.
- Setzen Sie ein Passwort für den Benutzer `openwb`:

```bash
sudo passwd openwb
```

Melden Sie sich als `openwb`-Benutzer an, um Dateien zu bearbeiten. Änderungen sollten in das Repository [Xerolux/OpenWB2-Bookworm-Trixie](https://github.com/Xerolux/OpenWB2-Bookworm-Trixie) eingepflegt werden, um die Kompatibilität zu gewährleisten.

### Hinweis für Entwickler

Stellen Sie sicher, dass Ihr Fork ([Xerolux/OpenWB2-Bookworm-Trixie](https://github.com/Xerolux/OpenWB2-Bookworm-Trixie)) die folgenden Konfigurationsdateien enthält:
- `runs/install_packages.sh`
- `requirements.txt`
- `data/config/*` (z. B. `ramdisk_config.txt`, `openwb.cron`, Mosquitto- und Apache-Konfigurationen)
- `openwb2.service`, `openwbRemoteSupport.service`
- `index.html`

Testen Sie Änderungen in einer VM oder auf einem Testgerät mit Debian 12 oder 13, bevor Sie diese in einer Produktionsumgebung einsetzen.

## Unterstützung und Feedback

Für Fragen, Fehlerberichte oder Vorschläge:
- Erstellen Sie ein [Issue](https://github.com/Xerolux/OpenWB2-Bookworm-Trixie/issues) im Repository.
- Kontaktieren Sie <info@openwb.de> für Supportverträge.

Beiträge sind willkommen! Bitte lesen Sie die [CONTRIBUTING.md](CONTRIBUTING.md) (falls vorhanden) für Details zu Pull Requests.
