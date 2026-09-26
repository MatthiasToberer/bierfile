#if BIER_PACKAGE
import BierCore
#endif
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
			return "usage: bier-peer <hello|name|introduce|confirm|status|admin-pair|admin-run|pair|leave|seed|seed-if-empty|seed-if-pristine|compare|sync> <host> --local <name> --identity <path> [--data <path>] [--address <own-host>] [--code-file <path>] [--peer-signers <path>] [--port <port>] [--via <host>] [--body <path>]"
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
	let address: String
	let identity: URL
	let data: URL?
	let codeFile: URL?
	let peerSigners: URL?
	let port: Int
	let via: String?
	let body: URL?

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
		address = values["--address"] ?? (local.contains(".") ? local : "\(local).local")
		identity = URL(fileURLWithPath: identityPath)
		data = values["--data"].map(URL.init(fileURLWithPath:))
		codeFile = values["--code-file"].map(URL.init(fileURLWithPath:))
		peerSigners = values["--peer-signers"].map(URL.init(fileURLWithPath:))
		port = Int(values["--port"] ?? "53991") ?? 0
		// Where to connect when that is not the peer itself: the local end
		// of an SSH tunnel to it.
		via = values["--via"]
		body = values["--body"].map(URL.init(fileURLWithPath:))
		guard port > 0 && port <= 65_535 else { throw CLIError.invalidHost }
	}

	var baseURL: URL {
		get throws {
			let networkHost = via ?? displayHost.split(separator: "@", maxSplits: 1).last.map(String.init) ?? displayHost
			guard networkHost.range(of: "^[A-Za-z0-9][A-Za-z0-9.:-]*$", options: .regularExpression) != nil,
				let url = URL(string: "http://\(networkHost):\(port)") else { throw CLIError.invalidHost }
			return url
		}
	}
}

private struct RunResponse: Decodable {
	let status: Int32
	let out: String
	let err: String
}

