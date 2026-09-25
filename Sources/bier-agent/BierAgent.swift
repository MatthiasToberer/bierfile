import Foundation
import Network

#if BIER_PACKAGE
import BierCore
let agentVersion = "dev"
#endif

let maxRequestBytes = 64 * 1024
let maxPeerRequestAge: TimeInterval = 5 * 60

struct SnapshotBeginRequest: Decodable {
	let id: String
	let manifest: DataManifest
}

struct SnapshotPutRequest: Decodable {
	let id: String
	let path: String
	let offset: UInt64
	let data: Data
}

struct SnapshotCommitRequest: Decodable {
	let id: String
}

struct DataReadRequest: Decodable {
	let path: String
	let offset: UInt64
	let length: Int
}

struct BundleReadRequest: Decodable {
	let id: String
	let offset: UInt64
	let length: Int
}

// Bierkasten manages this Mac through the agent, and the agent runs bier
// for it: the logic stays in one place. Only these commands may run --
// the first words must match -- and nothing asks: stdin is empty.
let adminCommands: [[String]] = [
	["report"], ["fleet"], ["state"], ["sync"], ["brewmaster"], ["status"], ["list"],
	["peer", "pending"], ["peer", "accept"], ["peer", "reject"], ["peer", "list"], ["peer", "pair"],
	["add"], ["install"], ["uninstall"], ["prune", "--yes"], ["take"],
	["vault", "add"], ["vault", "forget"], ["vault", "resolve"], ["vault", "group"], ["share"],
]

struct AdminRunRequest: Decodable {
	let args: [String]
}

struct AdminRunResponse: Encodable {
	let status: Int32
	let out: String
	let err: String
}

func runBier(_ bier: String, _ args: [String]) -> AdminRunResponse {
	let process = Process()
	process.executableURL = URL(fileURLWithPath: bier)
	process.arguments = args
	var environment = ProcessInfo.processInfo.environment
	// bier's own bin first, as in a terminal set up by the installer.
	let own = URL(fileURLWithPath: bier).deletingLastPathComponent().path
	environment["PATH"] = "\(own):/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
	process.environment = environment
	process.standardInput = FileHandle.nullDevice
	let out = Pipe(), err = Pipe()
	process.standardOutput = out
	process.standardError = err
	do { try process.run() } catch { return AdminRunResponse(status: 127, out: "", err: "cannot run bier at \(bier)") }
	// Both pipes are read while bier runs: a full one would stop it.
	var output = Data()
	let reader = DispatchGroup()
	reader.enter()
	DispatchQueue.global().async {
		output = out.fileHandleForReading.readDataToEndOfFile()
		reader.leave()
	}
	let errors = err.fileHandleForReading.readDataToEndOfFile()
	reader.wait()
	process.waitUntilExit()
	return AdminRunResponse(status: process.terminationStatus, out: String(decoding: output, as: UTF8.self),
		err: String(decoding: errors, as: UTF8.self))
}

struct BundlePutRequest: Decodable {
	let id: String
	let offset: UInt64
	let data: Data
}

func validHostName(_ value: String) -> Bool {
	value.range(of: "^[A-Za-z0-9][A-Za-z0-9._-]*$", options: .regularExpression) != nil
}

func validPeerNonce(_ value: String) -> Bool {
	value.count >= 16 && value.count <= 128 && value.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil
}

func agentError(_ message: String) -> Never {
	fputs("bier-agent: \(message)\n", stderr)
	exit(1)
}

func peerPayload(method: String, path: String, peer: String, time: String, nonce: String, body: Data) -> Data {
	let digest = sha256Hex(body)
	return Data("\(method)\n\(path)\n\(peer)\n\(time)\n\(nonce)\n\(digest)\n".utf8)
}

