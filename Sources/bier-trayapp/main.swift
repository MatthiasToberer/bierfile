// BierMenu — a beer glass in the menu bar.
//
// Full glass: nothing to do. Empty glass: something arrived from another
// Mac, or something is wrong. The menu says which, and "Sync now" runs
// bier sync without a terminal. Everything else -- what waits to go out,
// what is installed but not listed -- is for "bier status".
//
// The app computes nothing itself — it calls "bier state" and renders
// its output. That check reads nobody's settings, so it needs no
// permission beyond bier's own folder.

import AppKit
import ServiceManagement

// MARK: - State

struct BierState {
	var ok = false
	var host = ""
	var group = ""
	var install: [String] = [] // arrived: on this Mac's lists, not installed
	var remove: [String] = [] // arrived: removed elsewhere or out of main
	var settings: [String] = [] // arrived: settings from another Mac
	var conflicts: [String] = [] // wrong: .from-safe copies to merge
	var pending: [String] = [] // Macs introduced by a peer, to accept
	var version = "" // the script's version, for the out-of-date hint
	var release = "" // a newer release on the code server, empty if none
	var repo = "" // path to the repository, for the info menu
	var commit = "" // short hash and date, for the info menu
	var error: String?
}

// MARK: - Calling bier

enum Bier {
	/// Where the guide lives. Opening a local .md file hands macOS a
	/// file that a Mac with no handler for it ignores — the menu entry
	/// looked broken. The rendered page needs only a browser, and every
	/// Mac has one. GUIDE.md stays as a pointer for older apps.
	static let guideURL = "https://github.com/MatthiasToberer/bierfile/blob/main/docs/README.md"

	/// GUI programs do not inherit the shell's PATH. Homebrew and the
	/// Command Line Tools therefore have to be added explicitly.
	static let path = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

