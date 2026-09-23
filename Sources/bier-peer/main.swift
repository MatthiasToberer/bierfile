import BierCore
import Darwin
import Foundation

private enum CLIError: LocalizedError {
	case usage
	case invalidHost
	case missingData
	case missingPairing
	case invalidResponse

	var errorDescription: String? {
		switch self {
		case .usage:
			return "usage: bier-peer <hello|pair|seed|seed-if-empty|compare|sync> <host> --local <name> --identity <path> [--data <path>] [--code-file <path>] [--peer-signers <path>] [--port <port>]"
		case .invalidHost:
			return "the peer host or port is invalid"
		case .missingData:
			return "this command needs --data <path>"
		case .missingPairing:
			return "pairing needs --code-file and --peer-signers"
		case .invalidResponse:
			return "the Bier Agent returned an invalid response"
		}
	}
}

private struct Options {
	let command: String
	let displayHost: String
	let localHost: String
	let identity: URL
	let data: URL?
	let codeFile: URL?
	let peerSigners: URL?
	let port: Int

	init(arguments: [String]) throws {
		guard arguments.count >= 2 else { throw CLIError.usage }
		command = arguments[0]
		displayHost = arguments[1]
		var values: [String: String] = [:]
		var index = 2
		while index < arguments.count {
			guard arguments[index].hasPrefix("--"), index + 1 < arguments.count else { throw CLIError.usage }
			values[arguments[index]] = arguments[index + 1]
			index += 2
		}
		guard let local = values["--local"], let identityPath = values["--identity"] else { throw CLIError.usage }
		localHost = local
		identity = URL(fileURLWithPath: identityPath)
		data = values["--data"].map(URL.init(fileURLWithPath:))
		codeFile = values["--code-file"].map(URL.init(fileURLWithPath:))
		peerSigners = values["--peer-signers"].map(URL.init(fileURLWithPath:))
		port = Int(values["--port"] ?? "53991") ?? 0
		guard port > 0 && port <= 65_535 else { throw CLIError.invalidHost }
	}

	var baseURL: URL {
		get throws {
			let networkHost = displayHost.split(separator: "@", maxSplits: 1).last.map(String.init) ?? displayHost
			guard networkHost.range(of: "^[A-Za-z0-9][A-Za-z0-9.:-]*$", options: .regularExpression) != nil,
				let url = URL(string: "http://\(networkHost):\(port)") else { throw CLIError.invalidHost }
			return url
		}
	}
}

private struct HelloResponse: Decodable {
	let status: String
}

@main
private enum BierPeerCLI {
	static func main() async {
		do {
			try await run()
		} catch PeerSnapshotClientError.peerNotEmpty {
			fputs("bier: the peer data store is not empty; refusing to replace it\n", stderr)
			exit(1)
		} catch {
			fputs("bier: \(error.localizedDescription)\n", stderr)
			exit(1)
		}
	}

	private static func run() async throws {
		let options = try Options(arguments: Array(CommandLine.arguments.dropFirst()))
		let transport = try PeerClient(baseURL: options.baseURL, peerName: options.localHost, identity: options.identity)
		let snapshots = PeerSnapshotClient(transport: transport)
		let repositories = PeerRepositoryClient(transport: transport)
		switch options.command {
		case "hello":
			let response = try JSONDecoder().decode(HelloResponse.self, from: try await transport.send(method: "GET", path: "/v1/peer/hello", body: Data()))
			guard response.status == "peer-ok" else { throw CLIError.invalidResponse }
			print("Bier Agent on \(options.displayHost) accepted \(options.localHost) as a peer.")
		case "pair":
			try await pair(options)
		case "seed", "seed-if-empty":
			guard let data = options.data else { throw CLIError.missingData }
			do {
				try await snapshots.seedIfEmpty(from: data)
			} catch PeerSnapshotClientError.peerNotEmpty where options.command == "seed-if-empty" {
				if try await snapshots.manifest().entries == collectDataManifest(at: data).entries {
					try await repositories.push(from: GitRepository(root: data))
				}
				print("Existing peer data was kept unchanged.")
				return
			}
			try await repositories.push(from: GitRepository(root: data))
			print("Done. \(options.displayHost) now has the Bier data from \(options.localHost).")
		case "compare":
			guard let data = options.data else { throw CLIError.missingData }
			try await compare(local: data, localHost: options.localHost, remote: options.displayHost, snapshots: snapshots)
		case "sync":
			guard let data = options.data else { throw CLIError.missingData }
			try await repositories.synchronize(GitRepository(root: data))
			print("Bier data is in sync on \(options.localHost) and \(options.displayHost).")
		default:
			throw CLIError.usage
		}
	}

