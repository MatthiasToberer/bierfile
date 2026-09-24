import CryptoKit
import Foundation

public struct PeerPairingRequest: Codable {
	public let peer: String
	public let address: String
	public let publicKey: String
	public let proof: String

	public init(peer: String, address: String, publicKey: String, proof: String) {
		self.peer = peer
		self.address = address
		self.publicKey = publicKey
		self.proof = proof
	}
}

public struct PeerPairingResponse: Codable {
	public let status: String
	public let agent: String
	public let publicKey: String
	public let proof: String
}

private struct PeerPairingOffer: Codable {
	let version: Int
	let code: String
	let expires: Int64
	var attempts: Int
}

public enum PeerPairingError: Error {
	case unavailable
	case expired
	case rejected
	case invalidKey
}

public func peerPairingProof(code: String, peer: String, address: String, publicKey: String) -> String {
	let message = Data("bier-pair-v1\n\(peer)\n\(address)\n\(publicKey)\n".utf8)
	let key = SymmetricKey(data: Data(code.utf8))
	return HMAC<SHA256>.authenticationCode(for: message, using: key).map { String(format: "%02x", $0) }.joined()
}

public func peerPairingResponseProof(code: String, request: PeerPairingRequest, agent: String, publicKey: String) -> String {
	let message = Data("bier-pair-response-v1\n\(request.peer)\n\(request.address)\n\(request.publicKey)\n\(agent)\n\(publicKey)\n".utf8)
	let key = SymmetricKey(data: Data(code.utf8))
	return HMAC<SHA256>.authenticationCode(for: message, using: key).map { String(format: "%02x", $0) }.joined()
}

public final class PeerPairingStore {
	private let offerURL: URL
	private let addressesURL: URL
	private let signersURL: URL
	private let localKeyURL: URL
	private let peersURL: URL?
	private let lock = NSLock()

	public init(stateDirectory: URL, signersURL: URL, localKeyURL: URL, peersURL: URL? = nil) {
		offerURL = stateDirectory.appendingPathComponent("pairing-offer.json")
		addressesURL = stateDirectory.appendingPathComponent("paired-addresses")
		self.signersURL = signersURL
		self.localKeyURL = localKeyURL
		self.peersURL = peersURL
	}

	public func accept(_ request: PeerPairingRequest, agent: String) throws -> PeerPairingResponse {
		lock.lock()
		defer { lock.unlock() }
		guard validName(request.peer), validAddress(request.address), validPublicKey(request.publicKey),
			let data = try? Data(contentsOf: offerURL),
			var offer = try? JSONDecoder().decode(PeerPairingOffer.self, from: data),
			offer.version == 1 else { throw PeerPairingError.unavailable }
		guard offer.expires >= Int64(Date().timeIntervalSince1970) else {
			try? FileManager.default.removeItem(at: offerURL)
			throw PeerPairingError.expired
		}
		guard offer.attempts < 5 else { throw PeerPairingError.rejected }
		let expected = peerPairingProof(code: offer.code, peer: request.peer, address: request.address, publicKey: request.publicKey)
		guard constantTimeEqual(expected, request.proof.lowercased()) else {
			offer.attempts += 1
			try JSONEncoder().encode(offer).write(to: offerURL, options: .atomic)
			try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: offerURL.path)
			throw PeerPairingError.rejected
		}
		let localKey = try String(contentsOf: localKeyURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
		guard validPublicKey(localKey) else { throw PeerPairingError.invalidKey }
		try remember(peer: request.peer, key: request.publicKey)
		try remember(address: request.address)
		try append("\(request.peer) \(request.address)", to: addressesURL)
		try FileManager.default.removeItem(at: offerURL)
		return PeerPairingResponse(status: "paired", agent: agent, publicKey: localKey,
			proof: peerPairingResponseProof(code: offer.code, request: request, agent: agent, publicKey: localKey))
	}

