import Foundation

@main
struct SnapshotTest {
	static func main() throws {
		let manager = FileManager.default
		let root = manager.temporaryDirectory.appendingPathComponent("bier-snapshot-test-\(UUID().uuidString)")
		defer { try? manager.removeItem(at: root) }
		let live = root.appendingPathComponent("data")
		try manager.createDirectory(at: live.appendingPathComponent("Brewfiles"), withIntermediateDirectories: true)
		try Data("old\n".utf8).write(to: live.appendingPathComponent("Brewfiles/main"))

		let store = try DataSnapshotStore(live: live)
		let first = "snapshot-first-0123456789"
		try store.begin(first)
		try store.put(first, path: "Brewfiles/main", data: Data("new\n".utf8))
		try store.put(first, path: "Safe/test.gpg", data: Data("encrypted\n".utf8))
		try store.commit(first)

		guard try String(contentsOf: live.appendingPathComponent("Brewfiles/main"), encoding: .utf8) == "new\n",
			manager.fileExists(atPath: live.appendingPathComponent("Safe/test.gpg").path) else {
			throw NSError(domain: "SnapshotTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "committed snapshot is incomplete"])
		}

		let interrupted = "snapshot-interrupted-0123456789"
		try store.begin(interrupted)
		try store.put(interrupted, path: "Brewfiles/main", data: Data("interrupted\n".utf8))
		guard try String(contentsOf: live.appendingPathComponent("Brewfiles/main"), encoding: .utf8) == "new\n" else {
			throw NSError(domain: "SnapshotTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "staging changed live data"])
		}

		do {
			try store.put("../not-a-snapshot", path: "Brewfiles/main", data: Data())
			throw NSError(domain: "SnapshotTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "invalid snapshot ID was accepted"])
		} catch DataSnapshotError.invalidPath {}

		do {
			try store.put(interrupted, path: "../outside", data: Data())
			throw NSError(domain: "SnapshotTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "invalid path was accepted"])
		} catch DataSnapshotError.invalidPath {}

		do {
			try store.put(interrupted, path: "Brewfiles/main", data: Data("first\n".utf8))
			try store.put(interrupted, path: "Brewfiles/main", data: Data("second\n".utf8))
			throw NSError(domain: "SnapshotTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "duplicate path was accepted"])
		} catch DataSnapshotError.duplicatePath {}

		print("Swift Bier snapshot tests passed.")
	}
}