func verifyPeer(method: String, path: String, peer: String, signers: String, time: String, nonce: String, body: Data, signature: Data) throws {
	guard validHostName(peer), validPeerNonce(nonce) else {
		throw NSError(domain: "BierAgent", code: 1, userInfo: [NSLocalizedDescriptionKey: "invalid peer request"])
	}
	let formatter = ISO8601DateFormatter()
	guard let requestTime = formatter.date(from: time), abs(requestTime.timeIntervalSinceNow) <= maxPeerRequestAge else {
		throw NSError(domain: "BierAgent", code: 1, userInfo: [NSLocalizedDescriptionKey: "peer request has expired"])
	}
	let signatureURL = FileManager.default.temporaryDirectory.appendingPathComponent("bier-peer-signature-\(UUID().uuidString)")
	try signature.write(to: signatureURL, options: .atomic)
	try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: signatureURL.path)
	defer { try? FileManager.default.removeItem(at: signatureURL) }

	let process = Process()
	process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")
	process.arguments = ["-Y", "verify", "-f", signers, "-I", peer, "-n", "bier-peer", "-s", signatureURL.path]
	let input = Pipe(), output = Pipe()
	process.standardInput = input
	process.standardOutput = output
	process.standardError = output
	try process.run()
	input.fileHandleForWriting.write(peerPayload(method: method, path: path, peer: peer, time: time, nonce: nonce, body: body))
	input.fileHandleForWriting.closeFile()
	process.waitUntilExit()
	guard process.terminationStatus == 0 else {
		throw NSError(domain: "BierAgent", code: 1, userInfo: [NSLocalizedDescriptionKey: "peer signature is not trusted"])
	}
}

final class ReplayStore {
	private let url: URL
	private let lock = NSLock()

	init(directory: URL) throws {
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
		try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
		url = directory.appendingPathComponent("processed-recipes")
	}

	func record(_ id: String) throws -> Bool {
		lock.lock()
		defer { lock.unlock() }
		let prior = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
		if prior.split(whereSeparator: \.isWhitespace).contains(Substring(id)) { return true }
		try (prior + id + "\n").write(to: url, atomically: true, encoding: .utf8)
		try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
		return false
	}
}

final class AgentServer {
	private let agent: String
	private let peerSigners: String?
	private let dataDirectory: URL?
	private let snapshotStore: DataSnapshotStore?
	private let bundleStore: GitBundleStore?
	private let pairingStore: PeerPairingStore?
	private let adminStore: PeerPairingStore?
	private let adminSigners: String?
	private let bier: String?
	private let store: ReplayStore
	private let listener: NWListener

	init(agent: String, peerSigners: String?, peerKey: String?, peersFile: String?, adminSigners: String?, bier: String?,
		dataDirectory: URL?, stateDirectory: URL, port: UInt16, bonjour: Bool) throws {
		guard validHostName(agent),
			let endpointPort = NWEndpoint.Port(rawValue: port) else {
			throw NSError(domain: "BierAgent", code: 1, userInfo: [NSLocalizedDescriptionKey: "invalid server configuration"])
		}
		self.agent = agent
		self.peerSigners = peerSigners
		if let peerSigners, let peerKey {
			pairingStore = PeerPairingStore(stateDirectory: stateDirectory, signersURL: URL(fileURLWithPath: peerSigners),
				localKeyURL: URL(fileURLWithPath: peerKey), peersURL: peersFile.map(URL.init(fileURLWithPath:)))
		} else {
			pairingStore = nil
		}
		// Bierkasten pairs like a peer, but into a list of its own: a peer
		// is never an admin, and an admin only ever talks from this Mac.
		if let adminSigners, let peerKey {
			adminStore = PeerPairingStore(stateDirectory: stateDirectory.appendingPathComponent("admin"),
				signersURL: URL(fileURLWithPath: adminSigners), localKeyURL: URL(fileURLWithPath: peerKey))
		} else {
			adminStore = nil
		}
		self.adminSigners = adminSigners
		self.bier = bier
		self.dataDirectory = dataDirectory
		if let dataDirectory {
			snapshotStore = try DataSnapshotStore(live: dataDirectory)
			bundleStore = try GitBundleStore(repository: GitRepository(root: dataDirectory), stateDirectory: stateDirectory)
		} else {
			snapshotStore = nil
			bundleStore = nil
		}
		store = try ReplayStore(directory: stateDirectory)
		listener = try NWListener(using: .tcp, on: endpointPort)
		if bonjour {
			listener.service = NWListener.Service(name: agent, type: "_bier-agent._tcp", domain: "local.")
		}
		listener.newConnectionHandler = { [weak self] connection in
			connection.start(queue: .global(qos: .utility))
			self?.receive(connection, data: Data())
		}
	}

