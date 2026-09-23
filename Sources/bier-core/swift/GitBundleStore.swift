import Foundation

public struct GitBundleDescriptor: Codable, Equatable {
	public let id: String
	public let bytes: UInt64
	public let sha256: String

	public init(id: String, bytes: UInt64, sha256: String) {
		self.id = id
		self.bytes = bytes
		self.sha256 = sha256
	}
}

public enum GitBundleStoreError: Error {
	case invalidIdentifier
	case invalidDescriptor
	case unknownTransfer
	case invalidOffset
	case incompleteTransfer
	case invalidBundle
}

private struct GitBundleImport {
	let descriptor: GitBundleDescriptor
	var received: UInt64
}

public final class GitBundleStore {
	private let repository: GitRepository
	private let directory: URL
	private let lock = NSLock()
	private var imports: [String: GitBundleImport] = [:]

	public init(repository: GitRepository, stateDirectory: URL) throws {
		self.repository = repository
		directory = stateDirectory.appendingPathComponent("repository-transfers")
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
	}

	public func beginExport() throws -> GitBundleDescriptor {
		lock.lock()
		defer { lock.unlock() }
		let id = identifier()
		let file = exportURL(id)
		try repository.exportBundle(to: file)
		let values = try file.resourceValues(forKeys: [.fileSizeKey])
		return GitBundleDescriptor(id: id, bytes: UInt64(values.fileSize ?? 0), sha256: try fileSHA256(at: file))
	}

	public func readExport(_ id: String, offset: UInt64, length: Int) throws -> Data {
		lock.lock()
		defer { lock.unlock() }
		try validate(id)
		guard length >= 0, length <= maxSnapshotChunkBytes else { throw GitBundleStoreError.invalidOffset }
		let file = exportURL(id)
		guard FileManager.default.fileExists(atPath: file.path) else { throw GitBundleStoreError.unknownTransfer }
		let size = UInt64(try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
		guard offset <= size else { throw GitBundleStoreError.invalidOffset }
		let handle = try FileHandle(forReadingFrom: file)
		defer { try? handle.close() }
		try handle.seek(toOffset: offset)
		return try handle.read(upToCount: min(length, Int(size - offset))) ?? Data()
	}

	public func beginImport(_ descriptor: GitBundleDescriptor) throws {
		lock.lock()
		defer { lock.unlock() }
		try validate(descriptor.id)
		guard descriptor.bytes <= 4_294_967_296,
			descriptor.sha256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
			throw GitBundleStoreError.invalidDescriptor
		}
		let file = importURL(descriptor.id)
		try? FileManager.default.removeItem(at: file)
		guard FileManager.default.createFile(atPath: file.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
			throw GitBundleStoreError.invalidDescriptor
		}
		imports[descriptor.id] = GitBundleImport(descriptor: descriptor, received: 0)
	}

	public func putImport(_ id: String, offset: UInt64, data: Data) throws {
		lock.lock()
		defer { lock.unlock() }
		try validate(id)
		guard data.count <= maxSnapshotChunkBytes, var session = imports[id], offset == session.received,
			UInt64(data.count) <= session.descriptor.bytes - session.received else { throw GitBundleStoreError.invalidOffset }
		let handle = try FileHandle(forWritingTo: importURL(id))
		defer { try? handle.close() }
		try handle.seek(toOffset: offset)
		try handle.write(contentsOf: data)
		session.received += UInt64(data.count)
		imports[id] = session
	}

	public func commitImport(_ id: String) throws {
		lock.lock()
		defer { lock.unlock() }
		try validate(id)
		guard let session = imports[id], session.received == session.descriptor.bytes else {
			throw GitBundleStoreError.incompleteTransfer
		}
		let file = importURL(id)
		guard try fileSHA256(at: file) == session.descriptor.sha256 else { throw GitBundleStoreError.invalidBundle }
		try repository.importBundle(from: file)
		try FileManager.default.removeItem(at: file)
		imports.removeValue(forKey: id)
	}

	private func identifier() -> String {
		UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
	}

	private func validate(_ id: String) throws {
		guard id.range(of: "^[a-z0-9]{32}$", options: .regularExpression) != nil else {
			throw GitBundleStoreError.invalidIdentifier
		}
	}

	private func exportURL(_ id: String) -> URL { directory.appendingPathComponent("export-\(id).bundle") }
	private func importURL(_ id: String) -> URL { directory.appendingPathComponent("import-\(id).bundle") }
}
