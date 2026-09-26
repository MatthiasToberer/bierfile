import Foundation

// The pages of Bierkasten, ready to show. bier view hands in what this Mac
// knows (the lines of bier report) and what the other Macs last said (the
// fleet cache); everything the app shows is worked out here, once, so the
// app neither counts nor compares. Bierkasten decodes the same types.

/// How a package stands on one Mac.
public enum PackageState: String, Codable, Sendable {
	/// It should be there, and is.
	case installed
	/// It should be there, and is not.
	case missing
	/// It is there, and was taken off elsewhere.
	case extra
	/// It is there, and neither All Macs nor a group gives it.
	case notAssigned
	/// The Mac has not said how it is.
	case unknown
}

/// How a Mac was last reached.
public enum Reach: String, Codable, Sendable {
	/// The Mac bier view runs on.
	case this
	case online
	case offline
	/// It answers, but does not say how it is: bier there is too old.
	case reachable
	/// Named in the lists, but not paired with this Mac.
	case unpaired
}

public struct ViewMac: Codable, Equatable, Sendable {
	/// Its one name, hostname -s.
	public var id: String
	/// How this Mac reaches it; nil for this Mac and for one not paired.
	public var address: String?
	/// Its group; nil while it is new, in none.
	public var group: String?
	public var reach: Reach
	/// When it was last asked, and when it last said how it is (seconds
	/// since 1970); for this Mac both are now.
	public var checked: Int?
	public var heard: Int?
	public var version: String?
	public var macos: String?
	public var model: String?
	public var disk: String?
	/// The Macs it trusts.
	public var trusts: [String]
	/// Whether it waits to be accepted here.
	public var waiting: Bool
	public var missing: Int
	public var extra: Int
	public var notAssigned: Int
	/// All it should have is there and nothing taken off is left; nil
	/// when it has not said.
	public var inSync: Bool?
}

public struct ViewGroup: Codable, Equatable, Sendable {
	public var name: String
	public var macs: [String]
	/// automatic | ask
	public var apply: String
	/// automatic | manual
	public var inventory: String
	/// How many packages the group gives.
	public var software: Int
}

public struct ViewPackage: Codable, Equatable, Sendable {
	/// As the lists write it: cask "firefox".
	public var entry: String
	public var name: String
	/// brew, cask, mas, tap, vscode …
	public var kind: String
	/// "all", or the groups that give it; empty when nothing does.
	public var givenTo: [String]
	/// Per Mac; a Mac it does not concern is left out.
	public var states: [String: PackageState]
	public var installed: Int
	public var missing: Int
	public var extra: Int
	public var notAssigned: Int
	public var unknown: Int
}

public struct ViewFile: Codable, Equatable, Sendable {
	public var path: String
	/// nil for All Macs, else the group.
	public var group: String?
}

public struct ViewAppSetting: Codable, Equatable, Sendable {
	public var package: String
	public var app: String
	public var what: String
	public var group: String?
}

public struct ViewChange: Codable, Equatable, Sendable {
	public var time: Int
	public var subject: String
	public var commit: String
}

/// A bier command the app may run, and what its button says.
public struct ViewAction: Codable, Equatable, Sendable {
	public var title: String
	public var args: [String]
}

/// Something that needs a person. kind and macs let the app word it in
/// its own language; text is the English wording.
public struct ViewFinding: Codable, Equatable, Sendable {
	/// pending, new, missing, extra, conflict, arrived, offline, old, release
	public var kind: String
	public var text: String
	public var macs: [String]
	public var detail: String?
	public var actions: [ViewAction]
}

/// A line in the network picture.
public struct ViewLink: Codable, Equatable, Sendable {
	public var from: String
	public var to: String
	/// paired: both trust each other; waiting: one waits to be accepted
	/// or only one side trusts the other.
	public var kind: String
}

public struct ViewCounts: Codable, Equatable, Sendable {
	public var macs: Int
	public var inSync: Int
	public var missing: Int
	public var extra: Int
	public var offline: Int
}

/// One page. What every page needs -- the Macs, the groups -- is always
/// there; the rest only on the page it belongs to.
public struct FleetPage: Codable, Equatable, Sendable {
	public var page: String
	public var generated: Int
	public var this: String
	public var macs: [ViewMac]
	public var groups: [ViewGroup]
	public var counts: ViewCounts?
	public var needsYou: [ViewFinding]?
	public var links: [ViewLink]?
	public var activity: [ViewChange]?
	/// The Macs in no group yet.
	public var new: [String]?
	public var group: ViewGroup?
	public var mac: ViewMac?
	public var software: [ViewPackage]?
	public var package: ViewPackage?
	public var files: [ViewFile]?
	public var appSettings: [ViewAppSetting]?
}

