import Foundation

@main
struct PairingTest {
	static func main() throws {
		let arguments = Array(CommandLine.arguments.dropFirst())
		guard arguments.count == 2 else { throw PeerPairingError.invalidKey }
		let localKey = try String(contentsOfFile: arguments[0], encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
		let remoteKey = try String(contentsOfFile: arguments[1], encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
		let manager = FileManager.default
		let root = manager.temporaryDirectory.appendingPathComponent("bier-pairing-test-\(UUID().uuidString)")
		defer { try? manager.removeItem(at: root) }
		try manager.createDirectory(at: root, withIntermediateDirectories: true)
		let signers = root.appendingPathComponent("peer-signers")
		let localKeyURL = root.appendingPathComponent("local.pub")
		try localKey.write(to: localKeyURL, atomically: true, encoding: .utf8)
		let code = "0123456789abcdef0123456789abcdef"
		let expiry = Int64(Date().timeIntervalSince1970) + 600
		try Data("{\"version\":1,\"code\":\"\(code)\",\"expires\":\(expiry),\"attempts\":0}".utf8)
			.write(to: root.appendingPathComponent("pairing-offer.json"), options: .atomic)
		let store = PeerPairingStore(stateDirectory: root, signersURL: signers, localKeyURL: localKeyURL)
		let request = PeerPairingRequest(peer: "controller", publicKey: remoteKey, proof: peerPairingProof(code: code, peer: "controller", publicKey: remoteKey))
		let response = try store.accept(request, agent: "target")
		guard response.status == "paired", response.agent == "target", response.publicKey == localKey else {
			throw PeerPairingError.rejected
		}
		guard try String(contentsOf: signers, encoding: .utf8).hasPrefix("controller ssh-ed25519 "),
			!manager.fileExists(atPath: root.appendingPathComponent("pairing-offer.json").path) else {
			throw PeerPairingError.rejected
		}
		do {
			_ = try store.accept(request, agent: "target")
			throw PeerPairingError.rejected
		} catch PeerPairingError.unavailable {}
		print("Swift Bier pairing tests passed.")
	}
}
