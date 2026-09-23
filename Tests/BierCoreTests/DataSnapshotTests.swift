import CryptoKit
import Foundation
import Testing
@testable import BierCore


@Suite struct DataSnapshotTests {
	private func manifest(_ files: [(String, Data)]) -> DataManifest {
		DataManifest(version: 1, entries: files.map { path, data in
			DataManifestEntry(
				path: path,
				bytes: UInt64(data.count),
				sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
			)
		})
	}

	@Test func commitReplacesLiveDataOnlyAfterCompleteSnapshot() throws {
		let manager = FileManager.default
		let root = manager.temporaryDirectory.appendingPathComponent("bier-core-test-\(UUID().uuidString)")
		defer { try? manager.removeItem(at: root) }
		let live = root.appendingPathComponent("data")
		try manager.createDirectory(at: live.appendingPathComponent("Brewfiles"), withIntermediateDirectories: true)
		try Data("old\n".utf8).write(to: live.appendingPathComponent("Brewfiles/main"))

		let store = try DataSnapshotStore(live: live)
		let id = "snapshot-complete-0123456789"
		let main = Data("new\n".utf8)
		let safe = Data("encrypted\n".utf8)
		try store.begin(id, manifest: manifest([("Brewfiles/main", main), ("Safe/test.gpg", safe)]))
		try store.put(id, path: "Brewfiles/main", offset: 0, data: main)

		#expect(try String(contentsOf: live.appendingPathComponent("Brewfiles/main"), encoding: .utf8) == "old\n")
		#expect(throws: DataSnapshotError.self) { try store.commit(id) }

		try store.put(id, path: "Safe/test.gpg", offset: 0, data: safe)
		try store.commit(id)

		#expect(try String(contentsOf: live.appendingPathComponent("Brewfiles/main"), encoding: .utf8) == "new\n")
		#expect(try Data(contentsOf: live.appendingPathComponent("Safe/test.gpg")) == safe)
	}

	@Test func dataReaderRejectsSymbolicLinks() throws {
		let manager = FileManager.default
		let root = manager.temporaryDirectory.appendingPathComponent("bier-core-test-\(UUID().uuidString)")
		defer { try? manager.removeItem(at: root) }
		try manager.createDirectory(at: root.appendingPathComponent("Safe"), withIntermediateDirectories: true)
		try manager.createSymbolicLink(at: root.appendingPathComponent("Safe/link.gpg"), withDestinationURL: URL(fileURLWithPath: "/etc/passwd"))

		#expect(throws: DataSnapshotError.self) {
			try readDataChunk(at: root, path: "Safe/link.gpg", offset: 0, length: 1)
		}
	}

	@Test func peerRequestCanonicalDataIncludesBodyHash() {
		let request = PeerRequest(
			method: "POST",
			path: "/v1/peer/snapshot/commit",
			peer: "mini",
			time: "2026-09-23T12:00:00Z",
			nonce: "01234567-89ab-cdef-0123-456789abcdef",
			body: Data("{}".utf8)
		)
		#expect(String(data: request.canonicalData, encoding: .utf8) == "POST\n/v1/peer/snapshot/commit\nmini\n2026-09-23T12:00:00Z\n01234567-89ab-cdef-0123-456789abcdef\n44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a\n")
	}
}
