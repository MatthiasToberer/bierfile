import Foundation

public enum PeerSnapshotClientError: Error {
	case invalidManifest
	case invalidResponse
	case peerNotEmpty
	case duplicatePath
	case incompleteChunk
}

private struct SnapshotBeginEnvelope: Encodable {
	let id: String
	let manifest: DataManifest
}

private struct SnapshotPutEnvelope: Encodable {
	let id: String
	let path: String
	let offset: UInt64
	let data: Data
}

private struct SnapshotCommitEnvelope: Encodable {
	let id: String
}

private struct DataReadEnvelope: Encodable {
	let path: String
	let offset: UInt64
	let length: Int
}

private struct StatusEnvelope: Decodable {
	let status: String
}

public struct PeerSnapshotClient<Transport: PeerTransport> {
	public let transport: Transport

	public init(transport: Transport) {
		self.transport = transport
	}

	public func manifest() async throws -> DataManifest {
		let data = try await transport.send(method: "GET", path: "/v1/peer/manifest", body: Data())
		let manifest = try JSONDecoder().decode(DataManifest.self, from: data)
		guard manifest.version == 1 else { throw PeerSnapshotClientError.invalidManifest }
		try validate(manifest)
		return manifest
	}

	public func fetch(to destination: URL) async throws {
		let manifest = try await manifest()
		let manager = FileManager.default
		try manager.createDirectory(at: destination, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
		var paths = Set<String>()
		for entry in manifest.entries {
			guard paths.insert(entry.path).inserted else { throw PeerSnapshotClientError.duplicatePath }
			let target = destination.appendingPathComponent(entry.path)
			try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
			guard manager.createFile(atPath: target.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
				throw PeerSnapshotClientError.duplicatePath
			}
			let handle = try FileHandle(forWritingTo: target)
			do {
				var offset: UInt64 = 0
				while offset < entry.bytes {
					let length = Int(min(UInt64(maxSnapshotChunkBytes), entry.bytes - offset))
					let body = try encode(DataReadEnvelope(path: entry.path, offset: offset, length: length))
					let chunk = try await transport.send(method: "POST", path: "/v1/peer/data/read", body: body)
					guard chunk.count == length else { throw PeerSnapshotClientError.incompleteChunk }
					try handle.write(contentsOf: chunk)
					offset += UInt64(chunk.count)
				}
				try handle.close()
			} catch {
				try? handle.close()
				throw error
			}
			guard try fileSHA256(at: target) == entry.sha256 else { throw PeerSnapshotClientError.invalidManifest }
		}
	}

	public func seedIfEmpty(from source: URL) async throws {
		try await seed(from: source, acceptingPristine: false)
	}

	public func seedIfPristine(from source: URL) async throws {
		try await seed(from: source, acceptingPristine: true)
	}

	private func seed(from source: URL, acceptingPristine: Bool) async throws {
		let remote = try await manifest()
		let pristine = remote.entries.allSatisfy {
			$0.path == ".gitattributes" || ($0.path == "Brewfiles/main" && $0.bytes == 0)
		}
		guard remote.entries.isEmpty || (acceptingPristine && pristine) else { throw PeerSnapshotClientError.peerNotEmpty }
		let manifest = try collectDataManifest(at: source)
		try validate(manifest)
		let id = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
		try expect("snapshot-ready", from: try await transport.send(
			method: "POST",
			path: "/v1/peer/snapshot/begin",
			body: try encode(SnapshotBeginEnvelope(id: id, manifest: manifest))
		))
		for entry in manifest.entries {
			let handle = try FileHandle(forReadingFrom: source.appendingPathComponent(entry.path))
			do {
				var offset: UInt64 = 0
				var first = true
				while offset < entry.bytes || first {
					let chunk = try handle.read(upToCount: maxSnapshotChunkBytes) ?? Data()
					guard entry.bytes == 0 || !chunk.isEmpty else { throw PeerSnapshotClientError.incompleteChunk }
					let body = try encode(SnapshotPutEnvelope(id: id, path: entry.path, offset: offset, data: chunk))
					try expect("snapshot-staged", from: try await transport.send(method: "POST", path: "/v1/peer/snapshot/put", body: body))
					offset += UInt64(chunk.count)
					first = false
				}
				try handle.close()
			} catch {
				try? handle.close()
				throw error
			}
		}
		try expect("snapshot-committed", from: try await transport.send(
			method: "POST",
			path: "/v1/peer/snapshot/commit",
			body: try encode(SnapshotCommitEnvelope(id: id))
		))
	}

	private func validate(_ manifest: DataManifest) throws {
		guard manifest.entries.count <= 10_000 else { throw PeerSnapshotClientError.invalidManifest }
		var paths = Set<String>()
		for entry in manifest.entries {
			guard validDataPath(entry.path), entry.bytes <= 1_073_741_824,
				entry.sha256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil,
				paths.insert(entry.path).inserted else { throw PeerSnapshotClientError.invalidManifest }
		}
	}

	private func encode<Value: Encodable>(_ value: Value) throws -> Data {
		let encoder = JSONEncoder()
		encoder.outputFormatting = .withoutEscapingSlashes
		return try encoder.encode(value)
	}

	private func expect(_ status: String, from response: Data) throws {
		guard try JSONDecoder().decode(StatusEnvelope.self, from: response).status == status else {
			throw PeerSnapshotClientError.invalidResponse
		}
	}
}
