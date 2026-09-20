// BierMenu — Bierglas in der Menüleiste.
//
// Volles Glas: System und Brewfile sind sich einig. Leeres Glas:
// irgendwas weicht ab. Klick zeigt was, und bietet an, es aufzulösen.
//
// Es geht hier ausschließlich um diesen Mac. Was auf anderen Geräten
// mehr oder weniger installiert ist, steht bewusst nicht im Menü —
// das gehört ins Terminal ("bier list") und sagt nichts darüber, ob
// hier etwas zu tun ist.
//
// Die App rechnet nichts selbst — sie ruft "bier state" auf und stellt
// dessen Ausgabe dar.

import AppKit
import ServiceManagement

// MARK: - Zustand

struct BierState {
	var ok = false
	var host = ""
	var fresh: [String] = [] // hier installiert, noch nicht erfasst
	var stale: [String] = [] // anderswo gelöscht, hier noch installiert
	var gone: [String] = [] // erfasst, aber hier nicht installiert
	var version = "" // Version des Skripts, für den Veraltet-Hinweis
	var repo = "" // Pfad zum Repo, fürs Info-Menü
	var commit = "" // Kurz-Hash und Datum, fürs Info-Menü
	var ahead = 0
	var behind = 0
	var dirty = false
	var error: String?

	var hasAnything: Bool {
		!fresh.isEmpty || !stale.isEmpty || !gone.isEmpty
			|| ahead > 0 || behind > 0 || dirty
	}
}

// MARK: - bier aufrufen

enum Bier {
	/// GUI-Programme erben den PATH der Shell nicht. Homebrew und die
	/// Command Line Tools müssen deshalb explizit dazu.
	static let path = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

	/// Sucht das bier-Skript: erst über root aus der Config, dann im PATH.
	static func executable() -> String? {
		let config = ("~/.config/bier/config" as NSString).expandingTildeInPath
		if let text = try? String(contentsOfFile: config, encoding: .utf8) {
			for line in text.split(separator: "\n") {
				let parts = line.split(separator: "=", maxSplits: 1)
				guard parts.count == 2, parts[0].trimmed == "root" else { continue }
				var root = parts[1].trimmed
				if root.hasPrefix("~/") {
					root = (root as NSString).expandingTildeInPath
				}
				let candidate = root + "/bin/bier"
				if FileManager.default.isExecutableFile(atPath: candidate) {
					return candidate
				}
			}
		}
		for dir in path.split(separator: ":") {
			let candidate = "\(dir)/bier"
			if FileManager.default.isExecutableFile(atPath: candidate) {
				return candidate
			}
		}
		return nil
	}

	/// Führt bier aus und liefert (Ausgabe, Fehlertext, Erfolg).
	@discardableResult
	static func run(_ args: [String]) -> (out: String, err: String, ok: Bool) {
		guard let exe = executable() else {
			return ("", "bier nicht gefunden — liegt das Repo noch unter dem Pfad "
				+ "aus ~/.config/bier/config?", false)
		}
		let task = Process()
		task.executableURL = URL(fileURLWithPath: exe)
		task.arguments = args
		var env = ProcessInfo.processInfo.environment
		env["PATH"] = path
		env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
		task.environment = env

		let outPipe = Pipe(), errPipe = Pipe()
		task.standardOutput = outPipe
		task.standardError = errPipe
		do {
			try task.run()
		} catch {
			return ("", "bier ließ sich nicht starten: \(error.localizedDescription)", false)
		}
		let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
		let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
		task.waitUntilExit()
		return (out, err, task.terminationStatus == 0)
	}

	/// Liest den Zustand. Die Zeilen sind tab-getrennt, siehe "bier state".
	static func state(fetch: Bool) -> BierState {
		var s = BierState()
		let r = run(fetch ? ["state", "--fetch"] : ["state"])
		guard r.ok else {
			s.error = r.err.trimmed.isEmpty ? "bier state schlug fehl" : r.err.trimmed
			return s
		}
		for line in r.out.split(separator: "\n") {
			let f = line.split(separator: "\t").map(String.init)
			guard let tag = f.first else { continue }
			switch tag {
			case "STATE": s.ok = f.count > 1 && f[1] == "ok"
			case "HOST": if f.count > 1 { s.host = f[1] }
			case "VERSION": if f.count > 1 { s.version = f[1] }
			case "REPO": if f.count > 1 { s.repo = f[1] }
			case "COMMIT":
				if f.count > 2 { s.commit = "\(f[1]) vom \(f[2])" }
			case "NEW": if f.count > 1 { s.fresh.append(f[1]) }
			case "STALE": if f.count > 1 { s.stale.append(f[1]) }
			case "GONE": if f.count > 1 { s.gone.append(f[1]) }
			case "GIT":
				if f.count > 3 {
					s.ahead = Int(f[1]) ?? 0
					s.behind = Int(f[2]) ?? 0
					s.dirty = f[3] == "1"
				}
			default: break
			}
		}
		return s
	}

