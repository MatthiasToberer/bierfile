import Foundation

public enum PeerClientError: Error {
	case invalidConfiguration
	case signingFailed
	case rejected(Int)
}

public protocol PeerTransport {
	func send(method: String, path: String, body: Data) async throws -> Data
}

public struct PeerRequest: Equatable {
	public let method: String
	public let path: String
	public let peer: String
	public let time: String
	public let nonce: String
	public let body: Data

	public init(method: String, path: String, peer: String, time: String, nonce: String, body: Data) {
		self.method = method
		self.path = path
		self.peer = peer
		self.time = time
		self.nonce = nonce
		self.body = body
	}

	public var canonicalData: Data {
		Data("\(method)\n\(path)\n\(peer)\n\(time)\n\(nonce)\n\(sha256Hex(body))\n".utf8)
	}
}

public struct PeerClient: PeerTransport {
	public let baseURL: URL
	public let peerName: String
	public let identity: URL

	public init(baseURL: URL, peerName: String, identity: URL) throws {
		guard baseURL.scheme == "http", baseURL.host != nil,
			peerName.range(of: "^[A-Za-z0-9][A-Za-z0-9._-]*$", options: .regularExpression) != nil,
			FileManager.default.isReadableFile(atPath: identity.path) else {
			throw PeerClientError.invalidConfiguration
		}
		self.baseURL = baseURL
		self.peerName = peerName
		self.identity = identity
	}

	public func send(method: String, path: String, body: Data = Data()) async throws -> Data {
		let time = ISO8601DateFormatter().string(from: Date())
		let nonce = UUID().uuidString.lowercased()
		let peerRequest = PeerRequest(method: method, path: path, peer: peerName, time: time, nonce: nonce, body: body)
		let signature = try sign(peerRequest.canonicalData)
		guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else { throw PeerClientError.invalidConfiguration }
		var request = URLRequest(url: url, timeoutInterval: 20)
		request.httpMethod = method
		request.httpBody = body
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.setValue(peerName, forHTTPHeaderField: "X-Bier-Peer")
		request.setValue(time, forHTTPHeaderField: "X-Bier-Time")
		request.setValue(nonce, forHTTPHeaderField: "X-Bier-Nonce")
		request.setValue(signature.base64EncodedString(), forHTTPHeaderField: "X-Bier-Signature")
		let (data, response) = try await URLSession.shared.data(for: request)
		guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
			throw PeerClientError.rejected((response as? HTTPURLResponse)?.statusCode ?? 0)
		}
		return data
	}

	private func sign(_ data: Data) throws -> Data {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent("bier-peer-sign-\(UUID().uuidString)")
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
		defer { try? FileManager.default.removeItem(at: directory) }
		let request = directory.appendingPathComponent("request")
		try data.write(to: request, options: .atomic)
		let process = Process()
		process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")
		process.arguments = ["-q", "-Y", "sign", "-f", identity.path, "-n", "bier-peer", request.path]
		process.standardOutput = FileHandle.nullDevice
		process.standardError = FileHandle.nullDevice
		try process.run()
		process.waitUntilExit()
		guard process.terminationStatus == 0 else { throw PeerClientError.signingFailed }
		return try Data(contentsOf: URL(fileURLWithPath: request.path + ".sig"))
	}
}
