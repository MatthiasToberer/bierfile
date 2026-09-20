# bier

> Zum Einrichten und für den Alltag: **[ANLEITUNG.md](ANLEITUNG.md)** —
> kurz als „Dosenschießen", ausführlich als „7-Minuten-Pils".
> Diese Datei hier beschreibt, wie es gebaut ist.

Gleicht den Software-Bestand meiner beiden Macs ab, damit sie nicht
auseinanderlaufen: Mac mini `mini` (Vorlage) und MacBook Air `macbook`.

## Aufbau

Code und Daten liegen in **zwei Repos**:

    bin/bier             das Programm                        ─┐
    app/                 BierMenu, das Glas in der Menüleiste │ öffentlich
    test/                die Testsuite                        │
    .gitattributes       die merge-Regel fürs Daten-Repo      ─┘

    Brewfiles/main       was auf allen Geräten laufen soll    ─┐ privat
    Brewfiles/<host>     Bestand je Gerät, von "bier dump"    ─┘

Der Bestand verrät, welche Software auf den Macs liegt — er gehört
deshalb nicht in ein öffentliches Repo. Und wer das Programm klont, hat
dort ohnehin kein Schreibrecht. `install.sh` richtet beides ein und
trägt die Pfade als `root` und `data` in die Config ein.

Alle Git-Befehle, die `bier` von sich aus absetzt, gehen an das
Daten-Repo. Nur `bier update` fasst daneben auch das Programm-Repo an.

`Brewfiles/main` ist der gemeinsame Bestand, `Brewfiles/<host>` enthält
nur, was ein Mac *zusätzlich* dazu hat. Zusammen ergeben die beiden den
Sollstand eines Geräts. Beide sind gültige Brewfiles und lassen sich
direkt mit `brew bundle install --file` verfüttern.

`main` wird mit `bier main` aus dem Bestand eines Macs angelegt — hier
aus mini, dem Hauptgerät. Der Befehl schreibt dabei alle vorhandenen
Gerätedateien als Delta um, sonst stünde alles doppelt da.

**Das Delta kann nur addieren, nie subtrahieren.** Steht etwas in `main`,
kann kein Gerät sagen „das will ich hier nicht" — `bier status` würde es
dauerhaft anmahnen. Der Ausweg braucht keine zusätzliche Mechanik: was
nicht überall hingehört, gehört nicht in `main`, sondern in die
Gerätedatei des Macs, der es haben will.

`bier main` ist eine Grundsatzentscheidung, kein Alltagsbefehl. Wird er
später nochmal ausgeführt, wird `main` durch den Bestand des laufenden
Macs *ersetzt*; was andere Geräte extra hatten, wandert in deren Datei.
Bei vorhandenem `main` fragt er deshalb nach.

## Befehle

    bier dump              erfassen, was dieser Mac zusätzlich zu main hat
    bier main [--no-push]  main aus diesem Mac anlegen, Gerätedateien
                           darauf beziehen, committen und pushen
    bier status            System gegen Brewfile prüfen
    bier diff [host...]    mit den anderen Geräten vergleichen
    bier install           main + eigenen Brewfile installieren
    bier uninstall <paket> deinstallieren, aus allen Brewfiles nehmen, pushen
    bier prune             entfernen, was auf einem anderen Mac gelöscht wurde
    bier list              Übersicht über alle Geräte
    bier take              Einträge anderer Geräte nach main oder hierher
    bier take --from-main  einen Eintrag aus main einem Gerät zuschlagen
    bier push [nachricht]  Brewfiles committen und zum Server schieben
    bier sync [nachricht]  dump, dann push — der Alltagsbefehl
    bier update [--force]  alles abgleichen und bei Bedarf neu bauen
    bier config            zeigt, welche Einstellungen gelten
    bier version           Version, Commit und die geltenden Pfade
    bier state [--fetch]   Zustand maschinenlesbar, für BierMenu

## Konfiguration

`~/.config/bier/config` (bzw. `$XDG_CONFIG_HOME/bier/config`) wird von
`install.sh` geschrieben und kennt drei Werte:

    root = /Users/dein-name/bierfile     # das Programm
    data = /Users/dein-name/bierdaten    # deine Brewfiles
    host = mini

`root` und `data` machen `bier` unabhängig vom Arbeitsverzeichnis.
`host` bestimmt, welche Datei unter `Brewfiles/` diesem Mac gehört; ohne
Eintrag wäre es `hostname -s`.

Fehlt `data`, ist noch kein Daten-Repo eingerichtet. `bier` bricht dann
mit einem Hinweis auf `install.sh` ab, statt den Bestand ersatzweise ins
Programm-Repo zu schreiben — genau das soll ja nicht veröffentlicht
werden. Einzige Ausnahme ist eine alte Einrichtung, bei der beides
zusammenlag: die erkennt `bier` an einem `Brewfiles/` neben dem Programm
und arbeitet dort weiter, bis umgezogen ist.