	/// Lange Läufe, die nachfragen können, gehören ins Terminal — nicht
	/// stumm in eine Menüleisten-App.
	static func runInTerminal(_ args: [String]) {
		guard let exe = executable() else { return }
		let command = ([exe] + args).map { "'\($0)'" }.joined(separator: " ")
		let script = "tell application \"Terminal\"\n"
			+ "activate\n"
			+ "do script \"\(command)\"\n"
			+ "end tell"
		if let apple = NSAppleScript(source: script) {
			var err: NSDictionary?
			apple.executeAndReturnError(&err)
		}
	}
}

extension StringProtocol {
	var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

// MARK: - App

class Controller: NSObject, NSMenuDelegate {
	var statusItem: NSStatusItem!
	var state = BierState()
	var lastCheck: Date?
	var checking = false
	var timer: Timer?
	private var busyCount = 0
	private var animation: Timer?
	private var phase: CGFloat = 0

	let full = Glass.image(full: true)
	let empty = Glass.image(full: false)

	func start() {
		statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
		statusItem.button?.image = full
		let menu = NSMenu()
		menu.delegate = self
		statusItem.menu = menu

		refresh(fetch: false)
		// Alle 15 Minuten nachsehen, plus bei jedem Öffnen des Menüs.
		let t = Timer(timeInterval: 900, repeats: true) { [weak self] _ in
			self?.refresh(fetch: true)
		}
		RunLoop.main.add(t, forMode: .common)
		timer = t
	}

	func refresh(fetch: Bool) {
		if checking { return }
		checking = true
		beginBusy()
		DispatchQueue.global(qos: .utility).async { [weak self] in
			let s = Bier.state(fetch: fetch)
			DispatchQueue.main.async {
				guard let self else { return }
				self.state = s
				self.lastCheck = Date()
				self.checking = false
				self.statusItem.button?.toolTip = s.error ?? (s.ok
					? "Alles abgeglichen"
					: "Es gibt Abweichungen")
				self.endBusy()
				self.build(self.statusItem.menu!)
			}
		}
	}

	// MARK: Schaum, solange etwas läuft

	/// Mehrere Läufe können sich überlappen, deshalb gezählt statt
	/// geschaltet — der Schaum hört erst auf, wenn der letzte fertig ist.
	private func beginBusy() {
		busyCount += 1
		guard animation == nil else { return }
		let t = Timer(timeInterval: 1.0 / 12.0, repeats: true) { [weak self] _ in
			guard let self else { return }
			phase += 0.055
			statusItem.button?.image = Glass.busy(phase: phase)
		}
		// .common, damit die Blasen auch bei offenem Menü weitersteigen.
		RunLoop.main.add(t, forMode: .common)
		animation = t
	}

	private func endBusy() {
		busyCount = max(0, busyCount - 1)
		guard busyCount == 0 else { return }
		animation?.invalidate()
		animation = nil
		showStateIcon()
	}

	private func showStateIcon() {
		statusItem.button?.image = (state.ok && state.error == nil) ? full : empty
	}

	// MARK: Menü

	func menuWillOpen(_ menu: NSMenu) {
		build(menu)
		refresh(fetch: true) // baut sich nach, sobald die Antwort da ist
	}

	private func header(_ title: String) -> NSMenuItem {
		let i = NSMenuItem(title: title, action: nil, keyEquivalent: "")
		i.isEnabled = false
		return i
	}

	private func detail(_ text: String) -> NSMenuItem {
		let i = NSMenuItem(title: "    " + text, action: nil, keyEquivalent: "")
		i.isEnabled = false
		i.attributedTitle = NSAttributedString(
			string: "    " + text,
			attributes: [
				.font: NSFont.menuFont(ofSize: NSFont.smallSystemFontSize),
				.foregroundColor: NSColor.secondaryLabelColor,
			]
		)
		return i
	}

