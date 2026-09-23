import Foundation
import CryptoKit

@main
struct SnapshotTest {
	static func manifest(_ files: [(String, Data)]) -> DataManifest {
		DataManifest(version: 1, entries: files.map { path, data in
			DataManifestEntry(path: path, bytes: UInt64(data.count), sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())
		})
	}

	static func main() throws {
		let manager = FileManager.default
		let root = manager.temporaryDirectory.appendingPathComponent("bier-snapshot-test-\(UUID().uuidString)")
		defer { try? manager.removeItem(at: root) }
		let live = root.appendingPathComponent("data")
		try manager.createDirectory(at: live.appendingPathComponent("Brewfiles"), withIntermediateDirectories: true)
		try Data("old\n".utf8).write(to: live.appendingPathComponent("Brewfiles/main"))

		let store = try DataSnapshotStore(live: live)
		let first = "snapshot-first-0123456789"
		let main = Data("new\n".utf8)
		let safe = Data("encrypted\n".utf8)
		try store.begin(first, manifest: manifest([("Brewfiles/main", main), ("Safe/test.gpg", safe)]))
		try store.put(first, path: "Brewfiles/main", offset: 0, data: main)
		try store.put(first, path: "Safe/test.gpg", offset: 0, data: safe)
		do {
			try store.commit(first)
		} catch {
			throw NSError(domain: "SnapshotTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "complete snapshot was rejected: \(error)"])
		}

		guard try String(contentsOf: live.appendingPathComponent("Brewfiles/main"), encoding: .utf8) == "new\n",
			manager.fileExists(atPath: live.appendingPathComponent("Safe/test.gpg").path) else {
			throw NSError(domain: "SnapshotTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "committed snapshot is incomplete"])
		}

		let interrupted = "snapshot-interrupted-0123456789"
		let interruptedData = Data("interrupted\n".utf8)
		try store.begin(interrupted, manifest: manifest([("Brewfiles/main", interruptedData)]))
		try store.put(interrupted, path: "Brewfiles/main", offset: 0, data: interruptedData)
		guard try String(contentsOf: live.appendingPathComponent("Brewfiles/main"), encoding: .utf8) == "new\n" else {
			throw NSError(domain: "SnapshotTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "staging changed live data"])
		}

		do {
			try store.put("../not-a-snapshot", path: "Brewfiles/main", offset: 0, data: Data())
			throw NSError(domain: "SnapshotTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "invalid snapshot ID was accepted"])
		} catch DataSnapshotError.invalidPath {}

		do {
			try store.put(interrupted, path: "../outside", offset: 0, data: Data())
			throw NSError(domain: "SnapshotTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "invalid path was accepted"])
		} catch DataSnapshotError.invalidPath {}

		let incomplete = "snapshot-incomplete-0123456789"
		let incompleteData = Data("second\n".utf8)
		try store.begin(incomplete, manifest: manifest([("Brewfiles/main", incompleteData)]))
		try store.put(incomplete, path: "Brewfiles/main", offset: 0, data: Data("second".utf8))
		do {
			try store.commit(incomplete)
			throw NSError(domain: "SnapshotTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "incomplete snapshot was committed"])
		} catch DataSnapshotError.incompleteSnapshot {}

		print("Swift Bier snapshot tests passed.")
	}
}