public enum FleetViewError: Error, CustomStringConvertible {
	case unknownPage(String)
	case unknownGroup(String)
	case unknownMac(String)
	case unknownPackage(String)

	public var description: String {
		switch self {
		case let .unknownPage(page): return "no page called \(page)"
		case let .unknownGroup(group): return "no group called \(group)"
		case let .unknownMac(mac): return "no Mac called \(mac)"
		case let .unknownPackage(entry): return "\(entry) is on no list and on no Mac"
		}
	}
}

/// What one Mac said about itself: the lines of bier state.
struct MacSaid {
	var lines: [[String]] = []

	func values(_ key: String) -> [[String]] { lines.filter { $0.first == key }.map { Array($0.dropFirst()) } }
	func first(_ key: String) -> String? { values(key).first?.first }
	func entries(_ key: String) -> Set<String> { Set(values(key).compactMap(\.first)) }
	func info(_ what: String) -> String? { values("INFO").first { $0.first == what }.flatMap { $0.count > 1 ? $0[1] : nil } }
}

public struct FleetView {
	let now: Int
	let this: String
	let own: MacSaid
	/// Each list by name: main, @group, or a Mac.
	var lists: [String: [String]] = [:]
	var groupMembers: [(String, [String])] = []
	var rules: [String: [String: String]] = [:]
	var files: [ViewFile] = []
	var appSettings: [ViewAppSetting] = []
	var history: [ViewChange] = []
	/// Paired Macs: address → name.
	var peers: [(address: String, name: String)] = []
	/// What each other Mac last said, by name.
	var said: [String: MacSaid] = [:]
	var fleet: [String: (status: String, checked: Int?, heard: Int?)] = [:]
	var pending: [(mac: String, by: String)] = []

	/// report: the output of bier report; fleet: the cache files of bier
	/// fleet, one per Mac.
	public init(report: String, fleet cache: [String], now: Int = Int(Date().timeIntervalSince1970)) {
		self.now = now
		var own = MacSaid()
		var this = ""
		for line in report.split(separator: "\n", omittingEmptySubsequences: true) {
			let f = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
			guard let key = f.first else { continue }
			let v = Array(f.dropFirst())
			switch key {
			case "HOST": this = v.first ?? ""; own.lines.append(f)
			case "ENTRY" where v.count >= 2: lists[v[0], default: []].append(v[1])
			case "GROUP" where v.count >= 1:
				let members = v.count > 1 ? v[1].split(separator: " ").map(String.init) : []
				groupMembers.append((v[0], members))
			case "RULE" where v.count >= 3: rules[v[0], default: [:]][v[1]] = v[2]
			case "FILE" where v.count >= 1: files.append(ViewFile(path: v[0], group: v.count > 1 ? v[1].orNil : nil))
			case "APPSET" where v.count >= 3:
				appSettings.append(ViewAppSetting(package: v[0], app: v[1], what: v[2], group: v.count > 3 ? v[3].orNil : nil))
			case "HISTORY" where v.count >= 3: history.append(ViewChange(time: Int(v[0]) ?? 0, subject: v[1], commit: v[2]))
			case "PEER" where v.count >= 1: peers.append((v[0], v.count > 3 && !v[3].isEmpty ? v[3] : FleetView.shortName(v[0])))
			case "PENDING" where v.count >= 1: pending.append((v[0], v.count > 1 ? v[1] : ""))
			case "SELF", "MAC", "REPO", "COMMIT": break
			default: own.lines.append(f)
			}
		}
		self.own = own
		self.this = this
		let names = Dictionary(peers.map { ($0.address, $0.name) }, uniquingKeysWith: { a, _ in a })
		for file in cache {
			var name: String?
			var mac = MacSaid()
			for line in file.split(separator: "\n", omittingEmptySubsequences: true) {
				let f = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
				if f.first == "FLEET", f.count >= 3 {
					name = names[f[1]] ?? FleetView.shortName(f[1])
					fleet[name!] = (f[2], f.count > 3 ? Int(f[3]) : nil, f.count > 4 ? Int(f[4]) : nil)
				} else if f.first == "AT", f.count >= 3 {
					mac.lines.append(Array(f.dropFirst(2)))
				}
			}
			if let name, !mac.lines.isEmpty { said[name] = mac }
		}
	}