	private func action(_ title: String, _ selector: Selector, _ tag: String = "") -> NSMenuItem {
		let i = NSMenuItem(title: title, action: selector, keyEquivalent: "")
		i.target = self
		i.representedObject = tag
		return i
	}

	/// Höchstens ein paar Einträge zeigen, der Rest wird gezählt.
	private func listing(_ items: [String], into menu: NSMenu, limit: Int = 8) {
		for entry in items.prefix(limit) {
			menu.addItem(detail(readable(entry)))
		}
		if items.count > limit {
			menu.addItem(detail("und \(items.count - limit) weitere"))
		}
	}

	/// 'brew "htop"' liest sich in einem Menü besser als 'htop (Formel)'.
	private func readable(_ entry: String) -> String {
		let parts = entry.split(separator: " ", maxSplits: 1).map(String.init)
		guard parts.count == 2 else { return entry }
		let name = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
		let kind: String
		switch parts[0] {
		case "brew": kind = "Formel"
		case "cask": kind = "App"
		case "mas": kind = "App Store"
		case "vscode": kind = "VS Code"
		case "tap": kind = "Tap"
		default: kind = parts[0]
		}
		return "\(name)  (\(kind))"
	}

	func build(_ menu: NSMenu) {
		menu.removeAllItems()

		if let error = state.error {
			menu.addItem(header("Fehler"))
			menu.addItem(detail(error))
			menu.addItem(.separator())
			addFooter(menu)
			return
		}

		if state.ok {
			menu.addItem(header("Alles abgeglichen"))
		} else {
			// Hier installiert, noch nicht erfasst: schnell und ungefährlich.
			if !state.fresh.isEmpty {
				menu.addItem(header("\(state.fresh.count) installiert, aber nicht erfasst"))
				listing(state.fresh, into: menu)
				menu.addItem(action("Einschenken: erfassen und pushen",
				                    #selector(doSync)))
				menu.addItem(.separator())
			}

			// Auf einem anderen Mac gelöscht. Das entfernt Software,
			// gehört also ins Terminal und nicht hinter einen Klick.
			if !state.stale.isEmpty {
				menu.addItem(header("\(state.stale.count) anderswo gelöscht, hier noch da"))
				listing(state.stale, into: menu)
				menu.addItem(action("Entfernen … (im Terminal)",
				                    #selector(doPrune)))
				menu.addItem(.separator())
			}

			// Erfasst, aber nicht installiert.
			if !state.gone.isEmpty {
				menu.addItem(header("\(state.gone.count) erfasst, aber nicht installiert"))
				listing(state.gone, into: menu)
				menu.addItem(action("Nachinstallieren … (im Terminal)",
				                    #selector(doInstall)))
				menu.addItem(.separator())
			}

			// Git hängt.
			if state.dirty {
				menu.addItem(header("Änderungen sind nicht committet"))
				menu.addItem(action("Einschenken: erfassen und pushen",
				                    #selector(doSync)))
				menu.addItem(.separator())
			}
			if state.behind > 0 {
				menu.addItem(header("origin ist \(state.behind) Commits voraus"))
				menu.addItem(action("Holen (git pull)", #selector(doPull)))
				menu.addItem(.separator())
			}
			if state.ahead > 0, !state.dirty {
				menu.addItem(header("\(state.ahead) Commits nicht gepusht"))
				menu.addItem(action("Pushen", #selector(doPush)))
				menu.addItem(.separator())
			}
		}

		addFooter(menu)
	}

	/// Was diese App beim Bauen als Version eingetragen bekam.
	private var ownVersion: String {
		Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
	}

	/// Läuft hier noch eine alte App, während das Skript schon weiter
	/// ist? Das ist genau dann passiert, wenn eine Installation die
	/// laufende Fassung nicht ersetzt hat — und es fällt sonst nicht auf.
	private func addVersionHint(_ menu: NSMenu) {
		guard !state.version.isEmpty, state.version != ownVersion else { return }
		menu.addItem(.separator())
		menu.addItem(header("Diese App ist \(ownVersion), bier ist \(state.version)"))
		menu.addItem(action("Aktualisieren … (im Terminal)", #selector(doUpdate)))
	}

	private func addFooter(_ menu: NSMenu) {
		addVersionHint(menu)
		if !menu.items.isEmpty, !(menu.items.last?.isSeparatorItem ?? false) {
			menu.addItem(.separator())
		}

		menu.addItem(action("Jetzt prüfen", #selector(doCheck)))

		let login = NSMenuItem(title: "Beim Anmelden starten",
		                       action: #selector(toggleLogin), keyEquivalent: "")
		login.target = self
		login.state = SMAppService.mainApp.status == .enabled ? .on : .off
		menu.addItem(login)

		addInfo(menu)

		// Wann zuletzt nachgesehen wurde, gehört unter die Handlungen —
		// oben nimmt es die Stelle ein, an der man eine erwartet.
		if checking {
			menu.addItem(detail("prüfe …"))
		} else if let last = lastCheck {
			let f = DateFormatter()
			f.dateFormat = "HH:mm"
			menu.addItem(detail("zuletzt geprüft \(f.string(from: last))"
					+ (state.host.isEmpty ? "" : " · \(state.host)")))
		}

		// Beenden abgesetzt, wie auf macOS üblich.
		menu.addItem(.separator())
		menu.addItem(action("Beenden", #selector(doQuit)))
	}

	/// Herkunft und Doku. Als Untermenü, damit das Hauptmenü kurz bleibt.
	private func addInfo(_ menu: NSMenu) {
		let item = NSMenuItem(title: "Info", action: nil, keyEquivalent: "")
		let sub = NSMenu()

		sub.addItem(detail("bier \(state.version.isEmpty ? "?" : state.version)"
				+ "   ·   App \(ownVersion)"))
		if !state.commit.isEmpty {
			sub.addItem(detail("Commit \(state.commit)"))
		}
		if !state.host.isEmpty {
			sub.addItem(detail("Gerät \(state.host)"))
		}
		if !state.repo.isEmpty {
			sub.addItem(detail(state.repo))
		}

		if !state.repo.isEmpty {
			sub.addItem(.separator())
			sub.addItem(action("Anleitung öffnen", #selector(doDocs)))
			sub.addItem(action("Ordner im Finder zeigen", #selector(doReveal)))
		}

		item.submenu = sub
		menu.addItem(item)
	}

	// MARK: Aktionen

	@objc private func doCheck() { refresh(fetch: true) }

	@objc private func doSync() { runQuietly(["sync"], "Erfassen und pushen") }

	@objc private func doPull() { runQuietly(["state", "--fetch"], "Holen") }

	@objc private func doPush() { runQuietly(["sync"], "Pushen") }

	@objc private func doInstall() { Bier.runInTerminal(["install"]) }

	@objc private func doPrune() { Bier.runInTerminal(["prune"]) }

	@objc private func doUpdate() { Bier.runInTerminal(["update"]) }

	/// ANLEITUNG.md führt Schritt für Schritt, README.md gibt den
	/// Überblick. Fehlt beides, lieber den Ordner zeigen als nichts tun.
	@objc private func doDocs() {
		guard !state.repo.isEmpty else { return }
		let root = URL(fileURLWithPath: state.repo)
		for name in ["ANLEITUNG.md", "README.md"] {
			let file = root.appendingPathComponent(name)
			if FileManager.default.fileExists(atPath: file.path) {
				NSWorkspace.shared.open(file)
				return
			}
		}
		doReveal()
	}

	@objc private func doReveal() {
		guard !state.repo.isEmpty else { return }
		NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: state.repo)
	}

	/// Kurze, ungefährliche Läufe ohne Terminal. Fehler werden gezeigt,
	/// Erfolge nur am wieder vollen Glas erkennbar.
	private func runQuietly(_ args: [String], _ what: String) {
		beginBusy()
		DispatchQueue.global(qos: .userInitiated).async { [weak self] in
			let r = Bier.run(args)
			DispatchQueue.main.async {
				self?.endBusy()
				if !r.ok {
					let alert = NSAlert()
					alert.messageText = "\(what) schlug fehl"
					alert.informativeText = r.err.trimmed.isEmpty ? r.out.trimmed : r.err.trimmed
					alert.alertStyle = .warning
					alert.runModal()
				}
				self?.refresh(fetch: false)
			}
		}
	}

	@objc private func toggleLogin() {
		do {
			if SMAppService.mainApp.status == .enabled {
				try SMAppService.mainApp.unregister()
			} else {
				try SMAppService.mainApp.register()
			}
		} catch {
			let alert = NSAlert()
			alert.messageText = "Start beim Anmelden ließ sich nicht ändern"
			alert.informativeText = error.localizedDescription
			alert.runModal()
		}
	}

	@objc private func doQuit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // kein Dock-Symbol
let controller = Controller()
controller.start()
app.run()