	private static func pair(_ options: Options) async throws {
		guard let codeFile = options.codeFile, let signers = options.peerSigners else { throw CLIError.missingPairing }
		let code = try String(contentsOf: codeFile, encoding: .utf8)
			.lowercased().filter { $0.isHexDigit }
		guard code.count == 32 else { throw CLIError.missingPairing }
		let publicKey = try String(contentsOf: URL(fileURLWithPath: options.identity.path + ".pub"), encoding: .utf8)
			.trimmingCharacters(in: .whitespacesAndNewlines)
		let pairing = PeerPairingRequest(peer: options.localHost, publicKey: publicKey, proof: peerPairingProof(code: code, peer: options.localHost, publicKey: publicKey))
		let encoder = JSONEncoder()
		encoder.outputFormatting = .withoutEscapingSlashes
		var request = URLRequest(url: try options.baseURL.appendingPathComponent("v1/pair"))
		request.httpMethod = "POST"
		request.httpBody = try encoder.encode(pairing)
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		let (data, rawResponse) = try await URLSession.shared.data(for: request)
		guard let response = rawResponse as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
			throw PeerPairingError.rejected
		}
		let result = try JSONDecoder().decode(PeerPairingResponse.self, from: data)
		guard result.status == "paired",
			result.agent.range(of: "^[A-Za-z0-9][A-Za-z0-9._-]*$", options: .regularExpression) != nil,
			result.publicKey.hasPrefix("ssh-ed25519 "), !result.publicKey.contains("\n") else { throw CLIError.invalidResponse }
		try remember(peer: result.agent, key: result.publicKey, in: signers)
		print("Paired \(options.localHost) with \(result.agent) on \(options.displayHost).")
	}

	private static func remember(peer: String, key: String, in file: URL) throws {
		let prior = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
		let kept = prior.split(separator: "\n", omittingEmptySubsequences: true).filter {
			$0.split(whereSeparator: \.isWhitespace).first.map(String.init) != peer
		}
		let value = (kept.map(String.init) + ["\(peer) \(key)"]).joined(separator: "\n") + "\n"
		try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
		try value.write(to: file, atomically: true, encoding: .utf8)
		try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
	}

	private static func compare(local: URL, localHost: String, remote: String, snapshots: PeerSnapshotClient<PeerClient>) async throws {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent("bier-peer-compare-\(UUID().uuidString)")
		defer { try? FileManager.default.removeItem(at: directory) }
		try await snapshots.fetch(to: directory)
		let localEntries = Dictionary(uniqueKeysWithValues: try collectDataManifest(at: local).entries.map { ($0.path, $0) })
		let remoteEntries = Dictionary(uniqueKeysWithValues: try collectDataManifest(at: directory).entries.map { ($0.path, $0) })
		let paths = Set(localEntries.keys).union(remoteEntries.keys).sorted()
		let differences = paths.filter { localEntries[$0] != remoteEntries[$0] }
		if differences.isEmpty {
			print("Bier data is identical on \(localHost) and \(remote).")
			return
		}
		print("Data differs:")
		for path in differences { print("  \(path)") }
		print("\(differences.count) data file(s) differ. Nothing was changed.")
	}
}