	func start() {
		listener.start(queue: .global(qos: .utility))
		dispatchMain()
	}

	private func receive(_ connection: NWConnection, data: Data) {
		connection.receive(minimumIncompleteLength: 1, maximumLength: maxRequestBytes + 1) { [weak self] part, _, _, error in
			guard let self else { connection.cancel(); return }
			var combined = data
			if let part { combined.append(part) }
			guard error == nil, combined.count <= maxRequestBytes else {
				self.respond(connection, status: 400, body: "invalid request")
				return
			}
			guard let request = self.completeRequest(combined) else {
				self.receive(connection, data: combined)
				return
			}
			self.handle(connection, method: request.method, path: request.path, headers: request.headers, body: request.body)
		}
	}

	private func completeRequest(_ data: Data) -> (method: String, path: String, headers: [String: String], body: Data)? {
		let separator = Data("\r\n\r\n".utf8)
		guard let range = data.range(of: separator),
			let header = String(data: data[..<range.lowerBound], encoding: .utf8) else { return nil }
		let lines = header.components(separatedBy: "\r\n")
		guard let requestLine = lines.first else { return nil }
		let fields = requestLine.split(separator: " ")
		guard fields.count == 3 else { return nil }
		var headers: [String: String] = [:]
		for line in lines.dropFirst() {
			let fields = line.split(separator: ":", maxSplits: 1)
			guard fields.count == 2 else { return nil }
			headers[String(fields[0]).lowercased()] = String(fields[1]).trimmingCharacters(in: .whitespaces)
		}
		let contentLength = headers["content-length"].flatMap(Int.init) ?? 0
		let bodyStart = range.upperBound
		guard contentLength >= 0, data.count >= bodyStart + contentLength else { return nil }
		return (String(fields[0]), String(fields[1]), headers, Data(data[bodyStart..<(bodyStart + contentLength)]))
	}