	static func shortName(_ address: String) -> String {
		let host = address.split(separator: "@").last.map(String.init) ?? address
		return host.split(separator: ".").first.map(String.init) ?? host
	}

	// MARK: - The Macs

	var groupNames: [String] { groupMembers.map(\.0) }

	func group(of mac: String) -> String? {
		if let group = groupMembers.first(where: { $0.1.contains(mac) })?.0 { return group }
		// Not in this Mac's lists yet: what the Mac says of itself.
		let theirs = (mac == this ? own : said[mac])?.first("MYGROUP")
		return theirs == "new" ? nil : theirs
	}

	/// Every Mac there is: this one, the paired ones, and those the lists
	/// or a waiting introduction name.
	var macIDs: [String] {
		var ids = [this]
		func add(_ id: String) { if !id.isEmpty && !ids.contains(id) { ids.append(id) } }
		peers.forEach { add($0.name) }
		groupMembers.flatMap(\.1).forEach(add)
		lists.keys.filter { $0 != "main" && !$0.hasPrefix("@") }.sorted().forEach(add)
		pending.forEach { add($0.mac) }
		return ids
	}

	func state(of mac: String) -> MacSaid? { mac == this ? own : said[mac] }

	/// What the Mac should have: All Macs and its group, then its own list.
	func wanted(by mac: String) -> (given: [String], own: [String]) {
		var given = lists["main"] ?? []
		if let group = group(of: mac) { given += lists["@" + group] ?? [] }
		return (given, lists[mac] ?? [])
	}

	/// Every package that concerns the Mac, and how it stands there.
	func states(on mac: String) -> [String: PackageState] {
		let (given, ownList) = wanted(by: mac)
		var result: [String: PackageState] = [:]
		guard let said = state(of: mac) else {
			for entry in given { result[entry] = .unknown }
			return result
		}
		let gone = said.entries("GONE")
		for entry in ownList { result[entry] = gone.contains(entry) ? .missing : .notAssigned }
		for entry in given { result[entry] = gone.contains(entry) ? .missing : .installed }
		for entry in said.entries("NEW") { result[entry] = .notAssigned }
		for entry in said.entries("STALE").union(said.entries("DROPPED")) { result[entry] = .extra }
		return result
	}

	func mac(_ id: String) -> ViewMac {
		let said = state(of: id)
		let address = peers.first { $0.name == id }?.address
		let reach: Reach
		if id == this {
			reach = .this
		} else if let status = fleet[id]?.status {
			reach = Reach(rawValue: status) ?? .offline
		} else {
			reach = address == nil ? .unpaired : .offline
		}
		let states = self.states(on: id).values
		let count = { (state: PackageState) in states.filter { $0 == state }.count }
		let known = said != nil
		return ViewMac(
			id: id, address: address, group: group(of: id), reach: reach,
			checked: id == this ? now : fleet[id]?.checked,
			heard: id == this ? now : fleet[id]?.heard,
			version: said?.first("VERSION"), macos: said?.info("macos"), model: said?.info("model"), disk: said?.info("disk"),
			trusts: said?.values("TRUSTS").compactMap(\.first) ?? [],
			waiting: pending.contains { $0.mac == id },
			missing: count(.missing), extra: count(.extra), notAssigned: count(.notAssigned),
			inSync: known ? count(.missing) == 0 && count(.extra) == 0 && said?.first("STATE") != "drift" : nil)
	}

	var macs: [ViewMac] { macIDs.map(mac) }

	var groups: [ViewGroup] {
		groupMembers.map { name, members in
			ViewGroup(name: name, macs: members,
				apply: rules[name]?["apply"] ?? "automatic",
				inventory: rules[name]?["inventory"] ?? "automatic",
				software: lists["@" + name]?.count ?? 0)
		}
	}

	// MARK: - Packages

	func givenTo(_ entry: String) -> [String] {
		if lists["main"]?.contains(entry) == true { return ["all"] }
		return groupNames.filter { lists["@" + $0]?.contains(entry) == true }
	}

