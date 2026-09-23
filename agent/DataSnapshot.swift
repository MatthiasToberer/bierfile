import Foundation

enum DataSnapshotError: Error {
	case invalidPath
	case invalidManifest
	case unknownSnapshot
	case unexpectedPath
	case invalidOffset
	case oversizedChunk
	case incompleteSnapshot
}

let maxSnapshotChunkBytes = 32 * 1024

private struct SnapshotSession {
	let entries: [String: DataManifestEntry]
	var received: [String: UInt64]
}

final class DataSnapshotStore {
	private let live: URL
	private let staging: URL
	private let lock = NSLock()
	private var sessions: [String: SnapshotSession] = [:]

	init(live: URL) throws {
		self.live = live
		staging = live.deletingLastPathComponent().appendingPathComponent(".bier-staging")
		try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
	}

	func begin(_ id: String, manifest: DataManifest) throws {
		lock.lock()
		defer { lock.unlock() }
		try validate(id)
		guard manifest.version == 1, manifest.entries.count <= 10_000 else { throw DataSnapshotError.invalidManifest }
		var entries: [String: DataManifestEntry] = [:]
		for entry in manifest.entries {
			try validate(path: entry.path)
			guard entry.bytes <= 1_073_741_824,
				entry.sha256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil,
				entries[entry.path] == nil else { throw DataSnapshotError.invalidManifest }
			entries[entry.path] = entry
		}
		let directory = staging.appendingPathComponent(id)
		if FileManager.default.fileExists(atPath: directory.path) {
			try FileManager.default.removeItem(at: directory)
		}
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
		sessions[id] = SnapshotSession(entries: entries, received: [:])
	}

	func put(_ id: String, path: String, offset: UInt64, data: Data) throws {
		lock.lock()
		defer { lock.unlock() }
		try validate(id)
		try validate(path: path)
		guard data.count <= maxSnapshotChunkBytes else { throw DataSnapshotError.oversizedChunk }
		guard var session = sessions[id] else { throw DataSnapshotError.unknownSnapshot }
		guard let entry = session.entries[path] else { throw DataSnapshotError.unexpectedPath }
		let received = session.received[path] ?? 0
		guard offset == received, UInt64(data.count) <= entry.bytes - received else { throw DataSnapshotError.invalidOffset }
		let directory = staging.appendingPathComponent(id)
		let target = directory.appendingPathComponent(path)
		try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
		if !FileManager.default.fileExists(atPath: target.path) {
			FileManager.default.createFile(atPath: target.path, contents: nil, attributes: [.posixPermissions: 0o600])
		}
		let handle = try FileHandle(forWritingTo: target)
		defer { try? handle.close() }
		try handle.seek(toOffset: offset)
		try handle.write(contentsOf: data)
		session.received[path] = received + UInt64(data.count)
		sessions[id] = session
	}

	func commit(_ id: String) throws {
		lock.lock()
		defer { lock.unlock() }
		try validate(id)
		guard let session = sessions[id] else { throw DataSnapshotError.unknownSnapshot }
		guard session.entries.allSatisfy({ session.received[$0.key] == $0.value.bytes }) else { throw DataSnapshotError.incompleteSnapshot }
		let source = staging.appendingPathComponent(id)
		guard FileManager.default.fileExists(atPath: source.path),
			try collectDataManifest(at: source).entries == session.entries.values.sorted(by: { $0.path < $1.path }) else {
			throw DataSnapshotError.invalidManifest
		}
		let replacement = live.deletingLastPathComponent().appendingPathComponent(".bier-replacement-\(id)")
		try? FileManager.default.removeItem(at: replacement)
		try FileManager.default.moveItem(at: source, to: replacement)
		if FileManager.default.fileExists(atPath: live.path) {
			_ = try FileManager.default.replaceItemAt(live, withItemAt: replacement, backupItemName: nil, options: [])
		} else {
			try FileManager.default.moveItem(at: replacement, to: live)
		}
		sessions.removeValue(forKey: id)
	}

	private func validate(_ id: String) throws {
		guard id.range(of: "^[A-Za-z0-9_-]{16,128}$", options: .regularExpression) != nil else { throw DataSnapshotError.invalidPath }
	}

	private func validate(path: String) throws {
		guard path == ".gitattributes" || path.hasPrefix("Brewfiles/") || path.hasPrefix("Safe/"),
			!path.contains(".."), !path.hasPrefix("/"), !path.hasSuffix("/") else { throw DataSnapshotError.invalidPath }
	}
}