	private func handle(_ connection: NWConnection, method: String, path: String, headers: [String: String], body: Data) {
		if method == "GET" && path == "/v1/health" {
			respond(connection, status: 200, body: "{\"status\":\"ok\",\"version\":\"\(agentVersion)\"}", contentType: "application/json")
			return
		}
		if method == "POST" && path == "/v1/pair" {
			guard let pairingStore, let request = try? JSONDecoder().decode(PeerPairingRequest.self, from: body) else {
				respond(connection, status: 400, body: "invalid pairing request")
				return
			}
			do {
				let encoder = JSONEncoder()
				encoder.outputFormatting = .withoutEscapingSlashes
				respond(connection, status: 200, data: try encoder.encode(pairingStore.accept(request, agent: agent)), contentType: "application/json")
			} catch {
				respond(connection, status: 403, body: "pairing was rejected")
			}
			return
		}
		if method == "POST" && path == "/v1/admin/pair" {
			guard isLocal(connection), let adminStore, let request = try? JSONDecoder().decode(PeerPairingRequest.self, from: body) else {
				respond(connection, status: 403, body: "admin pairing is only open to this Mac")
				return
			}
			do {
				let encoder = JSONEncoder()
				encoder.outputFormatting = .withoutEscapingSlashes
				respond(connection, status: 200, data: try encoder.encode(adminStore.accept(request, agent: agent)), contentType: "application/json")
			} catch {
				respond(connection, status: 403, body: "pairing was rejected")
			}
			return
		}
		if method == "POST" && path == "/v1/admin/run" {
			guard isLocal(connection), let adminSigners, let bier, let admin = headers["x-bier-peer"], let time = headers["x-bier-time"],
				let nonce = headers["x-bier-nonce"], let encoded = headers["x-bier-signature"], let signature = Data(base64Encoded: encoded),
				let request = try? JSONDecoder().decode(AdminRunRequest.self, from: body) else {
				respond(connection, status: 403, body: "admin is not authorised")
				return
			}
			guard adminCommands.contains(where: { request.args.starts(with: $0) }) else {
				respond(connection, status: 403, body: "command not allowed")
				return
			}
			do {
				try verifyPeer(method: method, path: path, peer: admin, signers: adminSigners, time: time, nonce: nonce, body: body, signature: signature)
				if try store.record("admin-\(admin)-\(nonce)") { respond(connection, status: 409, body: "request was already processed"); return }
				respond(connection, status: 200, data: try JSONEncoder().encode(runBier(bier, request.args)), contentType: "application/json")
			} catch { respond(connection, status: 403, body: "admin is not authorised") }
			return
		}
		if method == "GET" && path == "/v1/peer/status" {
			guard let peerSigners, let bier, let peer = headers["x-bier-peer"], let time = headers["x-bier-time"],
				let nonce = headers["x-bier-nonce"], let encoded = headers["x-bier-signature"], let signature = Data(base64Encoded: encoded) else {
				respond(connection, status: 403, body: "peer is not authorised")
				return
			}
			do {
				// How this Mac is doing, for the fleet view on another Mac:
				// read only, the same lines BierMenu reads.
				try verifyPeer(method: method, path: path, peer: peer, signers: peerSigners, time: time, nonce: nonce, body: body, signature: signature)
				if try store.record("peer-\(peer)-\(nonce)") { respond(connection, status: 409, body: "peer request was already processed"); return }
				respond(connection, status: 200, data: try JSONEncoder().encode(runBier(bier, ["state"])), contentType: "application/json")
			} catch { respond(connection, status: 403, body: "peer is not authorised") }
			return
		}
		if method == "GET" && path == "/v1/peer/hello" {
			guard let peerSigners, let peer = headers["x-bier-peer"], let time = headers["x-bier-time"],
				let nonce = headers["x-bier-nonce"], let encoded = headers["x-bier-signature"],
				let signature = Data(base64Encoded: encoded) else {
				respond(connection, status: 403, body: "peer is not authorised")
				return
			}
			do {
				try verifyPeer(method: method, path: path, peer: peer, signers: peerSigners, time: time, nonce: nonce, body: body, signature: signature)
				if try store.record("peer-\(peer)-\(nonce)") {
					respond(connection, status: 409, body: "peer request was already processed")
				} else {
					respond(connection, status: 200, body: "{\"status\":\"peer-ok\",\"agent\":\"\(agent)\"}", contentType: "application/json")
				}
			} catch {
				respond(connection, status: 403, body: "peer is not authorised")
			}
			return
		}
		if method == "POST" && path == "/v1/peer/leave" {
			guard let peerSigners, let pairingStore, let peer = headers["x-bier-peer"], let time = headers["x-bier-time"],
				let nonce = headers["x-bier-nonce"], let encoded = headers["x-bier-signature"], let signature = Data(base64Encoded: encoded) else {
				respond(connection, status: 403, body: "peer is not authorised")
				return
			}
			do {
				// Only the sender itself, proven by its signature, can take
				// itself out; nobody can sign off another Mac.
				try verifyPeer(method: method, path: path, peer: peer, signers: peerSigners, time: time, nonce: nonce, body: body, signature: signature)
				if try store.record("peer-\(peer)-\(nonce)") { respond(connection, status: 409, body: "peer request was already processed"); return }
				var source: String?
				if case let .hostPort(host, _) = connection.endpoint { source = "\(host)" }
				try pairingStore.forget(peer: peer, from: source)
				respond(connection, status: 200, body: "{\"status\":\"peer-left\"}", contentType: "application/json")
			} catch { respond(connection, status: 403, body: "peer is not authorised") }
			return
		}
		if method == "POST" && path == "/v1/peer/introduce" {
			guard let peerSigners, let pairingStore, let peer = headers["x-bier-peer"], let time = headers["x-bier-time"],
				let nonce = headers["x-bier-nonce"], let encoded = headers["x-bier-signature"], let signature = Data(base64Encoded: encoded),
				let introduction = try? JSONDecoder().decode(PeerIntroduction.self, from: body) else {
				respond(connection, status: 400, body: "invalid introduction")
				return
			}
			do {
				// Only a Mac trusted here may vouch for another, and what it
				// vouches for waits for bier peer accept.
				try verifyPeer(method: method, path: path, peer: peer, signers: peerSigners, time: time, nonce: nonce, body: body, signature: signature)
				if try store.record("peer-\(peer)-\(nonce)") { respond(connection, status: 409, body: "peer request was already processed"); return }
				try pairingStore.introduce(introduction, by: peer, agent: agent)
				respond(connection, status: 200, body: "{\"status\":\"introduced\"}", contentType: "application/json")
			} catch { respond(connection, status: 403, body: "peer is not authorised") }
			return
		}
		if method == "POST" && path == "/v1/peer/confirm" {
			guard let pairingStore, let peer = headers["x-bier-peer"], let time = headers["x-bier-time"],
				let nonce = headers["x-bier-nonce"], let encoded = headers["x-bier-signature"], let signature = Data(base64Encoded: encoded),
				let signer = pairingStore.pendingSigner(peer) else {
				respond(connection, status: 403, body: "peer is not waiting here")
				return
			}
			let signers = FileManager.default.temporaryDirectory.appendingPathComponent("bier-pending-\(UUID().uuidString)")
			defer { try? FileManager.default.removeItem(at: signers) }
			do {
				// Signed with the very key it was introduced with.
				try (signer + "\n").write(to: signers, atomically: true, encoding: .utf8)
				try verifyPeer(method: method, path: path, peer: peer, signers: signers.path, time: time, nonce: nonce, body: body, signature: signature)
				if try store.record("peer-\(peer)-\(nonce)") { respond(connection, status: 409, body: "peer request was already processed"); return }
				try pairingStore.confirm(peer)
				respond(connection, status: 200, body: "{\"status\":\"confirmed\"}", contentType: "application/json")
			} catch { respond(connection, status: 403, body: "peer is not authorised") }
			return
		}
		if method == "GET" && path == "/v1/peer/manifest" {
			guard let peerSigners, let dataDirectory, let peer = headers["x-bier-peer"], let time = headers["x-bier-time"],
				let nonce = headers["x-bier-nonce"], let encoded = headers["x-bier-signature"], let signature = Data(base64Encoded: encoded) else {
				respond(connection, status: 403, body: "peer is not authorised")
				return
			}
			do {
				try verifyPeer(method: method, path: path, peer: peer, signers: peerSigners, time: time, nonce: nonce, body: body, signature: signature)
				if try store.record("peer-\(peer)-\(nonce)") { respond(connection, status: 409, body: "peer request was already processed"); return }
				let encoder = JSONEncoder()
				encoder.outputFormatting = .withoutEscapingSlashes
				let body = try String(data: encoder.encode(collectDataManifest(at: dataDirectory)), encoding: .utf8) ?? "{}"
				respond(connection, status: 200, body: body, contentType: "application/json")
			} catch { respond(connection, status: 403, body: "peer request was rejected") }
			return
		}
		if method == "POST" && path == "/v1/peer/data/read" {
			guard let peerSigners, let dataDirectory, let peer = headers["x-bier-peer"], let time = headers["x-bier-time"],
				let nonce = headers["x-bier-nonce"], let encoded = headers["x-bier-signature"], let signature = Data(base64Encoded: encoded),
				let request = try? JSONDecoder().decode(DataReadRequest.self, from: body) else {
				respond(connection, status: 400, body: "invalid data request")
				return
			}
			do {
				try verifyPeer(method: method, path: path, peer: peer, signers: peerSigners, time: time, nonce: nonce, body: body, signature: signature)
				if try store.record("peer-\(peer)-\(nonce)") { respond(connection, status: 409, body: "peer request was already processed"); return }
				respond(connection, status: 200, data: try readDataChunk(at: dataDirectory, path: request.path, offset: request.offset, length: request.length), contentType: "application/octet-stream")
			} catch {
				respond(connection, status: 403, body: "data request was rejected")
			}
			return
		}
		if method == "POST" && path == "/v1/peer/snapshot/begin" {
			guard let peerSigners, let snapshotStore, let peer = headers["x-bier-peer"], let time = headers["x-bier-time"],
				let nonce = headers["x-bier-nonce"], let encoded = headers["x-bier-signature"], let signature = Data(base64Encoded: encoded),
				let request = try? JSONDecoder().decode(SnapshotBeginRequest.self, from: body) else {
				respond(connection, status: 400, body: "invalid snapshot request")
				return
			}
			do {
				try verifyPeer(method: method, path: path, peer: peer, signers: peerSigners, time: time, nonce: nonce, body: body, signature: signature)
				if try store.record("peer-\(peer)-\(nonce)") { respond(connection, status: 409, body: "peer request was already processed"); return }
				try snapshotStore.begin(request.id, manifest: request.manifest)
				respond(connection, status: 200, body: "{\"status\":\"snapshot-ready\"}", contentType: "application/json")
			} catch {
				respond(connection, status: 403, body: "snapshot request was rejected")
			}
			return
		}
		if method == "POST" && path == "/v1/peer/snapshot/put" {
			guard let peerSigners, let snapshotStore, let peer = headers["x-bier-peer"], let time = headers["x-bier-time"],
				let nonce = headers["x-bier-nonce"], let encoded = headers["x-bier-signature"], let signature = Data(base64Encoded: encoded),
				let request = try? JSONDecoder().decode(SnapshotPutRequest.self, from: body) else {
				respond(connection, status: 400, body: "invalid snapshot request")
				return
			}
			do {
				try verifyPeer(method: method, path: path, peer: peer, signers: peerSigners, time: time, nonce: nonce, body: body, signature: signature)
				if try store.record("peer-\(peer)-\(nonce)") { respond(connection, status: 409, body: "peer request was already processed"); return }
				try snapshotStore.put(request.id, path: request.path, offset: request.offset, data: request.data)
				respond(connection, status: 200, body: "{\"status\":\"snapshot-staged\"}", contentType: "application/json")
			} catch {
				respond(connection, status: 403, body: "snapshot request was rejected")
			}
			return
		}
		if method == "POST" && path == "/v1/peer/snapshot/commit" {
			guard let peerSigners, let snapshotStore, let peer = headers["x-bier-peer"], let time = headers["x-bier-time"],
				let nonce = headers["x-bier-nonce"], let encoded = headers["x-bier-signature"], let signature = Data(base64Encoded: encoded),
				let request = try? JSONDecoder().decode(SnapshotCommitRequest.self, from: body) else {
				respond(connection, status: 400, body: "invalid snapshot request")
				return
			}
			do {
				try verifyPeer(method: method, path: path, peer: peer, signers: peerSigners, time: time, nonce: nonce, body: body, signature: signature)
				if try store.record("peer-\(peer)-\(nonce)") { respond(connection, status: 409, body: "peer request was already processed"); return }
				try snapshotStore.commit(request.id)
				respond(connection, status: 200, body: "{\"status\":\"snapshot-committed\"}", contentType: "application/json")
			} catch {
				respond(connection, status: 403, body: "snapshot request was rejected")
			}
			return
		}
		if method == "POST" && path == "/v1/peer/repository/export" {
			guard let peerSigners, let bundleStore, let peer = headers["x-bier-peer"], let time = headers["x-bier-time"],
				let nonce = headers["x-bier-nonce"], let encoded = headers["x-bier-signature"], let signature = Data(base64Encoded: encoded) else {
				respond(connection, status: 403, body: "peer is not authorised")
				return
			}
			do {
				try verifyPeer(method: method, path: path, peer: peer, signers: peerSigners, time: time, nonce: nonce, body: body, signature: signature)
				if try store.record("peer-\(peer)-\(nonce)") { respond(connection, status: 409, body: "peer request was already processed"); return }
				let encoder = JSONEncoder()
				encoder.outputFormatting = .withoutEscapingSlashes
				respond(connection, status: 200, data: try encoder.encode(bundleStore.beginExport()), contentType: "application/json")
			} catch { respond(connection, status: 403, body: rejection("repository export was rejected", error)) }
			return
		}
		if method == "POST" && path == "/v1/peer/repository/export/read" {
			guard let peerSigners, let bundleStore, let peer = headers["x-bier-peer"], let time = headers["x-bier-time"],
				let nonce = headers["x-bier-nonce"], let encoded = headers["x-bier-signature"], let signature = Data(base64Encoded: encoded),
				let request = try? JSONDecoder().decode(BundleReadRequest.self, from: body) else {
				respond(connection, status: 400, body: "invalid repository request")
				return
			}
			do {
				try verifyPeer(method: method, path: path, peer: peer, signers: peerSigners, time: time, nonce: nonce, body: body, signature: signature)
				if try store.record("peer-\(peer)-\(nonce)") { respond(connection, status: 409, body: "peer request was already processed"); return }
				respond(connection, status: 200, data: try bundleStore.readExport(request.id, offset: request.offset, length: request.length), contentType: "application/octet-stream")
			} catch { respond(connection, status: 403, body: "repository export was rejected") }
			return
		}
		if method == "POST" && path == "/v1/peer/repository/import/begin" {
			guard let peerSigners, let bundleStore, let peer = headers["x-bier-peer"], let time = headers["x-bier-time"],
				let nonce = headers["x-bier-nonce"], let encoded = headers["x-bier-signature"], let signature = Data(base64Encoded: encoded),
				let descriptor = try? JSONDecoder().decode(GitBundleDescriptor.self, from: body) else {
				respond(connection, status: 400, body: "invalid repository request")
				return
			}
			do {
				try verifyPeer(method: method, path: path, peer: peer, signers: peerSigners, time: time, nonce: nonce, body: body, signature: signature)
				if try store.record("peer-\(peer)-\(nonce)") { respond(connection, status: 409, body: "peer request was already processed"); return }
				try bundleStore.beginImport(descriptor)
				respond(connection, status: 200, body: "{\"status\":\"repository-ready\"}", contentType: "application/json")
			} catch { respond(connection, status: 403, body: "repository import was rejected") }
			return
		}
		if method == "POST" && path == "/v1/peer/repository/import/put" {
			guard let peerSigners, let bundleStore, let peer = headers["x-bier-peer"], let time = headers["x-bier-time"],
				let nonce = headers["x-bier-nonce"], let encoded = headers["x-bier-signature"], let signature = Data(base64Encoded: encoded),
				let request = try? JSONDecoder().decode(BundlePutRequest.self, from: body) else {
				respond(connection, status: 400, body: "invalid repository request")
				return
			}
			do {
				try verifyPeer(method: method, path: path, peer: peer, signers: peerSigners, time: time, nonce: nonce, body: body, signature: signature)
				if try store.record("peer-\(peer)-\(nonce)") { respond(connection, status: 409, body: "peer request was already processed"); return }
				try bundleStore.putImport(request.id, offset: request.offset, data: request.data)
				respond(connection, status: 200, body: "{\"status\":\"repository-staged\"}", contentType: "application/json")
			} catch { respond(connection, status: 403, body: "repository import was rejected") }
			return
		}
		if method == "POST" && path == "/v1/peer/repository/import/commit" {
			guard let peerSigners, let bundleStore, let peer = headers["x-bier-peer"], let time = headers["x-bier-time"],
				let nonce = headers["x-bier-nonce"], let encoded = headers["x-bier-signature"], let signature = Data(base64Encoded: encoded),
				let request = try? JSONDecoder().decode(SnapshotCommitRequest.self, from: body) else {
				respond(connection, status: 400, body: "invalid repository request")
				return
			}
			do {
				try verifyPeer(method: method, path: path, peer: peer, signers: peerSigners, time: time, nonce: nonce, body: body, signature: signature)
				if try store.record("peer-\(peer)-\(nonce)") { respond(connection, status: 409, body: "peer request was already processed"); return }
				try bundleStore.commitImport(request.id)
				respond(connection, status: 200, body: "{\"status\":\"repository-committed\"}", contentType: "application/json")
			} catch { respond(connection, status: 403, body: rejection("repository import was rejected", error)) }
			return
		}
		respond(connection, status: 404, body: "not found")
	}