	private func remember(address: String) throws {
		guard let peersURL else { return }
		let prior = (try? String(contentsOf: peersURL, encoding: .utf8)) ?? ""
		let peers = prior.split(whereSeparator: \.isNewline).map(String.init)
		guard !peers.contains(address) else { return }
		try FileManager.default.createDirectory(at: peersURL.deletingLastPathComponent(), withIntermediateDirectories: true,
			attributes: [.posixPermissions: 0o700])
		try (peers + [address]).joined(separator: "\n").appending("\n").write(to: peersURL, atomically: true, encoding: .utf8)
		try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: peersURL.path)
	}

	/// A paired Mac signs off: its key goes, so it is not trusted any
	/// more, and so do the addresses this Mac used to reach it. Those are
	/// the one it gave when pairing, its own name, and -- for pairings
	/// from before that was recorded -- any that resolves to the address
	/// the sign-off came from. Returns the addresses removed.
	@discardableResult
	public func forget(peer: String, from source: String?) throws -> [String] {
		lock.lock()
		defer { lock.unlock() }
		guard validName(peer) else { throw PeerPairingError.rejected }
		let signers = (try? String(contentsOf: signersURL, encoding: .utf8)) ?? ""
		let kept = signers.split(separator: "\n", omittingEmptySubsequences: true).filter {
			$0.split(whereSeparator: \.isWhitespace).first.map(String.init) != peer
		}
		try (kept.map(String.init).joined(separator: "\n") + (kept.isEmpty ? "" : "\n"))
			.write(to: signersURL, atomically: true, encoding: .utf8)

		let recorded = ((try? String(contentsOf: addressesURL, encoding: .utf8)) ?? "")
			.split(whereSeparator: \.isNewline).map { $0.split(separator: " ", maxSplits: 1).map(String.init) }
		var names: Set<String> = [peer, "\(peer).local"]
		for pair in recorded where pair.count == 2 && pair[0] == peer { names.insert(pair[1]) }
		let origin = source.map(normalisedAddress)
		guard let peersURL else { return [] }
		let peers = ((try? String(contentsOf: peersURL, encoding: .utf8)) ?? "").split(whereSeparator: \.isNewline).map(String.init)
		var removed: [String] = []
		let left = peers.filter { address in
			let gone = names.contains(address) || (origin.map { resolves(address, to: $0) } ?? false)
			if gone { removed.append(address) }
			return !gone
		}
		try (left.joined(separator: "\n") + (left.isEmpty ? "" : "\n")).write(to: peersURL, atomically: true, encoding: .utf8)
		let rest = recorded.filter { !($0.count == 2 && $0[0] == peer) }.map { $0.joined(separator: " ") }
		try (rest.joined(separator: "\n") + (rest.isEmpty ? "" : "\n")).write(to: addressesURL, atomically: true, encoding: .utf8)
		return removed
	}

	private func append(_ line: String, to url: URL) throws {
		let prior = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
		var lines = prior.split(whereSeparator: \.isNewline).map(String.init)
		guard !lines.contains(line) else { return }
		lines.append(line)
		try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
			attributes: [.posixPermissions: 0o700])
		try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
		try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
	}

	private func normalisedAddress(_ value: String) -> String {
		var address = value
		if let percent = address.firstIndex(of: "%") { address = String(address[..<percent]) }
		if address.hasPrefix("::ffff:") { address = String(address.dropFirst(7)) }
		return address
	}

	private func resolves(_ name: String, to address: String) -> Bool {
		if normalisedAddress(name) == address { return true }
		var hints = addrinfo()
		hints.ai_socktype = SOCK_STREAM
		var result: UnsafeMutablePointer<addrinfo>?
		guard getaddrinfo(name, nil, &hints, &result) == 0, let first = result else { return false }
		defer { freeaddrinfo(first) }
		var entry: UnsafeMutablePointer<addrinfo>? = first
		while let current = entry {
			var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
			if getnameinfo(current.pointee.ai_addr, current.pointee.ai_addrlen, &host, socklen_t(host.count),
				nil, 0, NI_NUMERICHOST) == 0, normalisedAddress(String(cString: host)) == address {
				return true
			}
			entry = current.pointee.ai_next
		}
		return false
	}

	private func remember(peer: String, key: String) throws {
		let prior = (try? String(contentsOf: signersURL, encoding: .utf8)) ?? ""
		let kept = prior.split(separator: "\n", omittingEmptySubsequences: true).filter {
			$0.split(whereSeparator: \.isWhitespace).first.map(String.init) != peer
		}
		let value = (kept.map(String.init) + ["\(peer) \(key)"]).joined(separator: "\n") + "\n"
		try value.write(to: signersURL, atomically: true, encoding: .utf8)
		try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: signersURL.path)
	}

	private func validName(_ value: String) -> Bool {
		value.range(of: "^[A-Za-z0-9][A-Za-z0-9._-]*$", options: .regularExpression) != nil
	}

	private func validAddress(_ value: String) -> Bool {
		value.range(of: "^[A-Za-z0-9][A-Za-z0-9.-]*$", options: .regularExpression) != nil
	}

	private func validPublicKey(_ value: String) -> Bool {
		guard !value.contains("\n") else { return false }
		let fields = value.split(whereSeparator: \.isWhitespace)
		guard fields.count >= 2, fields[0] == "ssh-ed25519" else { return false }
		return Data(base64Encoded: String(fields[1])) != nil
	}

	private func constantTimeEqual(_ first: String, _ second: String) -> Bool {
		let a = Array(first.utf8), b = Array(second.utf8)
		guard a.count == b.count else { return false }
		var difference: UInt8 = 0
		for index in a.indices { difference |= a[index] ^ b[index] }
		return difference == 0
	}
}
