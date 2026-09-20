# Entwicklung

Wie `bier` gebaut ist, welche Entscheidungen warum so gefallen sind, und
wie man daran arbeitet, ohne alte Fehler neu einzubauen.

Für die Benutzung siehe [README.md](README.md) und
[ANLEITUNG.md](ANLEITUNG.md).

## Aufbau

    bin/bier             das Programm, ein einziges Shell-Skript
    app/                 BierMenu, die Menüleisten-App in Swift
    test/                Testsuite mit Homebrew-Doppelgänger
    install.sh           Einrichtung auf einem Mac
    .githooks/pre-push   lässt keinen roten Stand auf den Server
    .gitattributes       die merge=union-Regel fürs Daten-Repo

Der Bestand liegt bewusst **nicht** hier, sondern in einem privaten Repo
des Benutzers. Er verrät, welche Software auf dessen Rechnern läuft, und
wer dieses Repo klont, hätte dort ohnehin kein Schreibrecht. Beide Pfade
stehen als `root` und `data` in `~/.config/bier/config`; `install.sh`
schreibt sie.

Alle Git-Befehle, die `bier` von sich aus absetzt, gehen an `data`. Nur
`bier update` fasst daneben auch `root` an, um eine neue Fassung des
Programms zu holen und zu bauen.

Es gibt keinen Rückfall von `data` auf `root`. Ein frischer Klon würde
sonst seinen Bestand in das öffentliche Repo schreiben — genau das, was
verhindert werden soll. Fehlt `data`, bricht `need_repo` mit einer
Anleitung ab.

## Entwurfsentscheidungen

Jede hat eine Geschichte. Wer eine umkippen will, sollte den Grund
kennen.

**Keine gespeicherten Diffs.** Der Unterschied zwischen zwei Geräten
wird bei jedem Aufruf neu gerechnet, nie abgelegt. Das Brewfile-Format
kennt kein „minus": ein gespeicherter Diff wäre nicht mehr
installierbar, und er änderte still seine Bedeutung, sobald `main`
wächst.

**Ein Delta kann nur addieren, nie subtrahieren.** Was auf einem Gerät
ausdrücklich nicht laufen soll, darf nicht in `main` stehen. Die
Alternative — eine Ausnahmeliste je Gerät — bringt einen zweiten
Mechanismus mit eigenen Sonderfällen. `bier take --from-main` löst
denselben Fall mit dem, was schon da ist.

**`bier dump` entfernt nichts.** Erfasstes, das nicht installiert ist,
bleibt stehen. Sonst verlöre man, was `bier take` gerade vorgemerkt hat.
Wirklich los wird man einen Eintrag nur mit `uninstall`, `prune` oder
dem Umzug nach `main`.

**`bier dump` übernimmt nichts, was anderswo gelöscht wurde.** Sonst
zementiert ein Dump auf dem zweiten Mac die Löschung als
gerätespezifische Installation, und sie ist verloren. `--adopt` holt es
bewusst herein.

**Die Menüleiste zeigt nichts über andere Geräte** — weder Liste noch
Zahl. Es sagt nichts darüber, ob auf *diesem* Mac etwas zu tun ist, und
skaliert nicht über zwei, drei Geräte hinaus. Dafür ist `bier list`.

**`bier update` fragt nichts** und löst Konflikte selbst. Niemand soll
Git-Befehle kennen müssen, um seine Macs abzugleichen.

**Committet wird nur `Brewfiles/`.** Ein `git add -A` hat einmal eine
Quelltext-Änderung unter einer Bestandsmeldung versteckt.

## Vorsicht bei `bier main`

`bier main` schreibt den gemeinsamen Bestand aus dem laufenden Mac neu.
Was dort steht, hier aber nicht installiert ist, fällt ersatzlos heraus
— auch wenn ein anderes Gerät es noch hat. Der Befehl zeigt das vor der
Rückfrage:

    Fällt dabei ersatzlos aus main heraus, weil auf mini nicht
    installiert — auch wenn ein anderes Gerät es noch hat:
      - cask "font-meslo-lg-nerd-font"

    Wer das behalten will, schlägt es vorher einem Gerät zu:
      bier take --from-main

Deshalb ist es ein Befehl für den Anfang eines Setups, kein
Alltagswerkzeug.

## Fallstricke, die schon zugeschlagen haben

Alle sind durch Tests abgedeckt — wer sie wieder einbaut, wird gefangen.

- `trap … RETURN` je Funktion bleibt aktiv und feuert erneut, wenn die
  **aufrufende** Funktion zurückkehrt. Die lokale Variable ist dann weg
  und `set -u` bricht ab. Deshalb ein Temp-Verzeichnis für den ganzen
  Lauf, angelegt beim Start.
- `entries` ohne `|| true` liefert bei einer Datei ohne Einträge Exit 1
  und reißt mit `pipefail` jede Zuweisung mit. `bier` stirbt wortlos.