	func package(_ entry: String, on macs: [String], statesByMac: [String: [String: PackageState]]) -> ViewPackage {
		var states: [String: PackageState] = [:]
		for mac in macs { if let state = statesByMac[mac]?[entry] { states[mac] = state } }
		let count = { (state: PackageState) in states.values.filter { $0 == state }.count }
		return ViewPackage(entry: entry, name: FleetView.name(of: entry), kind: FleetView.kind(of: entry),
			givenTo: givenTo(entry), states: states,
			installed: count(.installed), missing: count(.missing), extra: count(.extra),
			notAssigned: count(.notAssigned), unknown: count(.unknown))
	}

	static func kind(of entry: String) -> String { entry.split(separator: " ").first.map(String.init) ?? "" }

	static func name(of entry: String) -> String {
		let parts = entry.split(separator: "\"")
		return parts.count >= 2 ? String(parts[1]) : entry
	}

	/// The packages the given Macs have or should have, and those the
	/// chosen lists give, sorted by name.
	func software(on macs: [String], lists names: [String]? = nil) -> [ViewPackage] {
		let statesByMac = Dictionary(uniqueKeysWithValues: macs.map { ($0, states(on: $0)) })
		var entries = Set(statesByMac.values.flatMap(\.keys))
		for name in names ?? Array(lists.keys) { entries.formUnion(lists[name] ?? []) }
		return entries.map { package($0, on: macs, statesByMac: statesByMac) }
			.sorted { ($0.name.lowercased(), $0.kind) < ($1.name.lowercased(), $1.kind) }
	}

	// MARK: - What needs a person

	var findings: [ViewFinding] {
		var found: [ViewFinding] = []
		let macs = self.macs
		for (mac, by) in pending {
			found.append(ViewFinding(kind: "pending", text: "\(mac) waits to be trusted", macs: [mac],
				detail: by.isEmpty ? nil : "Introduced by \(by). Accept it once; \(mac) then trusts this Mac as well.",
				actions: [ViewAction(title: "Accept", args: ["peer", "accept", mac]), ViewAction(title: "Reject", args: ["peer", "reject", mac])]))
		}
		let new = macs.filter { $0.group == nil && !$0.waiting && $0.reach != .unpaired }.map(\.id)
		if !new.isEmpty {
			found.append(ViewFinding(kind: "new", text: "\(FleetView.list(new)) \(new.count == 1 ? "is" : "are") in no group yet", macs: new,
				detail: "A Mac gets what All Macs and its group give. Move it to a group.", actions: []))
		}
		let missing = macs.filter { $0.missing > 0 }
		if !missing.isEmpty {
			found.append(ViewFinding(kind: "missing", text: "Software is missing on \(FleetView.list(missing.map(\.id)))", macs: missing.map(\.id),
				detail: "\(missing.map(\.missing).reduce(0, +)) package(s) that All Macs or a group gives are not installed yet.",
				actions: [ViewAction(title: "Install on Every Mac Now", args: ["apply", "--everywhere"])]))
		}
		let extra = macs.filter { $0.extra > 0 }
		if !extra.isEmpty {
			found.append(ViewFinding(kind: "extra", text: "Software taken off is still on \(FleetView.list(extra.map(\.id)))", macs: extra.map(\.id),
				detail: "\(extra.map(\.extra).reduce(0, +)) package(s) were removed elsewhere and are still installed.",
				actions: [ViewAction(title: "Remove on Every Mac Now", args: ["apply", "--everywhere"])]))
		}
		for path in own.values("VAULT_LEFT").compactMap(\.first) {
			found.append(ViewFinding(kind: "conflict", text: "\(path) was changed on two Macs", macs: [this],
				detail: "Both versions are kept. Choose which one stays.",
				actions: [ViewAction(title: "Keep This Mac's", args: ["vault", "resolve", path, "mine"]),
					ViewAction(title: "Keep the Other", args: ["vault", "resolve", path, "theirs"])]))
		}
		let arrived = own.values("VAULT_IN").compactMap(\.first)
		if !arrived.isEmpty {
			found.append(ViewFinding(kind: "arrived", text: "Settings arrived for \(FleetView.list(arrived))", macs: [this],
				detail: "They are put in place with the next sync.", actions: [ViewAction(title: "Sync Now", args: ["sync"])]))
		}
		for mac in macs where mac.reach == .offline {
			found.append(ViewFinding(kind: "offline", text: "\(mac.id) is away", macs: [mac.id],
				detail: mac.heard.map { "Last heard from \(FleetView.ago(now - $0)) ago." } ?? "Not heard from yet.", actions: []))
		}
		for mac in macs where mac.reach == .reachable {
			found.append(ViewFinding(kind: "old", text: "\(mac.id) answers but does not say how it is", macs: [mac.id],
				detail: "bier there is too old. Run bier upgrade on \(mac.id).", actions: []))
		}
		if let release = own.first("NEWCODE") {
			found.append(ViewFinding(kind: "release", text: "bier \(release) is out", macs: [this],
				detail: "Upgrade from the menu bar glass, or run bier upgrade.", actions: []))
		}
		return found
	}

