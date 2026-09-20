# bier

**Hält den Software-Bestand mehrerer Macs deckungsgleich** — mit
Homebrew, einem Git-Repo und einem Bierglas in der Menüleiste.

Du installierst etwas auf dem Schreibtischrechner, vergisst es, und ein
halbes Jahr später fehlt es auf dem Laptop. `bier` schreibt auf, was
installiert ist, legt diese Liste in ein Git-Repo und sagt dir auf jedem
Gerät, was abweicht — **voll** heißt, alles ist im Lot, **leer** heißt,
hier ist etwas zu tun.

Es ist ein Shell-Skript ohne Abhängigkeiten außer Homebrew und Git, dazu
eine kleine Menüleisten-App in Swift. Nichts läuft in der Cloud, nichts
schreibt nach Hause; deine Listen liegen in einem Repo, das dir gehört.

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

## Was es kann

- **Erfassen und abgleichen.** `bier sync` schreibt auf, was auf diesem
  Mac liegt, und schiebt es zu den anderen.
- **Unterschiede zeigen.** Was ist hier installiert, aber nirgends
  vermerkt? Was steht in der Liste, fehlt aber auf diesem Gerät?
- **Unterschiede erlauben.** Nicht alles gehört überall hin. Ein Gerät
  darf Sonderausstattung haben, ohne dass sie den anderen aufgedrängt
  wird.
- **Löschungen übertragen.** Ein reines „was ist installiert"-Abbild
  kann das nicht. `bier` erkennt an der Git-Historie, ob ein Programm
  neu dazukam oder anderswo entfernt wurde — und behandelt beides
  verschieden.
- **Ohne Git-Kenntnisse auskommen.** `bier update` holt, schiebt, führt
  zusammen und baut neu. Es fragt nichts und verlangt nichts.
- **In der Menüleiste sitzen.** Ein Blick genügt, um zu sehen, ob dieser
  Mac abweicht.

## Wie es funktioniert