private struct HelloResponse: Decodable {
	let status: String
	let agent: String?
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
		if CommandLine.arguments.dropFirst().first == "view" {
			try view(Array(CommandLine.arguments.dropFirst(2)))
			return
		}
		let options = try Options(arguments: Array(CommandLine.arguments.dropFirst()))
		let transport = try PeerClient(baseURL: options.baseURL, peerName: options.localHost, identity: options.identity)
		let snapshots = PeerSnapshotClient(transport: transport)
		let repositories = PeerRepositoryClient(transport: transport)
		switch options.command {
		case "hello":
			let response = try JSONDecoder().decode(HelloResponse.self, from: try await transport.send(method: "GET", path: "/v1/peer/hello", body: Data()))
			guard response.status == "peer-ok" else { throw CLIError.invalidResponse }
			print("Bier Agent on \(options.displayHost) accepted \(options.localHost) as a peer.")
		case "name":
			// The name the other Mac signs with, for introducing it.
			let response = try JSONDecoder().decode(HelloResponse.self, from: try await transport.send(method: "GET", path: "/v1/peer/hello", body: Data()))
			guard response.status == "peer-ok", let agent = response.agent else { throw CLIError.invalidResponse }
			print(agent)
		case "introduce":
			guard let body = options.body else { throw CLIError.usage }
			let response = try JSONDecoder().decode(HelloResponse.self, from: try await transport.send(method: "POST", path: "/v1/peer/introduce", body: Data(contentsOf: body)))
			guard response.status == "introduced" else { throw CLIError.invalidResponse }
		case "status", "admin-run":
			// status: how another Mac is doing; admin-run: bier on this Mac,
			// as Bierkasten runs it (--body holds {"args": [...]}).
			let data = options.command == "status"
				? try await transport.send(method: "GET", path: "/v1/peer/status", body: Data())
				: try await transport.send(method: "POST", path: "/v1/admin/run", body: Data(contentsOf: options.body ?? URL(fileURLWithPath: "/dev/null")))
			let result = try JSONDecoder().decode(RunResponse.self, from: data)
			FileHandle.standardOutput.write(Data(result.out.utf8))
			FileHandle.standardError.write(Data(result.err.utf8))
			exit(result.status)
		case "admin-pair":
			try await pair(options, path: "v1/admin/pair")
		case "confirm":
			let response = try JSONDecoder().decode(HelloResponse.self, from: try await transport.send(method: "POST", path: "/v1/peer/confirm", body: Data()))
			guard response.status == "confirmed" else { throw CLIError.invalidResponse }
		case "pair":
			try await pair(options)
		case "leave":
			let response = try JSONDecoder().decode(HelloResponse.self, from: try await transport.send(method: "POST", path: "/v1/peer/leave", body: Data()))
			guard response.status == "peer-left" else { throw CLIError.invalidResponse }
			print("Signed off at \(options.displayHost): it forgot \(options.localHost).")
		case "seed", "seed-if-empty", "seed-if-pristine":
			guard let data = options.data else { throw CLIError.missingData }
			do {
				if options.command == "seed-if-pristine" {
					try await snapshots.seedIfPristine(from: data)
				} else {
					try await snapshots.seedIfEmpty(from: data)
				}
			} catch PeerSnapshotClientError.peerNotEmpty where options.command != "seed" {
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

	private static func pair(_ options: Options, path: String = "v1/pair") async throws {
		guard let codeFile = options.codeFile, let signers = options.peerSigners else { throw CLIError.missingPairing }
		let code = try String(contentsOf: codeFile, encoding: .utf8)
			.lowercased().filter { $0.isHexDigit }
		guard code.count == 32 else { throw CLIError.missingPairing }
		let publicKey = try String(contentsOf: URL(fileURLWithPath: options.identity.path + ".pub"), encoding: .utf8)
			.trimmingCharacters(in: .whitespacesAndNewlines)
		let address = options.address
		guard address.range(of: "^([A-Za-z0-9._-]+@)?[A-Za-z0-9][A-Za-z0-9.-]*\\z", options: .regularExpression) != nil else {
			throw CLIError.invalidHost
		}
		let pairing = PeerPairingRequest(peer: options.localHost, address: address, publicKey: publicKey,
			proof: peerPairingProof(code: code, peer: options.localHost, address: address, publicKey: publicKey))
		let encoder = JSONEncoder()
		encoder.outputFormatting = .withoutEscapingSlashes
		var request = URLRequest(url: try options.baseURL.appendingPathComponent(path))
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
			result.publicKey.hasPrefix("ssh-ed25519 "), !result.publicKey.contains("\n"),
			result.proof == peerPairingResponseProof(code: code, request: pairing, agent: result.agent, publicKey: result.publicKey)
		else { throw CLIError.invalidResponse }
		try remember(peer: result.agent, key: result.publicKey, in: signers)
		print("Paired \(options.localHost) with \(result.agent) on \(options.displayHost).")
	}

	/// view <page> [<argument>] --report <file> --fleet <directory> [--now
	/// <seconds>]: a page of Bierkasten as JSON, from bier report and the
	/// fleet cache; --now fixes the time, for samples that stay the same.
	private static func view(_ arguments: [String]) throws {
		var words: [String] = []
		var values: [String: String] = [:]
		var index = 0
		while index < arguments.count {
			if arguments[index].hasPrefix("--") {
				guard index + 1 < arguments.count else { throw CLIError.usage }
				values[arguments[index]] = arguments[index + 1]
				index += 2
			} else {
				words.append(arguments[index])
				index += 1
			}
		}
		guard let reportPath = values["--report"], (1...2).contains(words.count) else { throw CLIError.usage }
		let report = try String(contentsOfFile: reportPath, encoding: .utf8)
		var fleet: [String] = []
		if let directory = values["--fleet"],
			let names = try? FileManager.default.contentsOfDirectory(atPath: directory) {
			for name in names.sorted() where !name.hasPrefix(".") && !name.contains(".tmp") {
				if let text = try? String(contentsOfFile: directory + "/" + name, encoding: .utf8) { fleet.append(text) }
			}
		}
		do {
			let now = values["--now"].flatMap(Int.init) ?? Int(Date().timeIntervalSince1970)
			let data = try FleetView(report: report, fleet: fleet, now: now).json(words[0], words.count > 1 ? words[1] : nil)
			FileHandle.standardOutput.write(data + Data("\n".utf8))
		} catch let error as FleetViewError {
			fputs("bier: \(error.description)\n", stderr)
			exit(1)
		}
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
