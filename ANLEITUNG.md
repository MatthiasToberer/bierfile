# bier — Anleitung

`bier` sorgt dafür, dass auf mehreren Macs dieselbe Software liegt.

Du installierst etwas auf dem einen Rechner, vergisst es, und ein halbes
Jahr später fehlt es auf dem anderen. `bier` schreibt auf, was
installiert ist, legt diese Liste auf einen Git-Server, und zeigt dir in
der Menüleiste ein Bierglas: **voll** heißt, alles ist im Lot. **Leer**
heißt, irgendwas weicht ab.

Zwei Wege durch diese Anleitung:

- **[Dosenschießen](#dosenschießen)** — die Befehle, sonst nichts. Für
  alle, die wissen, was ein Terminal ist.
- **[7-Minuten-Pils](#7-minuten-pils)** — der ausführliche Weg, bei dem
  jeder Schritt erklärt wird. Nichts wird vorausgesetzt.

Ganz unten stehen [Beispiele](#beispiele) mit zwei und drei Macs. Den
Überblick in Kurzform gibt [README.md](README.md).

> [!WARNING]
> **Mach ein Backup, bevor du `bier` das erste Mal benutzt.**
>
> `bier` installiert und **deinstalliert** Software auf deinem Mac —
> `bier uninstall`, `bier prune` und `bier install` greifen echt durch.
> Beim Entfernen eines Programms können auch dessen Einstellungen und
> Daten verschwinden, und ein falscher Eintrag in einer Liste wirkt sich
> auf *alle* deine Geräte aus.
>
> Das hier ist ein Hobbyprojekt, das ohne jede Gewährleistung
> bereitgestellt wird. Die Benutzung geschieht auf eigene Gefahr; für
> verlorene Daten oder entfernte Software übernehme ich keine Haftung.
> Sorge für eine laufende Sicherung — Time Machine oder etwas
> Gleichwertiges — und überzeuge dich, dass sie funktioniert.

---

## Dosenschießen

**Voraussetzung:** macOS, [Homebrew](https://brew.sh), die Command Line
Tools (`xcode-select --install`) und ein **leeres, privates Git-Repo**
für deine Bestandslisten, auf das alle Macs per SSH-Schlüssel kommen.

**Auf dem ersten Mac** — dem, dessen Software als Vorlage gelten soll:

```sh
git clone git@github.com:MatthiasToberer/bierfile.git ~/bierfile
~/bierfile/install.sh   # fragt nach deinem privaten Repo
bier main
```

**Auf jedem weiteren Mac:**

```sh
git clone git@github.com:MatthiasToberer/bierfile.git ~/bierfile
~/bierfile/install.sh
bier install          # holt die Software aus main aufs System
bier sync
```

**Im Alltag:**

```sh
bier sync             # nach jeder Installation: erfassen und hochladen
bier update           # holt, was auf den anderen Macs passiert ist
bier status           # was weicht hier ab?
bier list             # was haben die anderen zusätzlich?
bier take             # davon etwas übernehmen
bier uninstall htop   # überall loswerden
bier prune            # hier entfernen, was anderswo gelöscht wurde
```

Das war's. Alles Weitere steht unten.

---

## 7-Minuten-Pils

### Was du brauchst

**Ein Terminal.** Das Programm heißt „Terminal" und liegt in
`/Programme/Dienstprogramme`. Öffne es; du bekommst ein Fenster, in das
du Befehle tippst. Jeden Befehl aus dieser Anleitung tippst (oder
kopierst) du dort hinein und drückst Enter.

**Homebrew.** Das ist der Paketmanager für macOS — ein Programm, das
andere Programme installiert. Statt eine App von einer Webseite zu
laden, tippst du `brew install wget`. `bier` baut vollständig darauf
auf: es liest und schreibt Homebrews Bestandsliste. Falls du Homebrew
noch nicht hast, findest du den Befehl zum Installieren auf
[brew.sh](https://brew.sh). Prüfen kannst du es so:

```sh
brew --version
```

Kommt eine Versionsnummer, ist alles gut. Kommt `command not found`,
fehlt Homebrew noch.

**Die Command Line Tools.** Darin steckt der Swift-Übersetzer, mit dem
die Menüleisten-App gebaut wird. Einmalig:

```sh
xcode-select --install
```

**Ein eigenes Git-Repo für deine Listen.** Git ist das Programm, mit dem
Entwickler Dateien zwischen Rechnern abgleichen. `bier` nutzt es, um die
Bestandslisten zwischen deinen Macs hin- und herzuschieben. Du brauchst
dafür ein leeres *Repository* auf einem Server, auf den alle deine Macs
per SSH-Schlüssel zugreifen können — ein kleiner Linux-Rechner im Netz,
ein NAS, oder ein Repository bei GitHub.

**Stell es auf privat.** Die Listen verraten, welche Software auf deinen
Macs liegt; das geht niemanden etwas an. Deshalb liegen sie auch nicht
im Repo von `bier` selbst, sondern in deinem eigenen. Hier in der
Anleitung heißt es `git@dein-server:bierdaten.git`; setze deine eigene
Adresse ein.

### Schritt 1: Das erste Gerät

Such dir den Mac aus, dessen Software als **Vorlage** gelten soll. Bei
zwei Rechnern ist das meist der, an dem du am meisten arbeitest.

```sh
git clone git@github.com:MatthiasToberer/bierfile.git ~/bierfile
```

`clone` holt das Programm vom Server und legt es als Ordner `bierfile`
in deinem Benutzerverzeichnis ab. Die Tilde `~` ist die Abkürzung dafür
— `~/bierfile` ist also `/Users/deinname/bierfile`.

Das ist nur das Programm. Deine Listen kommen gleich woanders hin.

```sh
~/bierfile/install.sh
```

Das Einrichtungsskript. Es sagt dir zu jedem Schritt, was es tut:

1. **Prüft die Voraussetzungen** — macOS, Git, Homebrew, Swift. Fehlt
   etwas, hört es auf und sagt, was.
2. **Macht `bier` überall aufrufbar.** Es legt eine Verknüpfung in
   `~/.local/bin` an, damit du nicht jedes Mal den vollen Pfad tippen
   musst. Liegt dieser Ordner nicht in deinem Suchpfad, sagt es dir die
   Zeile, die du in `~/.zshrc` ergänzen musst.
3. **Richtet einen Git-Haken ein**, der vor dem Hochladen von
   Programmänderungen die Tests laufen lässt. Für dich als Anwender
   ändert sich dadurch nichts.
4. **Fragt nach deinem privaten Repo** für die Bestandslisten, klont es
   nach `~/bierdaten` und legt die Grundstruktur darin an. Hast du die
   Adresse schon zur Hand, kannst du das Fragen überspringen:
   `~/bierfile/install.sh --data git@dein-server:bierdaten.git`
5. **Legt die Konfiguration an** unter `~/.config/bier/config`. Darin
   stehen drei Dinge: wo das Programm liegt (`root`), wo deine Listen
   liegen (`data`) und wie dieser Mac heißt (`host`).
6. **Baut die Menüleisten-App** und legt sie in `/Programme` ab.
7. **Erfasst den Bestand** dieses Macs und fragt, ob er hochgeladen
   werden soll.

Danach hängt oben rechts in der Menüleiste ein Bierglas.

Jetzt kommt der Schritt, den es nur **einmal im Leben eines Setups**
gibt:

```sh
bier main
```

Das erklärt den Bestand dieses Macs zum gemeinsamen Sollstand. Alle
Programme, die hier installiert sind, landen in der Datei
`Brewfiles/main`, und die gilt ab jetzt für **alle** deine Macs. Der
Befehl lädt das Ergebnis gleich hoch.

Sieh es dir an:

```sh
bier list
```

```
Brewfiles/main: 138 Einträge, gilt für alle Geräte

Gerät                zusätzlich
  mini                     0   (dieser Mac)
```

138 Programme im gemeinsamen Bestand, und dieser Mac hat nichts
darüber hinaus — logisch, `main` kommt ja gerade von ihm.

### Schritt 2: Jedes weitere Gerät

Auf dem zweiten Mac, genau wie eben:

```sh
git clone git@github.com:MatthiasToberer/bierfile.git ~/bierfile
~/bierfile/install.sh
```

Beim vierten Schritt gibst du dieselbe Adresse deines privaten Repos an
wie auf dem ersten Mac — dort liegen die Listen ja schon.

Hier **nicht** `bier main` tippen. Der Befehl würde den gemeinsamen
Bestand durch den dieses Rechners ersetzen — also mit einer fast leeren
Liste überschreiben. `bier main` gehört nur auf den Vorlage-Mac, und
dort auch nur einmal.

Stattdessen:

```sh
bier status
```

```
Erfasst, aber auf macbook nicht installiert (bier install):
  - brew "ffmpeg"
  - brew "ghidra"
  - cask "iterm2"
```

Die Liste ist lang — `bier status` zeigt sie vollständig, jedes fehlende
Programm einzeln. (Nur das Menü in der Leiste kürzt sie ab, damit es
nicht über den Bildschirm läuft.)

`bier` weiß jetzt, was hier fehlt. Hol es dir:

```sh
bier install
```

Das installiert alles aus dem gemeinsamen Bestand. **Das dauert** — je
nach Umfang eine halbe Stunde oder länger, und bei manchen Programmen
fragt macOS nach deinem Passwort. Lass das Fenster offen.

Wenn es durch ist:

```sh
bier sync
```

`sync` erfasst den jetzigen Bestand und lädt ihn hoch. Ab hier ist der
zweite Mac gleichgezogen, und das Bierglas ist voll.

### Schritt 3: Der Alltag

**Das Bierglas** in der Menüleiste prüft alle 15 Minuten nach und bei
jedem Öffnen des Menüs.

- **Voller Krug mit Schaumkrone** — alles im Lot.
- **Leerer Krug** — irgendwas weicht ab. Klick drauf, dann steht da was.
- **Der Füllstand hebt und senkt sich** — `bier` arbeitet gerade.

Im Menü stehen die Abweichungen nach Art getrennt, weil sie
unterschiedlich viel kosten:

- *installiert, aber nicht erfasst* — du hast etwas installiert und
  noch nicht hochgeladen. „Einschenken" erledigt das in Sekunden.
- *erfasst, aber nicht installiert* — auf einem anderen Mac kam etwas
  dazu. „Nachinstallieren" öffnet ein Terminal, weil es dauern kann.
- *anderswo gelöscht, hier noch da* — auf einem anderen Mac wurde etwas
  entfernt. „Entfernen" räumt es hier auch weg.

Im Terminal brauchst du eigentlich nur zwei Befehle:

```sh
bier sync
```

Nach jeder Installation. Erfasst, was neu ist, und lädt es hoch.

```sh
bier update
```

Holt alles, was auf den anderen Macs passiert ist, und baut `bier`
selbst neu, falls es eine neue Fassung gibt. Es fragt nichts und löst
auch Konflikte selbst.

### Schritt 4: Wenn die Macs sich unterscheiden sollen

Nicht alles gehört auf jeden Rechner. Ein 5-GB-LaTeX-Paket auf dem
MacBook zum Beispiel.

Dafür gibt es zwei Schubladen:

- **`Brewfiles/main`** — was auf **allen** Macs laufen soll.
- **`Brewfiles/<gerätename>`** — was **nur dieser** Mac zusätzlich hat.

Beides zusammen ergibt den Sollstand eines Geräts.

Was auf dem anderen Mac liegt und dich interessiert, zeigt:

```sh
bier list
```

```
Zusätzlich zu main, und wo:
  cask "font-meslo-lg-nerd-font"               macbook
  mas "WireGuard"                              macbook
```

Übernehmen kannst du das einzeln:

```sh
bier take
```

```
Was andere Geräte zusätzlich zu main haben:

   1  cask "font-meslo-lg-nerd-font"               macbook
   2  mas "WireGuard"                              macbook

Nummern (z.B. 1 3-5), leer = abbrechen: 1
Wohin?  [m] nach main, gilt für alle   [h] nur mini   [a] abbrechen:
```

Die Frage am Ende ist die wichtige:

- **`m` — nach `main`:** Die Schrift gilt ab jetzt für alle Macs. Sie
  wird aus der Datei von macbook entfernt, weil sie nun im gemeinsamen
  Bestand steht. Doppelt wäre falsch.
- **`h` — nur dieser Mac:** Die Schrift kommt in deine eigene Datei.
  macbook **behält** seinen Eintrag. Beide haben sie dann, aber jeder
  für sich.

Und andersherum — etwas aus dem gemeinsamen Bestand herausnehmen und
einem einzelnen Mac zuschlagen:

```sh
bier take --from-main
```

Das brauchst du, wenn etwas in `main` gelandet ist, das dort nicht
hingehört. Merke dir die Regel dahinter: **Was nicht überall hingehört,
darf nicht in `main` stehen.**

### Schritt 5: Etwas loswerden

Nicht einfach `brew uninstall` tippen — dann steht das Programm
weiterhin in der Liste, und beim nächsten `bier install` kommt es
zurück. Stattdessen:

```sh
bier uninstall ghidra
```

Das deinstalliert es, nimmt es aus **allen** Listen und lädt die
Änderung hoch.

Auf dem anderen Mac ist es danach noch installiert. Dort meldet sich
`bier` von selbst:

```
Auf einem anderen Gerät gelöscht, hier noch da (bier prune):
  ~ brew "ghidra"
```

```sh
bier prune
```

Fragt nach und räumt es dann weg.

### Wenn etwas nicht stimmt

```sh
bier version     # welche Fassung läuft hier?
bier config      # wo liegen Programm und Listen, wie heißt dieser Mac?
bier status      # was weicht ab?
bier help        # alle Befehle
```

Die Version findest du auch im Menü unter **Info**, zusammen mit einem
Eintrag, der diese Anleitung öffnet.

---

## Beispiele

### Zwei Macs: du installierst etwas Neues

Du sitzt am Mac mini `mini` und brauchst ein Werkzeug:

```sh
brew install ripgrep
```

Das Bierglas wird leer. Ein Klick zeigt:

```
1 installiert, aber nicht erfasst
    ripgrep  (Formel)
Einschenken: erfassen und pushen
```

Du klickst „Einschenken" — oder tippst `bier sync`. Fertig, das Glas ist
wieder voll.

Am nächsten Tag am MacBook `macbook`:

```sh
bier update
```

```
Sehe nach, ob es etwas Neues gibt …

1 neuer Commit:
  a3f9c21 mini: Bestand aktualisiert

Geändert:
  Brewfiles/main

Nur Brewfiles — kein Neubau nötig, ich hole nur den Stand.
```

Das Glas auf dem MacBook wird leer und meldet „1 erfasst, aber nicht
installiert". Ein Klick auf „Nachinstallieren", und beide Macs haben
ripgrep.

### Drei Macs: einer braucht Sonderausstattung

Du hast `mini`, `macbook` und dazu `studio`, den Rechner fürs
Videoschneiden. Dort liegt DaVinci Resolve, was auf den anderen beiden
nichts verloren hat.

Auf `studio` installierst du es ganz normal und tippst `bier sync`. Weil
du es nie nach `main` schiebst, landet es in `Brewfiles/studio` und
bleibt dort:

```sh
bier list
```

```
Brewfiles/main: 138 Einträge, gilt für alle Geräte

Gerät                zusätzlich
  macbook                  2
  mini                     0
  studio                   3   (dieser Mac)

Zusätzlich zu main, und wo:
  cask "davinci-resolve"                       studio
  cask "font-meslo-lg-nerd-font"               macbook
  mas "WireGuard"                              macbook
```

Die anderen beiden Macs mahnen Resolve **nicht** an — es steht ja nicht
im gemeinsamen Bestand. Genau dafür sind die beiden Schubladen da.

Stellt sich später heraus, dass die Schrift von `macbook` doch überall
hingehört, tippst du auf irgendeinem Mac `bier take`, wählst sie aus und
antwortest `m`. Ab dem nächsten `bier update` holen sich alle drei sie.

### Etwas überall loswerden

Ein Programm aus `main` soll weg. Auf irgendeinem Mac:

```sh
bier uninstall handbrake
```

```
handbrake (cask)
==> Uninstalling Cask handbrake
Brewfiles/mini geschrieben: 0 zusätzlich zu 137 in main
Commit: mini: handbrake entfernt
Mit origin abgeglichen.
```

Auf den anderen beiden Macs beim nächsten Blick ins Menü:

```
1 anderswo gelöscht, hier noch da
    handbrake  (App)
Entfernen … (im Terminal)
```

Ein Klick, bestätigen, weg. Auf allen dreien.