	private func isLocal(_ connection: NWConnection) -> Bool {
		guard case let .hostPort(host, _) = connection.endpoint else { return false }
		let address = "\(host)"
		return address == "127.0.0.1" || address.hasPrefix("::1") || address.hasPrefix("::ffff:127.0.0.1")
	}

	// The peer has proven who it is by now, and "rejected" alone left
	// it guessing. Only the repository's own reasons go out.
	private func rejection(_ message: String, _ error: Error) -> String {
		guard let error = error as? GitRepositoryError else { return message }
		return "\(message): \(error.peerDescription)"
	}

	private func respond(_ connection: NWConnection, status: Int, body: String, contentType: String = "text/plain") {
		respond(connection, status: status, data: Data(body.utf8), contentType: contentType)
	}

	private func respond(_ connection: NWConnection, status: Int, data: Data, contentType: String) {
		let reason = status == 200 ? "OK" : status == 400 ? "Bad Request" : status == 403 ? "Forbidden" : status == 409 ? "Conflict" : "Not Found"
		let header = "HTTP/1.1 \(status) \(reason)\r\nContent-Type: \(contentType)\r\nContent-Length: \(data.count)\r\nConnection: close\r\n\r\n"
		connection.send(content: Data(header.utf8) + data, completion: .contentProcessed { _ in connection.cancel() })
	}
}

