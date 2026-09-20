# Hinweise für Claude

Diese Datei liegt im Repo und wandert deshalb zwischen den Macs mit.
Das Gedächtnis unter `~/.claude/` tut das **nicht** — was eine spätere
Sitzung auf dem anderen Gerät wissen muss, gehört hierher.

Der Benutzer arbeitet auf Deutsch. Antworten, Commits, Kommentare und
Ausgaben von `bier` sind durchgehend deutsch.

## Was das Projekt löst

Nach einer Installation vergisst der Benutzer, den Bestand zu erfassen,
und die beiden Macs laufen auseinander. `bier` erfasst, vergleicht und
gleicht ab; BierMenu zeigt den Zustand als Bierglas in der Menüleiste.

## Zwei Repos — Code und Daten

Seit 0.10.0 getrennt:

- **root** ist das Programm (`bin/bier`, `app/`, `test/`).
  Öffentlich, darf jeder klonen.
- **data** sind die Brewfiles. Privat: sie verraten, welche Software auf
  den Macs läuft. Wer das Programm klont, hat dort ohnehin kein
  Schreibrecht.

Beide Pfade stehen in `~/.config/bier/config`. **Alle Git-Befehle, die
`bier` von sich aus absetzt, gehen an `DATA`** — nur `bier update`
fasst daneben auch `ROOT` an (`need_code`, `check_code`).

Kein Rückfall von `DATA` auf `ROOT`: sonst schriebe ein frischer Klon
seinen Bestand ins öffentliche Repo. Leer heißt „noch nicht
eingerichtet", und `need_repo` stolpert mit einer Anleitung darüber.
Einzige Ausnahme ist eine alte Einrichtung, erkennbar an einem
`Brewfiles/` neben dem Programm; dort wird weitergearbeitet, bis
umgezogen ist.

## Das Modell — das Wichtigste

- `Brewfiles/main` ist der **gemeinsame** Bestand, gilt für alle Geräte.
- `Brewfiles/<host>` enthält nur, was ein Mac **zusätzlich** hat.
- Zusammen ergeben beide den Sollstand eines Geräts.
- **Ein Delta kann nur addieren, nie subtrahieren.** Was auf einem Gerät
  ausdrücklich nicht laufen soll, darf nicht in `main` stehen. Das ist
  keine Schwäche, sondern die Regel, an der alles hängt.
- Geschrieben wird `Brewfiles/<host>` von `bier dump`, `main` nur von
  `bier main` und `bier take`.

## Entscheidungen, die schon gefallen sind

Nicht ohne neuen Grund umkippen — jede hat eine Geschichte:

- **Keine gespeicherten Diffs.** Das Brewfile-Format kennt kein „minus",
  ein Diff wäre nicht mehr installierbar, und er änderte still seine
  Bedeutung, sobald `main` wächst. Den Vergleich rechnet `bier` live.
- **`bier dump` entfernt nichts.** Erfasstes, das nicht installiert ist,
  bleibt stehen — sonst verlöre man, was `bier take` vorgemerkt hat.
  Wirklich los wird man etwas nur mit `uninstall`, `prune` oder dem
  Umzug nach `main`.
- **`bier dump` übernimmt nichts, was anderswo gelöscht wurde.** Sonst
  zementiert ein Dump auf dem zweiten Mac die verlorene Löschung als
  gerätespezifische Installation. `--adopt` holt es bewusst herein.
- **Die Menüleiste zeigt nichts über andere Geräte.** Weder Liste noch
  Zahl. Es sagt nichts darüber, ob auf *diesem* Mac etwas zu tun ist,
  und skaliert nicht. Dafür ist `bier list` im Terminal.
- **`bier update` fragt nichts** und löst Konflikte selbst. Niemand soll
  git-Befehle kennen müssen, um seine Macs abzugleichen.
- **`publish` fasst nur `Brewfiles/` an.** `git add -A` hat einmal eine
  Quelltext-Änderung unter einer Bestandsmeldung versteckt.
- **`bier adopt` und `bier pull` wurden absichtlich entfernt.** `adopt`
  installierte, ohne zu erfassen; `pull` war redundant, weil `publish`
  vor jedem Push ohnehin holt.

## Fallen, in die ich schon getreten bin

Alle sind durch Tests abgedeckt — wer sie wieder einbaut, wird gefangen.

- `trap ... RETURN` je Funktion bleibt aktiv und feuert erneut, wenn die
  **aufrufende** Funktion zurückkehrt. Die lokale Variable ist dann weg
  und `set -u` bricht ab. Deshalb ein Temp-Verzeichnis für den ganzen
  Lauf, angelegt beim Start, nicht faul in einer Funktion: `$(tmpfile)`
  liefe in einer Subshell, die Zuweisung verpuffte dort.