	/// Finds the bier script: the barrel's command, then root from the
	/// config (the barrel's, or the one from before it), then on PATH.
	static func executable() -> String? {
		let command = ("~/.barrel/bin/bier" as NSString).expandingTildeInPath
		if FileManager.default.isExecutableFile(atPath: command) {
			return command
		}
		for path in ["~/.barrel/config", "~/.config/bier/config"] {
			let config = (path as NSString).expandingTildeInPath
			guard let text = try? String(contentsOfFile: config, encoding: .utf8) else { continue }
			for line in text.split(separator: "\n") {
				let parts = line.split(separator: "=", maxSplits: 1)
				guard parts.count == 2, parts[0].trimmed == "root" else { continue }
				var root = parts[1].trimmed
				if root.hasPrefix("~/") {
					root = (root as NSString).expandingTildeInPath
				}
				let candidate = root + "/Sources/bier-core/bier"
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

	/// Nothing here may block for ever. git can sit on an unreachable
	/// server, and "brew bundle dump" calls mas, which hangs when the
	/// App Store is away -- and the menu bar would foam until the next
	/// login, because the run it is waiting for never comes back.
	static let runLimit: TimeInterval = 45

	/// Runs bier and returns (output, error text, success).
	@discardableResult
	static func run(_ args: [String], limit: TimeInterval = runLimit) -> (out: String, err: String, ok: Bool) {
		guard let exe = executable() else {
			return ("", "bier not found — is ~/.barrel still there?", false)
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
			return ("", "bier could not be started: \(error.localizedDescription)", false)
		}

		var timedOut = false
		let watchdog = DispatchWorkItem {
			if task.isRunning {
				timedOut = true
				task.terminate()
			}
		}
		DispatchQueue.global().asyncAfter(deadline: .now() + limit, execute: watchdog)
		defer { watchdog.cancel() }
		let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
		let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
		task.waitUntilExit()
		if timedOut {
			return ("", "bier did not answer within \(Int(limit)) seconds "
				+ "— is a server or the App Store unreachable?", false)
		}
		task.waitUntilExit()
		return (out, err, task.terminationStatus == 0)
	}

	/// Reads the state. The lines are tab-separated, see "bier state".
	static func state(fetch: Bool) -> BierState {
		var s = BierState()
		let r = run(fetch ? ["state", "--fetch"] : ["state"])
		guard r.ok else {
			s.error = r.err.trimmed.isEmpty ? "bier state failed" : r.err.trimmed
			return s
		}
		for line in r.out.split(separator: "\n") {
			let f = line.split(separator: "\t").map(String.init)
			guard let tag = f.first, f.count > 1 else { continue }
			switch tag {
			case "STATE": s.ok = f[1] == "ok"
			case "HOST": s.host = f[1]
			case "MYGROUP": s.group = f[1]
			case "VERSION": s.version = f[1]
			case "NEWCODE": s.release = f[1]
			case "REPO": s.repo = f[1]
			case "COMMIT": if f.count > 2 { s.commit = "\(f[1]) of \(f[2])" }
			case "GONE": s.install.append(f[1])
			case "STALE", "DROPPED": s.remove.append(f[1])
			case "VAULT_IN": s.settings.append(f[1])
			case "VAULT_LEFT": s.conflicts.append(f[1])
			case "PENDING": s.pending.append(f[1])
			default: break
			}
		}
		return s
	}

	/// Long runs that may ask questions belong in the terminal — not
	/// silently inside a menu bar app.
	static func runInTerminal(_ args: [String]) {
		guard let exe = executable() else { return }
		// Two layers of quoting, and both have to hold. The shell sees
		// single quotes, so an embedded ' has to close and reopen them;
		// AppleScript sees a string literal, so a backslash or a quote
		// has to be escaped again — backslash first, or the escapes
		// would escape each other. A path from the config file with a
		// quote in it would otherwise end the command early.
		let shell = ([exe] + args)
			.map { "'" + $0.replacingOccurrences(of: "'", with: "'\\''") + "'" }
			.joined(separator: " ")
		let command = shell
			.replacingOccurrences(of: "\\", with: "\\\\")
			.replacingOccurrences(of: "\"", with: "\\\"")
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
		// Check every 15 minutes, plus whenever the menu opens.
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
				self.statusItem.button?.toolTip = s.error ?? (self.isOk
					? "Everything in sync"
					: "Something to look at")
				self.endBusy()
				self.build(self.statusItem.menu!)
			}
		}
	}

	/// What the last "Sync now" ran into, until the next one succeeds.
	var syncTrouble: [String] = []

	var isOk: Bool { state.ok && state.error == nil && syncTrouble.isEmpty }

	// MARK: Foam while something is running

	/// Several runs can overlap, so counted rather than toggled — the
	/// foam only settles once the last one has finished.
	private func beginBusy() {
		busyCount += 1
		guard animation == nil else { return }
		let t = Timer(timeInterval: 1.0 / 12.0, repeats: true) { [weak self] _ in
			guard let self else { return }
			phase += 0.055
			statusItem.button?.image = Glass.busy(phase: phase)
		}
		// .common so the bubbles keep rising while the menu is open.
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
		statusItem.button?.image = isOk ? full : empty
	}

	// MARK: Menu

	func menuWillOpen(_ menu: NSMenu) {
		build(menu)
		refresh(fetch: true) // rebuilds itself once the answer arrives
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

	/// Show a handful of entries at most, the rest is counted.
	private func listing(_ items: [String], into menu: NSMenu, limit: Int = 8) {
		for entry in items.prefix(limit) {
			menu.addItem(detail(readable(entry)))
		}
		if items.count > limit {
			menu.addItem(detail("and \(items.count - limit) more"))
		}
	}

	/// 'brew "htop"' reads better in a menu as 'htop (formula)'.
	private func readable(_ entry: String) -> String {
		let parts = entry.split(separator: " ", maxSplits: 1).map(String.init)
		guard parts.count == 2 else { return entry }
		let name = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
		let kind: String
		switch parts[0] {
		case "brew": kind = "formula"
		case "cask": kind = "app"
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
			menu.addItem(header("Error"))
			menu.addItem(detail(error))
			menu.addItem(.separator())
		} else if isOk {
			menu.addItem(header("Everything in sync"))
			menu.addItem(.separator())
		}

		// Something is wrong: what the last sync ran into, and conflicts.
		if !syncTrouble.isEmpty || !state.conflicts.isEmpty || !state.pending.isEmpty {
			menu.addItem(header("Something needs you"))
			let waiting = state.pending.map { "\($0) waits: bier peer accept \($0)" }
			for line in (syncTrouble + state.conflicts.map { "merge, then delete: \($0)" } + waiting).prefix(6) {
				menu.addItem(detail(short(line)))
			}
			if syncTrouble.contains(where: { $0.contains("no access") }) {
				menu.addItem(action("Allow access … (Full Disk Access)", #selector(doAccess)))
			}
			menu.addItem(.separator())
		}

		// Something arrived from another Mac.
		if !state.settings.isEmpty {
			menu.addItem(header("\(state.settings.count) settings from another Mac"))
			for line in state.settings.prefix(4) { menu.addItem(detail(short(line))) }
			menu.addItem(.separator())
		}
		if !state.install.isEmpty {
			menu.addItem(header("\(state.install.count) to install"))
			listing(state.install, into: menu, limit: 4)
			menu.addItem(action("Install … (in Terminal)", #selector(doInstall)))
			menu.addItem(.separator())
		}
		if !state.remove.isEmpty {
			menu.addItem(header("\(state.remove.count) removed on another Mac"))
			listing(state.remove, into: menu, limit: 4)
			menu.addItem(action("Remove … (in Terminal)", #selector(doPrune)))
			menu.addItem(.separator())
		}

		menu.addItem(action("Sync now", #selector(doSync)))
		addFooter(menu)
	}

	private func short(_ path: String) -> String {
		path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
	}

	/// The version this app was stamped with when it was built.
	private var ownVersion: String {
		Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
	}

	/// Is an old app still running while the script has moved on? That
	/// happens exactly when an install failed to replace the running
	/// build — and it would otherwise go unnoticed.
	private func addVersionHint(_ menu: NSMenu) {
		// A release waiting on the server is the hint worth showing first:
		// nobody would otherwise learn that it exists.
		if !state.release.isEmpty {
			menu.addItem(.separator())
			menu.addItem(header("bier \(state.release) is out — this is \(state.version)"))
			menu.addItem(action("Upgrade … (in Terminal)", #selector(doUpgrade)))
			return
		}
		guard !state.version.isEmpty, state.version != ownVersion else { return }
		menu.addItem(.separator())
		menu.addItem(header("This app is \(ownVersion), bier is \(state.version)"))
		menu.addItem(action("Upgrade … (in Terminal)", #selector(doUpgrade)))
	}

	private func addFooter(_ menu: NSMenu) {
		addVersionHint(menu)
		if !menu.items.isEmpty, !(menu.items.last?.isSeparatorItem ?? false) {
			menu.addItem(.separator())
		}


		// Pairing without a terminal: the one-time code, shown here.
		let connect = NSMenuItem(title: "Connect", action: nil, keyEquivalent: "")
		let connectMenu = NSMenu()
		connectMenu.addItem(action("Let a Mac Join …", #selector(doJoin)))
		connectMenu.addItem(action("Connect Bierkasten …", #selector(doConnectApp)))
		connect.submenu = connectMenu
		menu.addItem(connect)

		let login = NSMenuItem(title: "Start at login",
		                       action: #selector(toggleLogin), keyEquivalent: "")
		login.target = self
		login.state = SMAppService.mainApp.status == .enabled ? .on : .off
		menu.addItem(login)

		addInfo(menu)

		// When we last looked belongs below the actions — at the top it
		// occupies the spot where one expects something to click.
		if checking {
			menu.addItem(detail("checking …"))
		} else if let last = lastCheck {
			let f = DateFormatter()
			f.dateFormat = "HH:mm"
			menu.addItem(detail("last checked \(f.string(from: last))"
					+ (state.host.isEmpty ? "" : " · \(state.host)")
					+ (state.group.isEmpty ? "" : " · group \(state.group)")))
		}

		// Quit set apart, as is customary on macOS.
		menu.addItem(.separator())
		menu.addItem(action("Quit", #selector(doQuit)))
	}

	/// Origin and docs. A submenu, to keep the main menu short.
	private func addInfo(_ menu: NSMenu) {
		let item = NSMenuItem(title: "Info", action: nil, keyEquivalent: "")
		let sub = NSMenu()

		sub.addItem(detail("bier \(state.version.isEmpty ? "?" : state.version)"
				+ "   ·   App \(ownVersion)"))
		if !state.commit.isEmpty {
			sub.addItem(detail("Commit \(state.commit)"))
		}
		if !state.host.isEmpty {
			sub.addItem(detail("Device \(state.host)" + (state.group.isEmpty ? "" : ", group \(state.group)")))
		}
		if !state.repo.isEmpty {
			sub.addItem(detail(state.repo))
		}

		if !state.repo.isEmpty {
			sub.addItem(.separator())
			sub.addItem(action("Open the guide", #selector(doDocs)))
			sub.addItem(action("Show folder in Finder", #selector(doReveal)))
		}

		item.submenu = sub
		menu.addItem(item)
	}

	// MARK: Actions

	/// bier sync, without a terminal. Installing and removing software
	/// stay in the terminal: they take long, may ask for a password,
	/// and are worth watching.
	@objc private func doSync() {
		beginBusy()
		DispatchQueue.global(qos: .userInitiated).async { [weak self] in
			let r = Bier.run(["sync"], limit: 600)
			let said = (r.out + "\n" + r.err).split(separator: "\n").map { $0.trimmed }
			var trouble = said.filter {
				$0.hasPrefix("no access:") || $0.hasPrefix("changed here and on another Mac:")
					|| $0.hasPrefix("waiting:")
			}
			if !r.ok {
				trouble.insert("sync failed: " + (said.last(where: { $0.hasPrefix("bier:") }) ?? "see bier sync"), at: 0)
			}
			DispatchQueue.main.async {
				guard let self else { return }
				self.syncTrouble = trouble
				self.endBusy()
				self.refresh(fetch: false)
			}
		}
	}

	@objc private func doInstall() { Bier.runInTerminal(["install"]) }

	@objc private func doPrune() { Bier.runInTerminal(["prune"]) }

	@objc private func doAccess() {
		if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
			NSWorkspace.shared.open(url)
		}
		NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
	}

	@objc private func doUpgrade() { Bier.runInTerminal(["upgrade"]) }

	/// The guide, rendered, in whatever browser the Mac uses. The local
	/// file is still there for anyone who wants it — "Show folder in
	/// Finder" leads to it.
	@objc private func doDocs() {
		guard let url = URL(string: Bier.guideURL) else { return }
		NSWorkspace.shared.open(url)
	}

	@objc private func doReveal() {
		guard !state.repo.isEmpty else { return }
		NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: state.repo)
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
			alert.messageText = "Could not change \"Start at login\""
			alert.informativeText = error.localizedDescription
			alert.runModal()
		}
	}

	@objc private func doQuit() { NSApp.terminate(nil) }

	/// Opens pairing for ten minutes and shows the code, and what to run
	/// on the new Mac -- or, one day, to pick this Mac in its Bierkasten.
	@objc private func doJoin() {
		let r = Bier.run(["peer", "offer"])
		let code = line(after: "One-time code: ", in: r.out)
		let run = line(after: "On the other Mac run:", in: r.out)?.trimmingCharacters(in: .whitespaces)
		guard r.ok, let code else { return showFailure("Could not open pairing", r.err) }
		showCode(code, title: "A Mac can join for 10 minutes",
			text: "On the new Mac, run in Terminal:\n\n    \(run ?? "bier peer pair <this Mac>")\n\nand enter this code — or enter it in Bierkasten's Add a Mac.")
	}

	/// Lets Bierkasten connect to this Mac's agent, once.
	@objc private func doConnectApp() {
		let r = Bier.run(["admin", "offer"])
		guard r.ok, let code = line(after: "Enter this code in Bierkasten: ", in: r.out) else {
			return showFailure("Could not open the connection", r.err)
		}
		showCode(code, title: "Connect Bierkasten", text: "Enter this code in Bierkasten. It is open for 10 minutes.")
		if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "net.toberer.bierkasten") {
			NSWorkspace.shared.open(app)
		}
	}

	private func line(after prefix: String, in text: String) -> String? {
		text.split(separator: "\n").first { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
	}

	private func showCode(_ code: String, title: String, text: String) {
		NSApp.activate(ignoringOtherApps: true)
		let alert = NSAlert()
		alert.messageText = title
		alert.informativeText = text + "\n\n" + code
		alert.addButton(withTitle: "Copy Code")
		alert.addButton(withTitle: "Done")
		if alert.runModal() == .alertFirstButtonReturn {
			NSPasteboard.general.clearContents()
			NSPasteboard.general.setString(code, forType: .string)
		}
	}

	private func showFailure(_ title: String, _ detail: String) {
		NSApp.activate(ignoringOtherApps: true)
		let alert = NSAlert()
		alert.messageText = title
		alert.informativeText = detail.trimmingCharacters(in: .whitespacesAndNewlines)
		alert.runModal()
	}
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // no dock icon
let controller = Controller()
controller.start()
app.run()