	/// Where the lines of the network run.
	var links: [ViewLink] {
		let macs = self.macs
		let trusts = Dictionary(uniqueKeysWithValues: macs.map { ($0.id, Set($0.trusts)) })
		// A Mac with an older bier does not say whom it trusts; it is taken
		// at the word of the others.
		let known = Set(macs.filter { !$0.trusts.isEmpty }.map(\.id))
		var links: [ViewLink] = []
		for (i, a) in macs.enumerated() {
			for b in macs.dropFirst(i + 1) {
				let ab = trusts[a.id]?.contains(b.id) == true, ba = trusts[b.id]?.contains(a.id) == true
				guard ab || ba else { continue }
				let paired = (ab || !known.contains(a.id)) && (ba || !known.contains(b.id))
				links.append(ViewLink(from: a.id, to: b.id, kind: paired ? "paired" : "waiting"))
			}
		}
		for (mac, by) in pending {
			let from = by.isEmpty ? this : by
			if !links.contains(where: { Set([$0.from, $0.to]) == Set([from, mac]) }) {
				links.append(ViewLink(from: from, to: mac, kind: "waiting"))
			}
		}
		return links
	}

	static func list(_ names: [String]) -> String {
		names.count <= 1 ? names.joined() : names.dropLast().joined(separator: ", ") + " and " + names.last!
	}

	static func ago(_ seconds: Int) -> String {
		switch seconds {
		case ..<120: return "a minute"
		case ..<7200: return "\(seconds / 60) minutes"
		case ..<172_800: return "\(seconds / 3600) hours"
		default: return "\(seconds / 86400) days"
		}
	}

	// MARK: - Pages

	public func page(_ name: String, _ argument: String? = nil) throws -> FleetPage {
		var page = FleetPage(page: name, generated: now, this: this, macs: macs, groups: groups)
		switch (name, argument) {
		case ("overview", nil):
			let macs = page.macs
			page.counts = ViewCounts(macs: macs.count, inSync: macs.filter { $0.inSync == true }.count,
				missing: macs.map(\.missing).reduce(0, +), extra: macs.map(\.extra).reduce(0, +),
				offline: macs.filter { $0.reach == .offline }.count)
			page.needsYou = findings
			page.links = links
			page.activity = history
		case ("groups", nil):
			page.new = page.macs.filter { $0.group == nil && $0.reach != .unpaired }.map(\.id)
		case ("all", nil):
			page.software = software(on: macIDs)
			page.files = files
			page.appSettings = appSettings
		case let ("group", group?):
			guard let found = page.groups.first(where: { $0.name == group }) else { throw FleetViewError.unknownGroup(group) }
			page.group = found
			page.software = software(on: found.macs, lists: ["main", "@" + group])
			page.files = files.filter { $0.group == nil || $0.group == group }
			page.appSettings = appSettings.filter { $0.group == nil || $0.group == group }
		case let ("mac", id?):
			guard let found = page.macs.first(where: { $0.id == id }) else { throw FleetViewError.unknownMac(id) }
			page.mac = found
			page.software = software(on: [id], lists: [])
			page.needsYou = findings.filter { $0.macs.contains(id) }
			page.activity = history.filter { $0.subject.hasPrefix(id + ":") }
		case let ("package", entry?):
			let all = software(on: macIDs)
			guard let found = all.first(where: { $0.entry == entry || $0.name == entry }) else { throw FleetViewError.unknownPackage(entry) }
			page.package = found
			page.appSettings = appSettings.filter { $0.package == found.name }
		default:
			throw FleetViewError.unknownPage(([name] + (argument.map { [$0] } ?? [])).joined(separator: " "))
		}
		return page
	}

	public func json(_ name: String, _ argument: String? = nil) throws -> Data {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
		return try encoder.encode(page(name, argument))
	}
}

extension String {
	fileprivate var orNil: String? { isEmpty ? nil : self }
}