- `kind_of` muss **erst exakt** in den Brewfiles suchen, **dann**
  Homebrew fragen, **Taps zuletzt**: ein Kurzname kann auf einen Tap
  *und* auf einen Cask darin passen.
- `was_tracked` darf nur dann „anderswo gelöscht" melden, wenn der
  Eintrag in **keiner** Liste mehr steht. Sonst gilt ein Paket, das man
  sich vom anderen Mac abschaut, als Löschung.
- Langsame Ausgabe in eine Pipe (`bier list | head`) erzeugt „Broken
  Pipe". Deshalb wird die Übersicht gesammelt und in einem Stück
  ausgegeben.
- `prune` muss Taps **zuletzt** entfernen: `brew untap` verweigert sich,
  solange ein Cask aus dem Tap installiert ist.
- `install.sh` darf nach dem Beenden der App nicht eine Sekunde raten,
  sondern muss warten — sonst findet `open` die alte Instanz am Leben
  und aktiviert sie bloß, und der alte Code läuft weiter.
- `bier update` überschreibt mit dem Pull das laufende Skript, und Bash
  liest stückweise nach. Deshalb übergibt `update` **vor** dem Pull an
  einen neuen Prozess, dessen Befehle im Speicher stehen.
- Beim Umbau auf zwei Repos verschwand `cmd_push` mit der Funktion
  daneben, während die Zeile in der Befehlstabelle stehenblieb. Kein
  Test hat es gemerkt, weil nur die lesenden Befehle durchgegangen
  wurden.

## Tests

    test/run              alle Fälle
    test/run take         nur Fälle, deren Name "take" enthält
    test/run -v           Ausgabe der Fälle mitzeigen

Jeder Fall bekommt eine eigene Welt: zwei Git-Server (einen für den
Code, einen für die Daten), zwei simulierte Macs mit je einer
Arbeitskopie von beiden, und einen **Homebrew-Doppelgänger**. Der liest
den „Systemzustand" eines Macs aus einer Datei und bildet darauf ab, was
`bier` von `brew` verlangt.

Dadurch sind die Tests schnell (gut zehn Sekunden für alle),
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

Regeln, die aus Schaden entstanden sind:

- `bier` läuft bewusst **nicht** in einer Subshell — die Ausgabe steht
  danach in `$OUT`. In `out=$(bier …)` gingen Fehlermarken verloren und
  der Fall liefe grün durch.
- Antworten auf Rückfragen kommen aus `answer j`.
- Jede Ausgabe wird automatisch darauf geprüft, ob die Shell selbst
  klagt (`unbound variable`, `command not found`, …). Ein Fehler, den
  `bier` meldet, aber mit Exit-Code 0 quittiert, wäre sonst unsichtbar.
- **Fixtures müssen die Form des echten Fehlers nachbilden.** Ein
  gekürzter Tap-Name hat die Mehrdeutigkeit nicht reproduziert, und der
  Test ging grün durch.

Die Suite wurde durch Wiedereinbau aller bekannten Regressionen geprüft.
Wer sie ändert, sollte das wiederholen.

### Vor dem Push

`.githooks/pre-push` verlangt grüne Tests, bevor Code auf den Server
geht — der andere Mac holt sich diesen Stand beim nächsten `bier update`
und baut ihn. Ist ein Fall rot, wird der Push abgebrochen.

    pre-push: Code geändert, Tests laufen …
    pre-push: 17 Fälle, alle bestanden.

`install.sh` richtet den Haken ein (`core.hooksPath`). Im Notfall
umgehen: `git push --no-verify`.

## Version

    bier version

    bier 0.10.0
      Commit  a1333cd vom 2026-09-20
      Code    /Users/deinname/bierfile
      Daten   /Users/deinname/bierdaten
      Gerät   mini
      App     0.10.0 (/Applications/BierMenu.app)

`BIER_VERSION` steht an genau einer Stelle, in `bin/bier`.
`app/build.sh` holt sie dort heraus und trägt sie ins App-Bündel ein,
`bier state` meldet sie. Dadurch merkt BierMenu, wenn es selbst älter
ist als das Skript, und bietet im Menü ein Update an. **Bei
Verhaltensänderungen hochzählen** — eine alte App, die nach einer
Installation unbemerkt weiterläuft, ist schon passiert.

## Das Symbol ansehen

`app/preview-icon.swift` schreibt beide Ruhezustände, sechs Einzelbilder
der Animation, einen Streifen mit allen nebeneinander und `pixel.png`:

```sh
swiftc -o /tmp/preview app/Glass.swift app/preview-icon.swift -framework AppKit
/tmp/preview /tmp/glas
open /tmp/glas/pixel.png
```

`pixel.png` zeigt die Zustände in echter Menüleisten-Größe (30×34
Pixel), hart vergrößert. Das ist die Ansicht, nach der das Symbol
entworfen werden muss — groß gerendert sieht jeder Entwurf gut aus.