func option(_ args: [String], _ name: String) -> String? {
	guard let index = args.firstIndex(of: name), args.indices.contains(index + 1) else { return nil }
	return args[index + 1]
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else { agentError("usage: bier-agent <version|serve>") }
switch command {
case "version":
	print(agentVersion)
case "serve":
	// --allowed-signers belonged to signed recipes, which are gone; older
	// LaunchAgents still pass it, and it is ignored.
	guard let agent = option(arguments, "--agent") else {
		agentError("agent is required")
	}
	let port = UInt16(option(arguments, "--port") ?? "53991") ?? 0
	let bonjour = option(arguments, "--bonjour") != "false"
	let peerSigners = option(arguments, "--peer-signers")
	let peerKey = option(arguments, "--peer-key")
	let peersFile = option(arguments, "--peers-file")
	// Next to the peer keys and the barrel's bin; older LaunchAgents do
	// not name them.
	let barrelAgent = peerSigners.map { URL(fileURLWithPath: $0).deletingLastPathComponent() }
	let adminSigners = option(arguments, "--admin-signers") ?? barrelAgent?.appendingPathComponent("admin_signers").path
	let bier = option(arguments, "--bier") ?? barrelAgent?.deletingLastPathComponent().appendingPathComponent("bin/bier").path
	let dataDirectory = option(arguments, "--data-dir").map(URL.init(fileURLWithPath:))
	let state = option(arguments, "--state-dir").map(URL.init(fileURLWithPath:))
		?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Bier")
	do { try AgentServer(agent: agent, peerSigners: peerSigners, peerKey: peerKey, peersFile: peersFile,
		adminSigners: adminSigners, bier: bier, dataDirectory: dataDirectory, stateDirectory: state, port: port, bonjour: bonjour).start() }
	catch { agentError(error.localizedDescription) }
default:
	agentError("unknown command")
}
