import CryptoKit
import Foundation

public struct PeerPairingRequest: Codable {
	public let peer: String
	public let publicKey: String
	public let proof: String

	public init(peer: String, publicKey: String, proof: String) {
		self.peer = peer
		self.publicKey = publicKey
		self.proof = proof
	}
}

public struct PeerPairingResponse: Codable {
	public let status: String
	public let agent: String
	public let publicKey: String
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

public func peerPairingProof(code: String, peer: String, publicKey: String) -> String {
	let message = Data("bier-pair-v1\n\(peer)\n\(publicKey)\n".utf8)
	let key = SymmetricKey(data: Data(code.utf8))
	return HMAC<SHA256>.authenticationCode(for: message, using: key).map { String(format: "%02x", $0) }.joined()
}

public final class PeerPairingStore {
	private let offerURL: URL
	private let signersURL: URL
	private let localKeyURL: URL
	private let lock = NSLock()

	public init(stateDirectory: URL, signersURL: URL, localKeyURL: URL) {
		offerURL = stateDirectory.appendingPathComponent("pairing-offer.json")
		self.signersURL = signersURL
		self.localKeyURL = localKeyURL
	}

	public func accept(_ request: PeerPairingRequest, agent: String) throws -> PeerPairingResponse {
		lock.lock()
		defer { lock.unlock() }
		guard validName(request.peer), validPublicKey(request.publicKey),
			let data = try? Data(contentsOf: offerURL),
			var offer = try? JSONDecoder().decode(PeerPairingOffer.self, from: data),
			offer.version == 1 else { throw PeerPairingError.unavailable }
		guard offer.expires >= Int64(Date().timeIntervalSince1970) else {
			try? FileManager.default.removeItem(at: offerURL)
			throw PeerPairingError.expired
		}
		guard offer.attempts < 5 else { throw PeerPairingError.rejected }
		let expected = peerPairingProof(code: offer.code, peer: request.peer, publicKey: request.publicKey)
		guard constantTimeEqual(expected, request.proof.lowercased()) else {
			offer.attempts += 1
			try JSONEncoder().encode(offer).write(to: offerURL, options: .atomic)
			throw PeerPairingError.rejected
		}
		let localKey = try String(contentsOf: localKeyURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
		guard validPublicKey(localKey) else { throw PeerPairingError.invalidKey }
		try remember(peer: request.peer, key: request.publicKey)
		try FileManager.default.removeItem(at: offerURL)
		return PeerPairingResponse(status: "paired", agent: agent, publicKey: localKey)
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
