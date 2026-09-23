import Foundation
import Network

#if BIER_PACKAGE
import BierCore
let agentVersion = "dev"
#endif

let maxRequestBytes = 64 * 1024
let maxPeerRequestAge: TimeInterval = 5 * 60

struct Recipe: Decodable {
	let version: Int
	let id: String
	let target: String
	let type: String
	let expiresAt: String
	let issuer: String
	let payload: [String: String]

	enum CodingKeys: String, CodingKey {
		case version, id, target, type, expiresAt = "expires_at", issuer, payload
	}
}

struct ProbeEnvelope: Decodable {
	let recipe: String
	let signature: String
}

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

func validHostName(_ value: String) -> Bool {
	value.range(of: "^[A-Za-z0-9][A-Za-z0-9._-]*$", options: .regularExpression) != nil
}

func validRecipeID(_ value: String) -> Bool {
	value.count <= 128 && value.range(of: "^[A-Za-z0-9][A-Za-z0-9._-]*$", options: .regularExpression) != nil
}

func validPeerNonce(_ value: String) -> Bool {
	value.count >= 16 && value.count <= 128 && value.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil
}

func agentError(_ message: String) -> Never {
	fputs("bier-agent: \(message)\n", stderr)
	exit(1)
}

func verifyRecipe(agent: String, signers: String, raw: Data, signature: Data) throws -> Recipe {
	guard validHostName(agent),
		let recipe = try? JSONDecoder().decode(Recipe.self, from: raw),
		recipe.version == 1,
		validRecipeID(recipe.id),
		recipe.target == agent,
		recipe.type == "agent.probe",
		validHostName(recipe.issuer),
		recipe.payload.isEmpty else {
		throw NSError(domain: "BierAgent", code: 1, userInfo: [NSLocalizedDescriptionKey: "recipe is not allowed for this agent"])
	}
	let formatter = ISO8601DateFormatter()
	guard let expiry = formatter.date(from: recipe.expiresAt), expiry > Date() else {
		throw NSError(domain: "BierAgent", code: 1, userInfo: [NSLocalizedDescriptionKey: "recipe has expired or has an invalid expiry"])
	}
	let signatureURL = FileManager.default.temporaryDirectory.appendingPathComponent("bier-agent-signature-\(UUID().uuidString)")
	try signature.write(to: signatureURL, options: .atomic)
	try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: signatureURL.path)
	defer { try? FileManager.default.removeItem(at: signatureURL) }

	let process = Process()
	process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")
	process.arguments = ["-Y", "verify", "-f", signers, "-I", recipe.issuer, "-n", "bier-recipe", "-s", signatureURL.path]
	let input = Pipe(), output = Pipe()
	process.standardInput = input
	process.standardOutput = output
	process.standardError = output
	try process.run()
	input.fileHandleForWriting.write(raw)
	input.fileHandleForWriting.closeFile()
	process.waitUntilExit()
	guard process.terminationStatus == 0 else {
		throw NSError(domain: "BierAgent", code: 1, userInfo: [NSLocalizedDescriptionKey: "recipe signature is not trusted"])
	}
	return recipe
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
	private let signers: String
	private let peerSigners: String?
	private let dataDirectory: URL?
	private let snapshotStore: DataSnapshotStore?
	private let store: ReplayStore
	private let listener: NWListener

	init(agent: String, signers: String, peerSigners: String?, dataDirectory: URL?, stateDirectory: URL, port: UInt16, bonjour: Bool) throws {
		guard validHostName(agent), FileManager.default.fileExists(atPath: signers),
			let endpointPort = NWEndpoint.Port(rawValue: port) else {
			throw NSError(domain: "BierAgent", code: 1, userInfo: [NSLocalizedDescriptionKey: "invalid server configuration"])
		}
		self.agent = agent
		self.signers = signers
		self.peerSigners = peerSigners
		self.dataDirectory = dataDirectory
		if let dataDirectory {
			snapshotStore = try DataSnapshotStore(live: dataDirectory)
		} else {
			snapshotStore = nil
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
		guard method == "POST", path == "/v1/probe",
			let envelope = try? JSONDecoder().decode(ProbeEnvelope.self, from: body),
			let raw = Data(base64Encoded: envelope.recipe),
			let signature = Data(base64Encoded: envelope.signature) else {
			respond(connection, status: 400, body: "invalid probe request")
			return
		}
		do {
			let recipe = try verifyRecipe(agent: agent, signers: signers, raw: raw, signature: signature)
			if try store.record(recipe.id) {
				respond(connection, status: 409, body: "recipe was already processed")
			} else {
				respond(connection, status: 200, body: "{\"status\":\"accepted\"}", contentType: "application/json")
			}
		} catch {
			respond(connection, status: 403, body: "recipe rejected")
		}
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
guard let command = arguments.first else { agentError("usage: bier-agent <version|verify|serve>") }
switch command {
case "version":
	print(agentVersion)
case "verify":
	guard let agent = option(arguments, "--agent"), let recipePath = option(arguments, "--recipe"), let signers = option(arguments, "--allowed-signers"),
		let raw = try? Data(contentsOf: URL(fileURLWithPath: recipePath)), let signature = try? Data(contentsOf: URL(fileURLWithPath: recipePath + ".sig")) else {
		agentError("agent, recipe and allowed-signers are required")
	}
	do {
		let recipe = try verifyRecipe(agent: agent, signers: signers, raw: raw, signature: signature)
		print("Recipe \(recipe.id) is valid for \(recipe.target). Nothing was executed.")
	} catch { agentError(error.localizedDescription) }
case "serve":
	guard let agent = option(arguments, "--agent"), let signers = option(arguments, "--allowed-signers") else {
		agentError("agent and allowed-signers are required")
	}
	let port = UInt16(option(arguments, "--port") ?? "53991") ?? 0
	let bonjour = option(arguments, "--bonjour") != "false"
	let peerSigners = option(arguments, "--peer-signers")
	let dataDirectory = option(arguments, "--data-dir").map(URL.init(fileURLWithPath:))
	let state = option(arguments, "--state-dir").map(URL.init(fileURLWithPath:))
		?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Bier")
	do { try AgentServer(agent: agent, signers: signers, peerSigners: peerSigners, dataDirectory: dataDirectory, stateDirectory: state, port: port, bonjour: bonjour).start() }
	catch { agentError(error.localizedDescription) }
default:
	agentError("unknown command")
}
