import BierCore
import Darwin
import Foundation

private enum CLIError: LocalizedError {
	case usage
	case invalidHost
	case missingData
	case invalidResponse

	var errorDescription: String? {
		switch self {
		case .usage:
			return "usage: bier-peer <hello|seed|compare> <host> --local <name> --identity <path> [--data <path>] [--port <port>]"
		case .invalidHost:
			return "the peer host or port is invalid"
		case .missingData:
			return "this command needs --data <path>"
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
		switch options.command {
		case "hello":
			let response = try JSONDecoder().decode(HelloResponse.self, from: try await transport.send(method: "GET", path: "/v1/peer/hello", body: Data()))
			guard response.status == "peer-ok" else { throw CLIError.invalidResponse }
			print("Bier Agent on \(options.displayHost) accepted \(options.localHost) as a peer.")
		case "seed":
			guard let data = options.data else { throw CLIError.missingData }
			try await snapshots.seedIfEmpty(from: data)
			print("Done. \(options.displayHost) now has the Bier data from \(options.localHost).")
		case "compare":
			guard let data = options.data else { throw CLIError.missingData }
			try await compare(local: data, localHost: options.localHost, remote: options.displayHost, snapshots: snapshots)
		default:
			throw CLIError.usage
		}
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