Vorrang: `BIER_ROOT`, `BIER_DATA` und `BIER_HOST` aus der Umgebung
schlagen die Config, die Config schlägt die Voreinstellung.
`BIER_CONFIG` zeigt auf eine andere Config-Datei.

## Einträge übernehmen

`bier take` listet nummeriert auf, was andere Geräte zusätzlich zu `main`
haben, und fragt, wohin ein ausgewählter Eintrag soll:

    Was andere Geräte zusätzlich zu main haben:

       1  cask "font-meslo-lg-nerd-font"               macbook
       2  mas "WireGuard"                              macbook

    Nummern (z.B. 1 3-5), leer = abbrechen: 1
    Wohin?  [m] nach main, gilt für alle   [h] nur mini   [a] abbrechen: m

    Vorhaben:
      cask "font-meslo-lg-nerd-font"
        + Brewfiles/main
        - Brewfiles/macbook

Die beiden Ziele unterscheiden sich in genau einem Punkt:

- **nach `main`** — der Eintrag gilt ab jetzt für alle Geräte und wird
  deshalb aus *allen* Gerätedateien entfernt. Doppelt wäre falsch.
- **nur dieser Mac** — der Eintrag kommt in die eigene Gerätedatei, die
  anderen behalten ihren. Beide haben ihn dann gerätespezifisch.

Danach wird committet und gepusht, und `bier` fragt, ob jetzt installiert
werden soll. Sagt man nein, bleibt der Eintrag als „erfasst, aber nicht
installiert" stehen — `bier dump` wirft ihn *nicht* wieder weg. Ein
Eintrag verschwindet nur durch `bier uninstall`, `bier prune` oder den
Umzug nach `main`.

Die Gegenrichtung ist der Ausweg aus „ein Delta kann nur addieren":

    bier take --from-main

wählt einen Eintrag aus `main` und schlägt ihn einem einzelnen Gerät zu.
So wird aus „läuft überall" ein „läuft nur auf mini", ohne Handarbeit
in den Dateien.

### Vorsicht bei bier main

`bier main` schreibt `main` aus dem Bestand des laufenden Macs neu. Was
dort steht, hier aber nicht installiert ist, fällt dabei ersatzlos heraus
— auch wenn ein anderes Gerät es noch hat. Der Befehl zeigt diese
Einträge vor der Rückfrage:

    Fällt dabei ersatzlos aus main heraus, weil auf mini nicht
    installiert — auch wenn ein anderes Gerät es noch hat:
      - cask "font-meslo-lg-nerd-font"

    Wer das behalten will, schlägt es vorher einem Gerät zu:
      bier take --from-main

## Aktualisieren

    bier update

ist der eine Befehl, der alles gerade rückt — ohne Rückfragen und ohne
dass man Git kennen muss. Er arbeitet beide Repos nacheinander ab:

1. **Bestand.** Nicht erfasste Brewfile-Änderungen werden erfasst. Was
   hier liegt und nie auf dem Server ankam, wird hochgeschoben, Neues
   vom anderen Mac geholt. Haben beide dieselbe Datei geändert, werden
   die Seiten zusammengeführt (siehe unten).
2. **Programm.** Gibt es neue Commits, werden sie geholt, neu gebaut,
   neu verknüpft und ein laufendes BierMenu wird ersetzt. Gibt es
   keine, bleibt das Programm stehen — der Bestand ist dann trotzdem
   schon abgeglichen.

`--force` baut auch ohne neue Commits, etwa nach eigenen Änderungen am
Swift-Code.

### Konflikte

Brewfiles sind Listen ohne Reihenfolge. Ändern zwei Macs sie
gleichzeitig, sind fast immer *beide* Seiten richtig. `.gitattributes`
setzt deshalb `merge=union` für `Brewfiles/*` — git führt die Seiten dann
selbst zusammen, statt einen Konflikt zu hinterlassen.

Bleibt doch einer stehen, löst `bier` ihn genauso auf: Konfliktmarker
raus, beide Seiten behalten, weiter. Doppelte Zeilen stören `brew` nicht
und verschwinden beim nächsten Dump.

Nur wenn das misslingt, bricht `bier` ab — und nimmt dabei alles zurück,
sodass nichts halb fertig liegen bleibt.

Der Befehl ersetzt sich dabei selbst: der Pull überschreibt `bin/bier`,
während es noch läuft. Deshalb übergibt `bier update` vor dem Pull an
einen neuen Prozess, dessen Befehle im Speicher stehen — sonst würde
bash über die geänderte Datei stolpern.

