// BierMenu — a beer glass in the menu bar.
//
// Full glass: system and Brewfile agree. Empty glass: something
// differs. A click shows what, and offers to sort it out.
//
// This is about *this* Mac and nothing else. What other devices have
// more or less of is deliberately absent from the menu — that belongs
// in the terminal ("bier list") and says nothing about whether there
// is anything to do here.
//
// The app computes nothing itself — it calls "bier state" and renders
// its output.

import AppKit
import ServiceManagement

// MARK: - State

struct BierState {
	var ok = false
	var host = ""
	var fresh: [String] = [] // installed here, not recorded yet
	var stale: [String] = [] // removed elsewhere, still installed here
	var gone: [String] = [] // recorded, but not installed here
	var version = "" // the script's version, for the out-of-date hint
	var release = "" // a newer release on the code server, empty if none
	var offline = "" // servers that could not be reached: data, code, both
	var repo = "" // path to the repository, for the info menu
	var commit = "" // short hash and date, for the info menu
	var ahead = 0
	var behind = 0
	var dirty = false
	var error: String?

	var hasAnything: Bool {
		!fresh.isEmpty || !stale.isEmpty || !gone.isEmpty
			|| ahead > 0 || behind > 0 || dirty
	}
}

// MARK: - Calling bier

enum Bier {
	/// Where the guide lives. Opening the local GUIDE.md hands macOS a
	/// .md file, and a Mac with no handler for those does nothing at all
	/// — the menu entry looked broken. The rendered page needs only a
	/// browser, and every Mac has one.
	static let guideURL = "https://github.com/MatthiasToberer/bierfile/blob/main/GUIDE.md"

	/// GUI programs do not inherit the shell's PATH. Homebrew and the
	/// Command Line Tools therefore have to be added explicitly.
	static let path = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

	/// Finds the bier script: via root from the config, then on PATH.
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
	static func run(_ args: [String]) -> (out: String, err: String, ok: Bool) {
		guard let exe = executable() else {
			return ("", "bier not found — is the repository still at the path "
				+ "from ~/.config/bier/config?", false)
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
		DispatchQueue.global().asyncAfter(deadline: .now() + runLimit, execute: watchdog)
		defer { watchdog.cancel() }
		let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
		let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
		task.waitUntilExit()
		if timedOut {
			return ("", "bier did not answer within \(Int(runLimit)) seconds "
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
			guard let tag = f.first else { continue }
			switch tag {
			case "STATE": s.ok = f.count > 1 && f[1] == "ok"
			case "HOST": if f.count > 1 { s.host = f[1] }
			case "VERSION": if f.count > 1 { s.version = f[1] }
			case "NEWCODE": if f.count > 1 { s.release = f[1] }
			case "OFFLINE": if f.count > 1 { s.offline = f[1] }
			case "REPO": if f.count > 1 { s.repo = f[1] }
			case "COMMIT":
				if f.count > 2 { s.commit = "\(f[1]) of \(f[2])" }
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
				self.statusItem.button?.toolTip = s.error ?? (s.ok
					? "Everything in sync"
					: "There are differences")
				self.endBusy()
				self.build(self.statusItem.menu!)
			}
		}
	}

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
		statusItem.button?.image = (state.ok && state.error == nil) ? full : empty
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
			addFooter(menu)
			return
		}

		// Say it before anything else. What follows is the last state
		// that could be fetched, and without this line it reads as the
		// current one.
		if !state.offline.isEmpty {
			let what = state.offline == "data code"
				? "Neither server could be reached"
				: state.offline == "code"
					? "The code server could not be reached"
					: "The inventory server could not be reached"
			menu.addItem(header(what))
			menu.addItem(detail("what follows is the last state it knows"))
			menu.addItem(.separator())
		}

		if state.ok {
			menu.addItem(header("Everything in sync"))
		} else {
			// Installed here, not recorded yet: quick and harmless.
			if !state.fresh.isEmpty {
				menu.addItem(header("\(state.fresh.count) installed but not recorded"))
				listing(state.fresh, into: menu)
				menu.addItem(action("Pour a round: record and push",
				                    #selector(doSync)))
				menu.addItem(.separator())
			}

			// Removed on another Mac. This uninstalls software, so it
			// belongs in the terminal and not behind a single click.
			if !state.stale.isEmpty {
				menu.addItem(header("\(state.stale.count) removed elsewhere, still here"))
				listing(state.stale, into: menu)
				menu.addItem(action("Remove … (in Terminal)",
				                    #selector(doPrune)))
				menu.addItem(.separator())
			}

			// Recorded but not installed.
			if !state.gone.isEmpty {
				menu.addItem(header("\(state.gone.count) recorded but not installed"))
				listing(state.gone, into: menu)
				menu.addItem(action("Install missing … (in Terminal)",
				                    #selector(doInstall)))
				menu.addItem(.separator())
			}

			// Git is lagging.
			if state.dirty {
				menu.addItem(header("Changes are not committed"))
				menu.addItem(action("Pour a round: record and push",
				                    #selector(doSync)))
				menu.addItem(.separator())
			}
			if state.behind > 0 {
				menu.addItem(header("origin is \(state.behind) commits ahead"))
				menu.addItem(action("Fetch (git pull)", #selector(doPull)))
				menu.addItem(.separator())
			}
			if state.ahead > 0, !state.dirty {
				menu.addItem(header("\(state.ahead) commits not pushed"))
				menu.addItem(action("Push", #selector(doPush)))
				menu.addItem(.separator())
			}
		}

		addFooter(menu)
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

		menu.addItem(action("Check now", #selector(doCheck)))

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
					+ (state.host.isEmpty ? "" : " · \(state.host)")))
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
			sub.addItem(detail("Device \(state.host)"))
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

	@objc private func doCheck() { refresh(fetch: true) }

	@objc private func doSync() { runQuietly(["sync"], "Recording and pushing") }

	@objc private func doPull() { runQuietly(["state", "--fetch"], "Fetching") }

	@objc private func doPush() { runQuietly(["sync"], "Pushing") }

	@objc private func doInstall() { Bier.runInTerminal(["install"]) }

	@objc private func doPrune() { Bier.runInTerminal(["prune"]) }

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

	/// Short, harmless runs without a terminal. Failures are shown,
	/// success is visible only as the glass filling up again.
	private func runQuietly(_ args: [String], _ what: String) {
		beginBusy()
		DispatchQueue.global(qos: .userInitiated).async { [weak self] in
			let r = Bier.run(args)
			DispatchQueue.main.async {
				self?.endBusy()
				if !r.ok {
					let alert = NSAlert()
					alert.messageText = "\(what) failed"
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
			alert.messageText = "Could not change \"Start at login\""
			alert.informativeText = error.localizedDescription
			alert.runModal()
		}
	}

	@objc private func doQuit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // no dock icon
let controller = Controller()
controller.start()
app.run()
