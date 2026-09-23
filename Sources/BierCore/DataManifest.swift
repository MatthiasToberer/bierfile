import Foundation
import CryptoKit

public struct DataManifestEntry: Codable, Equatable {
	public let path: String
	public let bytes: UInt64
	public let sha256: String

	public init(path: String, bytes: UInt64, sha256: String) {
		self.path = path
		self.bytes = bytes
		self.sha256 = sha256
	}
}

public struct DataManifest: Codable {
	public let version: Int
	public let entries: [DataManifestEntry]

	public init(version: Int, entries: [DataManifestEntry]) {
		self.version = version
		self.entries = entries
	}
}

public enum DataManifestError: Error {
	case unsafePath(String)
}

public func fileSHA256(at url: URL) throws -> String {
	let handle = try FileHandle(forReadingFrom: url)
	defer { try? handle.close() }
	var hasher = SHA256()
	while let chunk = try handle.read(upToCount: 64 * 1024), !chunk.isEmpty {
		hasher.update(data: chunk)
	}
	return hasher.finalize().map { String(format: "%02x", $0) }.joined()
}

public func collectDataManifest(at root: URL) throws -> DataManifest {
	let manager = FileManager.default
	var entries: [DataManifestEntry] = []
	func collect(_ url: URL, relative: String) throws {
		let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey, .isSymbolicLinkKey])
		if values.isSymbolicLink == true { throw DataManifestError.unsafePath(relative) }
		if values.isRegularFile == true {
			entries.append(DataManifestEntry(path: relative, bytes: UInt64(values.fileSize ?? 0), sha256: try fileSHA256(at: url)))
			return
		}
		guard values.isDirectory == true else { return }
		for child in try manager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
			try collect(child, relative: relative + "/" + child.lastPathComponent)
		}
	}
	for name in [".gitattributes", "Brewfiles", "Safe"] {
		let start = root.appendingPathComponent(name)
		guard manager.fileExists(atPath: start.path) else { continue }
		try collect(start, relative: name)
	}
	return DataManifest(version: 1, entries: entries.sorted { $0.path < $1.path })
}
