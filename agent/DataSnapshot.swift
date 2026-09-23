import Foundation

enum DataSnapshotError: Error {
	case invalidPath
	case unknownSnapshot
}

final class DataSnapshotStore {
	private let live: URL
	private let staging: URL

	init(live: URL) throws {
		self.live = live
		staging = live.deletingLastPathComponent().appendingPathComponent(".bier-staging")
		try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
	}

	func begin(_ id: String) throws {
		guard id.range(of: "^[A-Za-z0-9_-]{16,128}$", options: .regularExpression) != nil else { throw DataSnapshotError.invalidPath }
		let directory = staging.appendingPathComponent(id)
		try? FileManager.default.removeItem(at: directory)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
	}

	func put(_ id: String, path: String, data: Data) throws {
		guard path == ".gitattributes" || path.hasPrefix("Brewfiles/") || path.hasPrefix("Safe/"),
			!path.contains(".."), !path.hasPrefix("/") else { throw DataSnapshotError.invalidPath }
		let directory = staging.appendingPathComponent(id)
		guard FileManager.default.fileExists(atPath: directory.path) else { throw DataSnapshotError.unknownSnapshot }
		let target = directory.appendingPathComponent(path)
		try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
		try data.write(to: target, options: .atomic)
		try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
	}

	func commit(_ id: String) throws {
		let source = staging.appendingPathComponent(id)
		guard FileManager.default.fileExists(atPath: source.path) else { throw DataSnapshotError.unknownSnapshot }
		let replacement = live.deletingLastPathComponent().appendingPathComponent(".bier-replacement-\(id)")
		try? FileManager.default.removeItem(at: replacement)
		try FileManager.default.moveItem(at: source, to: replacement)
		if FileManager.default.fileExists(atPath: live.path) {
			_ = try FileManager.default.replaceItemAt(live, withItemAt: replacement, backupItemName: nil, options: [])
		} else {
			try FileManager.default.moveItem(at: replacement, to: live)
		}
	}
}
