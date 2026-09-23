import Foundation

private struct RepositoryReadEnvelope: Encodable {
	let id: String
	let offset: UInt64
	let length: Int
}

private struct RepositoryPutEnvelope: Encodable {
	let id: String
	let offset: UInt64
	let data: Data
}

private struct RepositoryCommitEnvelope: Encodable {
	let id: String
}

public struct PeerRepositoryClient<Transport: PeerTransport> {
	public let transport: Transport

	public init(transport: Transport) {
		self.transport = transport
	}

	public func pull(into repository: GitRepository) async throws {
		let bundle = FileManager.default.temporaryDirectory.appendingPathComponent("bier-pull-\(UUID().uuidString).bundle")
		defer { try? FileManager.default.removeItem(at: bundle) }
		let descriptor = try JSONDecoder().decode(GitBundleDescriptor.self, from: try await transport.send(method: "POST", path: "/v1/peer/repository/export", body: Data()))
		try validate(descriptor)
		guard FileManager.default.createFile(atPath: bundle.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
			throw PeerSnapshotClientError.invalidResponse
		}
		let handle = try FileHandle(forWritingTo: bundle)
		do {
			var offset: UInt64 = 0
			while offset < descriptor.bytes {
				let length = Int(min(UInt64(maxSnapshotChunkBytes), descriptor.bytes - offset))
				let body = try encode(RepositoryReadEnvelope(id: descriptor.id, offset: offset, length: length))
				let chunk = try await transport.send(method: "POST", path: "/v1/peer/repository/export/read", body: body)
				guard chunk.count == length else { throw PeerSnapshotClientError.incompleteChunk }
				try handle.write(contentsOf: chunk)
				offset += UInt64(chunk.count)
			}
			try handle.close()
		} catch {
			try? handle.close()
			throw error
		}
		guard try fileSHA256(at: bundle) == descriptor.sha256 else { throw PeerSnapshotClientError.invalidManifest }
		try repository.importBundle(from: bundle)
	}

	public func push(from repository: GitRepository) async throws {
		let bundle = FileManager.default.temporaryDirectory.appendingPathComponent("bier-push-\(UUID().uuidString).bundle")
		defer { try? FileManager.default.removeItem(at: bundle) }
		try repository.exportBundle(to: bundle)
		let bytes = UInt64(try bundle.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
		let descriptor = GitBundleDescriptor(
			id: UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
			bytes: bytes,
			sha256: try fileSHA256(at: bundle)
		)
		try expect("repository-ready", from: try await transport.send(method: "POST", path: "/v1/peer/repository/import/begin", body: try encode(descriptor)))
		let handle = try FileHandle(forReadingFrom: bundle)
		do {
			var offset: UInt64 = 0
			while offset < bytes {
				let chunk = try handle.read(upToCount: maxSnapshotChunkBytes) ?? Data()
				guard !chunk.isEmpty else { throw PeerSnapshotClientError.incompleteChunk }
				let body = try encode(RepositoryPutEnvelope(id: descriptor.id, offset: offset, data: chunk))
				try expect("repository-staged", from: try await transport.send(method: "POST", path: "/v1/peer/repository/import/put", body: body))
				offset += UInt64(chunk.count)
			}
			try handle.close()
		} catch {
			try? handle.close()
			throw error
		}
		try expect("repository-committed", from: try await transport.send(method: "POST", path: "/v1/peer/repository/import/commit", body: try encode(RepositoryCommitEnvelope(id: descriptor.id))))
	}

	private func validate(_ descriptor: GitBundleDescriptor) throws {
		guard descriptor.id.range(of: "^[a-z0-9]{32}$", options: .regularExpression) != nil,
			descriptor.bytes <= 4_294_967_296,
			descriptor.sha256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
			throw PeerSnapshotClientError.invalidResponse
		}
	}

	private func encode<Value: Encodable>(_ value: Value) throws -> Data {
		let encoder = JSONEncoder()
		encoder.outputFormatting = .withoutEscapingSlashes
		return try encoder.encode(value)
	}

	private func expect(_ status: String, from response: Data) throws {
		guard let object = try JSONSerialization.jsonObject(with: response) as? [String: String], object["status"] == status else {
			throw PeerSnapshotClientError.invalidResponse
		}
	}
}
