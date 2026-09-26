import Foundation
import Testing
@testable import BierCore

@Suite struct FleetViewTests {
	/// Three Macs: mini (this one) and air in the group home, book new.
	/// air is missing wget and still has htop, taken off elsewhere; book
	/// has not said anything yet.
	private let report = """
	STATE\tdrift
	HOST\tmini
	VERSION\t0.50.12
	MYGROUP\thome
	TRUSTS\tair
	INFO\tmacos\t26.0
	NEW\tbrew "jq"
	VAULT_LEFT\t/Users/ma/.zshrc.from-safe
	PENDING\tbook\tair
	SELF\tmini.ts.net
	GROUP\thome\tmini air
	RULE\thome\tapply\task
	ENTRY\tmain\tbrew "wget"
	ENTRY\t@home\tcask "firefox"
	ENTRY\tair\tbrew "tree"
	FILE\t~/.zshrc\t
	FILE\t~/.ssh/config\thome
	APPSET\tfirefox\tFirefox\tpreferences\t
	PEER\tair.ts.net\tabc123\t1700000000\tair
	HISTORY\t1700000000\tair: added tree\tdef456
	HISTORY\t1690000000\tmini: wget on every Mac\t0123abc
	"""

	private let air = """
	FLEET\tair.ts.net\toffline\t1700000600\t1700000000
	AT\tair.ts.net\tSTATE\tdrift
	AT\tair.ts.net\tHOST\tair
	AT\tair.ts.net\tVERSION\t0.50.8
	AT\tair.ts.net\tGONE\tbrew "wget"
	AT\tair.ts.net\tSTALE\tbrew "htop"
	"""

	private func view() -> FleetView { FleetView(report: report, fleet: [air], now: 1700000700) }

	@Test func everyMacHasOneNameAndItsAddressAsAField() throws {
		let page = try view().page("overview")
		#expect(page.macs.map(\.id) == ["mini", "air", "book"])
		let air = try #require(page.macs.first { $0.id == "air" })
		#expect(air.address == "air.ts.net")
		#expect(page.macs.first?.address == "mini.ts.net")
		#expect(air.reach == .offline)
		#expect(air.heard == 1700000000 && air.checked == 1700000600)
		#expect(air.group == "home")
		#expect(page.macs.first { $0.id == "book" }?.waiting == true)
		#expect(page.macs.first { $0.id == "book" }?.group == nil)
	}

	@Test func packageStatesFollowTheLists() throws {
		let page = try view().page("all")
		let states = Dictionary(uniqueKeysWithValues: (page.software ?? []).map { ($0.name, $0.states) })
		#expect(states["wget"] == ["mini": .installed, "air": .missing, "book": .unknown])
		#expect(states["firefox"] == ["mini": .installed, "air": .installed])
		#expect(states["htop"] == ["air": .extra])
		#expect(states["jq"] == ["mini": .notAssigned])
		#expect(states["tree"] == ["air": .notAssigned])
		#expect(page.software?.first { $0.name == "wget" }?.givenTo == ["all"])
		#expect(page.software?.first { $0.name == "firefox" }?.givenTo == ["home"])
	}

	@Test func aMacThatHasNotSaidIsUnknown() throws {
		let view = FleetView(report: report + "\nGROUP\tlab\tbook\nENTRY\t@lab\tcask \"zoom\"", fleet: [air], now: 0)
		let book = try view.page("mac", "book")
		#expect(book.software?.map(\.states) == [["book": .unknown], ["book": .unknown]])
		#expect(book.mac?.inSync == nil)
	}

	@Test func overviewCountsAndNeedsYou() throws {
		let page = try view().page("overview")
		#expect(page.counts == ViewCounts(macs: 3, inSync: 0, missing: 1, extra: 1, offline: 1))
		let kinds = page.needsYou?.map(\.kind) ?? []
		#expect(kinds == ["pending", "missing", "extra", "conflict", "offline"])
		#expect(page.needsYou?.first?.actions.map(\.args) == [["peer", "accept", "book"], ["peer", "reject", "book"]])
		#expect(page.needsYou?.first { $0.kind == "offline" }?.detail == "Last heard from 11 minutes ago.")
		#expect(page.needsYou?.first { $0.kind == "conflict" }?.text == "~/.zshrc was changed on two Macs")
		#expect(page.needsYou?.first { $0.kind == "missing" }?.detail == "1 package that All Macs or a group gives is not installed yet.")
	}

	@Test func linksShowTheRealMesh() throws {
		let links = try view().page("overview").links ?? []
		// air says nothing about trust (older bier): taken at mini's word.
		#expect(links.contains(ViewLink(from: "mini", to: "air", kind: "paired")))
		#expect(links.contains(ViewLink(from: "air", to: "book", kind: "waiting")))
		#expect(links.count == 2)
	}

	@Test func groupAndMacPagesKeepToTheirOwn() throws {
		let group = try view().page("group", "home")
		#expect(group.group == ViewGroup(name: "home", macs: ["mini", "air"], apply: "ask", inventory: "automatic", software: 1))
		#expect(group.files?.map(\.path) == ["~/.zshrc", "~/.ssh/config"])
		let mac = try view().page("mac", "air")
		#expect(mac.activity?.map(\.commit) == ["def456"])
		#expect(Set(mac.software?.map(\.name) ?? []) == ["wget", "firefox", "htop", "tree"])
		#expect(throws: FleetViewError.self) { try view().page("group", "nope") }
		#expect(throws: FleetViewError.self) { try view().page("mac", "nope") }
	}

	@Test func packagePageByNameOrEntry() throws {
		#expect(try view().page("package", "wget").package?.missing == 1)
		#expect(try view().page("package", "cask \"firefox\"").package?.installed == 2)
		#expect(throws: FleetViewError.self) { try view().page("package", "nothing") }
	}

	@Test func jsonDecodesIntoTheSameTypes() throws {
		let data = try view().json("overview")
		let page = try JSONDecoder().decode(FleetPage.self, from: data)
		#expect(page == (try view().page("overview")))
	}
}