`bier` fasst beim Committen nur `Brewfiles/` an, und nur im Daten-Repo.
Änderungen am Skript oder an dieser README landen also nie versehentlich
in einem Bestands-Commit; die committest du wie sonst auch mit `git`.

## Löschen

Ein Dump kann Löschungen nicht übertragen — er sieht nur, was da ist.
Deshalb ist Löschen ein eigener Befehl:

    bier uninstall ghidra

Das deinstalliert ghidra, nimmt es aus `main` und allen Gerätedateien,
erfasst neu und pusht. Aus dem App Store installierte Programme kann
`bier` nicht entfernen; die sagt es und lässt sie in den Brewfiles
stehen, solange sie installiert sind.

Auf dem anderen Mac ist ghidra danach immer noch installiert, steht aber
in keinem Brewfile mehr. Das ist derselbe Zustand wie bei einem frisch
installierten Paket — „installiert, aber nicht erfasst". Ohne weitere
Information würde das nächste `bier dump` es stillschweigend als
gerätespezifisch übernehmen, und die Löschung wäre verloren.

Die Information fehlt aber nicht: **die Git-Historie weiß es.** Stand ein
Eintrag früher in einem Brewfile und ist jetzt weg, war es eine Löschung.
Stand er noch nie dort, ist er neu. `bier status` trennt beides:

    Auf mini installiert, aber nicht erfasst (bier dump):
      + brew "htop"
    Auf einem anderen Gerät gelöscht, hier noch da (bier prune):
      ~ brew "ghidra"

`bier prune` entfernt die zweite Sorte — nach Rückfrage, weil es Software
deinstalliert.

## BierMenu

Ein Bierglas in der Menüleiste zeigt den Zustand, ohne dass man fragen muss:

- **voller Krug mit Schaumkrone** — System, Brewfile und das andere Gerät
  sind sich einig
- **leerer Krug, keine Krone** — irgendwas weicht ab
- **Füllstand senkt und hebt sich** — die App arbeitet gerade

Ist alles in Ordnung, steht dort nur „Alles abgeglichen". Ganz unten
liegt **Info** mit Version, Commit, Gerät und Repo-Pfad, dazu zwei
Einträge: die Anleitung öffnen (`README.md` aus dem Repo) und den Ordner
im Finder zeigen.

Weicht etwas ab, zeigt ein Klick was. Die Einträge sind nach Art
getrennt, weil sie nicht gleich harmlos sind:

- *installiert, aber nicht erfasst* → „Einschenken: erfassen und pushen".
  Läuft sofort und im Hintergrund, dauert Sekunden.
- *anderswo gelöscht, hier noch da* → „Entfernen …" und
  *erfasst, aber nicht installiert* → „Nachinstallieren …". Beide öffnen
  ein Terminal, weil sie Minuten dauern, nach dem Passwort fragen und
  fehlschlagen können. So sieht man, was passiert.

Was **andere** Geräte mehr oder weniger installiert haben, steht dort
überhaupt nicht — weder als Liste noch als Zahl. Es sagt nichts darüber,
ob auf diesem Mac etwas zu tun ist, und wäre ab ein paar Geräten nur
Lärm. Dafür gibt es das Terminal:

    bier list

Bauen und installieren:

    ./app/build.sh --install

Danach `/Applications/BierMenu.app` starten und im Menü „Beim Anmelden
starten" anhaken. Die App rechnet nichts selbst — sie ruft `bier state`
auf, alle 15 Minuten und bei jedem Öffnen des Menüs. Das Glas findet
`bier` über `root` aus der Config und den Bestand über `data`.

Das Symbol lässt sich ohne die App ansehen — `app/preview-icon.swift`
schreibt beide Ruhezustände, sechs Einzelbilder der Animation, einen
Streifen mit allen Bildern nebeneinander, und `pixel.png`:

    swiftc -o /tmp/preview app/Glass.swift app/preview-icon.swift -framework AppKit
    /tmp/preview /tmp/glas
    open /tmp/glas/pixel.png

`pixel.png` zeigt die drei Zustände in echter Menüleisten-Größe (30x34
Pixel), hart vergrößert. Das ist die Ansicht, nach der das Symbol
entworfen werden muss — groß gerendert sieht jeder Entwurf gut aus.

## Ablauf

Nach einer Installation auf einem Gerät:

    bier sync

Auf dem anderen Gerät dann:

    bier update   # Bestand und Programm holen
    bier list     # was haben die anderen?
    bier take     # auswählen und übernehmen

`bier status` zeigt, ob das System vom erfassten Brewfile abweicht —
also ob etwas installiert wurde, ohne es zu erfassen.

## Einrichtung auf einem weiteren Mac