- `entries` ohne `|| true` liefert bei einer Datei ohne Einträge Exit 1
  und reißt mit `pipefail` jede Zuweisung mit. `bier` stirbt wortlos.
- `kind_of` muss **erst exakt** in den Brewfiles suchen, **dann**
  Homebrew fragen, **Taps zuletzt**: der Kurzname `sikarugir` passt auf
  den Tap `sikarugir-app/sikarugir` *und* auf den Cask darin.
- `was_tracked` darf nur dann „anderswo gelöscht" melden, wenn der
  Eintrag in **keinem** Brewfile mehr steht. Sonst gilt ein Paket, das
  man sich vom anderen Mac abschaut, als Löschung.
- `delta` braucht `[ -f "$1" ]`, sonst klagt `grep` beim allerersten
  Dump auf einem frischen Mac.
- Langsame Ausgabe in eine Pipe (`bier list | head`) erzeugt „Broken
  Pipe". Deshalb wird die Übersicht gesammelt und in einem Stück
  ausgegeben.
- `prune` muss Taps **zuletzt** entfernen: `brew untap` verweigert sich,
  solange ein Cask aus dem Tap installiert ist.
- `install.sh` darf nach dem Beenden der App nicht eine Sekunde raten,
  sondern muss warten — sonst findet `open` die alte Instanz am Leben
  und aktiviert sie bloß, und der alte Code läuft weiter.
- `bier update` überschreibt mit dem Pull das laufende Skript. Bash
  liest stückweise nach. Deshalb übergibt `update` **vor** dem Pull an
  einen neuen Prozess, dessen Befehle im Speicher stehen.
- Beim Umbau auf zwei Repos ist `cmd_push` mit der Funktion daneben
  verschwunden, die Zeile in der Befehlstabelle blieb stehen. Kein Test
  hat es gemerkt, weil `010-alle-befehle` nur die lesenden Befehle
  durchging. Jetzt stehen `push` und `sync` mit in der Schleife.
- Verschiebt man das Repo, zeigen `root` in der Config **und** die
  Verknüpfung `~/.local/bin/bier` weiter auf den alten Pfad. `bier` ist
  dann kommentarlos weg (`command not found`). Beides nachziehen oder
  `install.sh` nochmal laufen lassen.

## Tests

    test/run              alle Fälle
    test/run take -v      gefiltert, mit Ausgabe

Kern ist ein **Homebrew-Doppelgänger** (`test/stubs/brew`), der den
Systemzustand aus einer Datei liest. Dadurch sind die Tests
deterministisch und können Zustände herstellen, die auf einem echten Mac
destruktiv wären.

Regeln für neue Fälle:

- `bier` läuft **nicht** in einer Subshell; die Ausgabe steht in `$OUT`.
  In `out=$(bier …)` gingen Fehlermarken verloren, der Fall liefe grün
  durch.
- Antworten auf Rückfragen kommen aus `answer j`.
- Jede Ausgabe wird automatisch auf Shell-Klagen geprüft
  (`assert_sane`). Ein Fehler mit Exit-Code 0 wäre sonst unsichtbar —
  genau so ist mir einer durchgerutscht.
- **Fixtures müssen die Form des echten Fehlers nachbilden.** Ein Tap
  namens `sik-app/sik` statt `sikarugir-app/sikarugir` hat die
  Mehrdeutigkeit nicht reproduziert, und der Test ging grün durch.

Die Suite wurde durch Wiedereinbau aller bekannten Regressionen geprüft.
Wer sie ändert, sollte das wiederholen.

Die Testwelt bildet die Trennung nach: `$WORK/code.git` und
`$WORK/data.git`, je Mac eine Arbeitskopie von beiden. Die
`merge=union`-Regel kommt aus `.gitattributes` — derselben Datei, die
`install.sh` ins Daten-Repo legt. Sie liegt weiterhin im Programm-Repo,
wo sie nichts tut, damit es sie nur einmal gibt.

`.githooks/pre-push` hängt nur im Programm-Repo und verlangt bei Code
grüne Tests. `install.sh` richtet den Haken ein.

## Version

`BIER_VERSION` steht an genau einer Stelle in `bin/bier`. `app/build.sh`
holt sie dort heraus, `bier state` meldet sie, BierMenu vergleicht sie
mit der eigenen und bietet ein Update an. **Bei Verhaltensänderungen
hochzählen** — sonst merkt niemand, dass eine alte App weiterläuft.

## Arbeitsweise, die sich bewährt hat

- Erst prüfen, dann behaupten. Mehrere Fehler sind nur aufgefallen, weil
  ich die Ausgabe nachgemessen statt überflogen habe.
- Bei Entwurfsfragen nachfragen statt raten — der Benutzer hat das
  ausdrücklich so gewollt.
- Commits begründen ausführlich das *Warum*, nicht das *Was*, und enden
  mit `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`.