Zwei Listen im
[Brewfile-Format](https://docs.brew.sh/Brew-Bundle-and-Brewfile) ergeben
zusammen den Sollstand eines Geräts:

    Brewfiles/main       was auf allen Macs laufen soll
    Brewfiles/<host>     was dieser eine Mac zusätzlich hat

Beide sind gültige Brewfiles und lassen sich direkt an
`brew bundle install --file` verfüttern. `main` legst du einmal aus dem
Bestand deines Hauptgeräts an; danach schreibt jeder Mac nur noch seine
eigene Zusatzliste.

Daraus folgt eine Regel, die alles trägt: **eine Gerätedatei kann nur
addieren, nie abziehen.** Was ein Gerät ausdrücklich *nicht* haben soll,
darf also nicht in `main` stehen. Das klingt nach einer Einschränkung,
erspart dir aber eine ganze Klasse von Sonderfällen — und `bier take`
verschiebt Einträge in beide Richtungen, wenn du dich anders entscheidest.

## Voraussetzungen

- macOS mit [Homebrew](https://brew.sh)
- die Command Line Tools (`xcode-select --install`) für die App
- ein **leeres, privates Git-Repo** für deine Listen, erreichbar per
  SSH-Schlüssel von allen Geräten — GitHub, ein NAS oder ein eigener
  Server

Das Repo stellst du auf privat: deine Listen verraten, welche Software
auf deinen Rechnern läuft.

## Installation

Auf dem Mac, dessen Software als Vorlage gelten soll:

```sh
git clone https://github.com/MatthiasToberer/bierfile.git ~/bierfile
~/bierfile/install.sh
```

`install.sh` prüft die Voraussetzungen, macht `bier` aufrufbar, fragt
nach der Adresse deines privaten Repos, baut die Menüleisten-App und
erfasst den Bestand dieses Macs. Die Adresse lässt sich auch mitgeben:

```sh
~/bierfile/install.sh --data git@github.com:deinname/bierdaten.git
```

Dann einmalig den gemeinsamen Sollstand festlegen:

```sh
bier main
```

Auf jedem weiteren Mac dasselbe `git clone` und `install.sh`, aber
**statt** `bier main`:

```sh
bier install    # holt die Software aus main auf dieses Gerät
bier sync       # erfasst, was dieser Mac zusätzlich hat
```

Ausführlich, Schritt für Schritt und ohne Vorkenntnisse:
**[ANLEITUNG.md](ANLEITUNG.md)**.

## Der Alltag

```sh
bier sync              # nach jeder Installation: erfassen und hochladen
bier update            # holen, was auf den anderen Macs passiert ist
bier status            # was weicht hier ab?
bier list              # was haben die anderen zusätzlich?
bier take              # davon etwas übernehmen
bier uninstall ghidra  # überall loswerden
bier prune             # hier entfernen, was anderswo gelöscht wurde
```

Meistens brauchst du nur die ersten beiden.

## Befehle

| Befehl | was er tut |
| --- | --- |
| `bier dump [--adopt]` | erfassen, was dieser Mac zusätzlich zu `main` hat |
| `bier sync [nachricht]` | `dump`, committen, hochladen — der Alltagsbefehl |
| `bier update [--force]` | alles abgleichen und bei Bedarf neu bauen |
| `bier status` | System gegen die Listen prüfen |
| `bier list` | Übersicht über alle Geräte |
| `bier diff [host…]` | Bestand mit anderen Geräten vergleichen |
| `bier install` | `main` und die eigene Liste aufs System holen |
| `bier take` | Einträge anderer Geräte nach `main` oder hierher |
| `bier take --from-main` | einen Eintrag aus `main` einem Gerät zuschlagen |
| `bier main` | `main` aus diesem Mac anlegen — einmal im Leben |
| `bier uninstall <paket>` | deinstallieren und aus allen Listen nehmen |
| `bier prune` | entfernen, was auf einem anderen Mac gelöscht wurde |
| `bier push [nachricht]` | Listen committen und hochladen |
| `bier config` | zeigt, welche Einstellungen gelten |
| `bier version` | Version, Commit und Pfade |
| `bier help` | dieselbe Übersicht im Terminal |

## Etwas übernehmen

`bier list` zeigt, was die anderen Geräte zusätzlich haben. `bier take`
lässt dich auswählen und fragt, wohin:

```
Was andere Geräte zusätzlich zu main haben:

   1  cask "font-meslo-lg-nerd-font"               macbook
   2  mas "WireGuard"                              macbook

Nummern (z.B. 1 3-5), leer = abbrechen: 1
Wohin?  [m] nach main, gilt für alle   [h] nur mini   [a] abbrechen: m
```

- **nach `main`** — gilt ab jetzt für alle Geräte und verschwindet
  deshalb aus den Gerätelisten. Doppelt wäre falsch.
- **nur dieser Mac** — kommt in die eigene Liste, die anderen behalten
  ihre. Beide haben es dann gerätespezifisch.

Die Gegenrichtung, `bier take --from-main`, holt einen Eintrag aus dem
gemeinsamen Bestand heraus und schlägt ihn einem einzelnen Gerät zu. So
wird aus „läuft überall" ein „läuft nur hier".

## Löschen

Ein Abbild des Systems kann Löschungen nicht übertragen — es sieht nur,
was da ist. Deshalb ist Löschen ein eigener Befehl:

```sh
bier uninstall ghidra
```

Das deinstalliert, nimmt den Eintrag aus allen Listen und lädt hoch. Auf
dem anderen Mac ist ghidra danach noch installiert, steht aber in keiner
Liste mehr — derselbe Zustand wie bei einem frisch installierten Paket.

Unterscheiden lässt sich das trotzdem, denn **die Git-Historie weiß es**:
stand ein Eintrag früher in einer Liste und ist jetzt weg, war es eine
Löschung; stand er nie dort, ist er neu. `bier status` trennt beides:

```
Auf mini installiert, aber nicht erfasst (bier dump):
  + brew "htop"
Auf einem anderen Gerät gelöscht, hier noch da (bier prune):
  ~ brew "ghidra"
```

`bier prune` räumt die zweite Sorte weg, nach Rückfrage.

## Die Menüleiste

**BierMenu** zeigt den Zustand dieses Macs, ohne dass du fragen musst:

- **voller Krug mit Schaumkrone** — System und Listen sind sich einig
- **leerer Krug** — hier weicht etwas ab
- **Füllstand bewegt sich** — die App sieht gerade nach

Ein Klick zeigt, was abweicht, nach Art getrennt: *nicht erfasst* wird
mit einem Klick im Hintergrund erledigt, *deinstallieren* und
*nachinstallieren* öffnen ein Terminal — das dauert, fragt nach dem
Passwort und kann schiefgehen, also sollst du zusehen können.

Was **andere** Geräte mehr oder weniger haben, steht dort bewusst nicht.
Es sagt nichts darüber, ob auf *diesem* Mac etwas zu tun ist. Dafür gibt
es `bier list`.

Die App rechnet nichts selbst; sie ruft `bier state` auf, alle 15
Minuten und bei jedem Öffnen des Menüs.

## Wenn zwei Macs gleichzeitig etwas ändern

Listen von Paketen haben keine Reihenfolge, und fast immer sind *beide*
Seiten richtig. `bier` setzt deshalb `merge=union` für die Listen: Git
führt gleichzeitige Änderungen selbst zusammen, statt einen Konflikt zu
hinterlassen. Bleibt doch einer stehen, löst `bier update` ihn nach
derselben Regel auf — beide Seiten behalten, weiter. Doppelte Zeilen
stören Homebrew nicht und verschwinden beim nächsten `bier sync`.

Geht es wirklich nicht, bricht `bier` ab und nimmt alles zurück, statt
etwas halb fertig liegen zu lassen.

## Wo was liegt

Deine Listen liegen in *deinem* privaten Repo, nicht in diesem hier —
sie gehen niemanden etwas an, und Schreibrecht hättest du hier ohnehin
nicht. `install.sh` richtet beides ein und hält die Pfade in
`~/.config/bier/config` fest:

    root = /Users/deinname/bierfile     # dieses Programm
    data = /Users/deinname/bierdaten    # deine Listen
    host = mini                         # wie dieses Gerät heißt

`bier config` zeigt, was gerade gilt.

## Weiterlesen

- **[ANLEITUNG.md](ANLEITUNG.md)** — Einrichtung und Alltag Schritt für
  Schritt, mit Beispielen für zwei und drei Macs. Setzt nichts voraus.
- **[ENTWICKLUNG.md](ENTWICKLUNG.md)** — wie es gebaut ist, welche
  Entwurfsentscheidungen warum gefallen sind, und wie die Tests
  funktionieren.
