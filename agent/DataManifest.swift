import Foundation
import CryptoKit

struct DataManifestEntry: Encodable {
	let path: String
	let bytes: UInt64
	let sha256: String
}

struct DataManifest: Encodable {
	let version = 1
	let entries: [DataManifestEntry]
}

enum DataManifestError: Error {
	case unsafePath(String)
}

func fileSHA256(at url: URL) throws -> String {
	let handle = try FileHandle(forReadingFrom: url)
	defer { try? handle.close() }
	var hasher = SHA256()
	while let chunk = try handle.read(upToCount: 64 * 1024), !chunk.isEmpty {
		hasher.update(data: chunk)
	}
	return hasher.finalize().map { String(format: "%02x", $0) }.joined()
}

func collectDataManifest(at root: URL) throws -> DataManifest {
	let manager = FileManager.default
	var entries: [DataManifestEntry] = []
	for name in [".gitattributes", "Brewfiles", "Safe"] {
		let start = root.appendingPathComponent(name)
		guard manager.fileExists(atPath: start.path) else { continue }
		let iterator = manager.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey])
		while let url = iterator?.nextObject() as? URL {
			let relative = url.path.replacingOccurrences(of: root.path + "/", with: "")
			guard relative == name || relative.hasPrefix(name + "/") else { continue }
			let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey])
			if values.isSymbolicLink == true { throw DataManifestError.unsafePath(relative) }
			guard values.isRegularFile == true else { continue }
			entries.append(DataManifestEntry(path: relative, bytes: UInt64(values.fileSize ?? 0), sha256: try fileSHA256(at: url)))
		}
	}
	return DataManifest(entries: entries.sorted { $0.path < $1.path })
}