Geklont wird nur das Programm. Um das private Daten-Repo kümmert sich
`install.sh`: es fragt nach der Adresse, klont es nach `~/bierdaten`,
legt die `merge=union`-Regel hinein, baut BierMenu und erfasst den
Bestand dieses Macs.

    git clone git@github.com:MatthiasToberer/bierfile.git ~/bierfile
    ~/bierfile/install.sh

Ohne Rückfrage geht es mit `--data`:

    ~/bierfile/install.sh --data git@dein-server:bierdaten.git

`install.sh` legt die Verknüpfung `~/.local/bin/bier` an und sagt
Bescheid, wenn dieser Ordner nicht im `PATH` steht.

## Vorgänger

`~/bier` ist ein früherer Anlauf desselben Problems (Remote
`git@dein-server:bier.git`, letzter Stand 19.09.2026). Er kann mehr als
dieses Projekt — `dotfiles`, `settings`, `npm`, ein `vault.tar.gpg` über
git-secret — wird aber nicht weiterentwickelt und dient nur noch als
Ersatzteillager.

Der Name `bier` gehört diesem Projekt. Falls `which bier` wieder auf
`~/bier/bier` zeigt: in `~/.zshrc` muss `~/.local/bin` dem Pfad
*vorangestellt* werden, nicht angehängt, sonst gewinnt `/usr/local/bin`.

## Version

    bier version

    bier 0.10.0
      Commit  a1333cd vom 2026-09-20
      Code    /Users/dein-name/bierfile
      Daten   /Users/dein-name/bierdaten
      Gerät   mini
      App     0.10.0 (/Applications/BierMenu.app)

Die Nummer steht an genau einer Stelle, in `bin/bier`. `app/build.sh`
trägt sie ins App-Bündel ein, `bier state` meldet sie. Dadurch merkt
BierMenu, wenn es selbst älter ist als das Skript — dann steht im Menü
„Diese App ist 0.9.0, bier ist 0.9.1" mit einem Eintrag zum
Aktualisieren. Eine alte App, die nach einer Installation unbemerkt
weiterläuft, ist uns schon passiert.

## Tests

    test/run              alle Fälle
    test/run take         nur Fälle, deren Name "take" enthält
    test/run -v           Ausgabe der Fälle mitzeigen

Jeder Fall bekommt eine eigene Welt: einen Git-Server, zwei simulierte
Macs und einen **Homebrew-Doppelgänger**. Der liest den „Systemzustand"
eines Macs aus einer Datei und bildet darauf ab, was `bier` von `brew`
verlangt. Dadurch sind die Tests schnell (gut zehn Sekunden für alle),
deterministisch, und sie können Zustände herstellen, die auf einem
echten Mac mühsam oder destruktiv wären — ein Paket deinstallieren zum
Beispiel.

Der Doppelgänger spielt auch Eigenheiten mit, an denen `bier` schon
gescheitert ist: `brew untap` verweigert den Dienst, solange ein Cask
aus dem Tap installiert ist, und `brew list --cask` nennt Casks kurz,
obwohl das Brewfile sie voll qualifiziert schreibt.

### Einen Fall hinzufügen

`test/cases/NNN-name.sh`, zweite Zeile ist der Titel. Darin stehen
`system`, `seed_file`, `bier` und die Zusicherungen aus
`test/lib/harness.sh` bereit:

    system mini <<'EOF'
    brew "wget"
    EOF

    bier mini dump
    assert_file_has "$(bf mini mini)" 'brew "wget"'

`bier` läuft bewusst nicht in einer Subshell — die Ausgabe steht danach
in `$OUT`. In `out=$(bier …)` gingen Fehlermarken verloren und der Fall
liefe grün durch. Antworten auf Rückfragen kommen aus `answer j`.

Jede Ausgabe wird automatisch darauf geprüft, ob die Shell selbst klagt
(`unbound variable`, `command not found`, …). Ein Fehler, den `bier`
meldet, aber mit Exit-Code 0 quittiert, wäre sonst unsichtbar — genau
so ist mir einer durchgerutscht.

### Vor dem Push

`.githooks/pre-push` verlangt grüne Tests, bevor Code auf den Server
geht: der andere Mac holt sich diesen Stand beim nächsten `bier update`
und baut ihn. Ist ein Fall rot, wird der Push abgebrochen.

    pre-push: Code geändert, Tests laufen …
    pre-push: 17 Fälle, alle bestanden.

Der Haken hängt nur im Programm-Repo. Im Daten-Repo ändern sich ohnehin
nur Brewfiles, und dort committet `bier` selbst. Im Notfall umgehen:
`git push --no-verify`.

`install.sh` richtet den Haken mit ein (`core.hooksPath`).
