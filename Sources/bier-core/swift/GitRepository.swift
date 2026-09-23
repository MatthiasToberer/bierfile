import Foundation

public enum GitRepositoryError: LocalizedError {
	case notRepository
	case uncommittedChanges
	case dataMismatch
	case nonFastForward
	case unrelatedHistories
	case gitFailed(String)

	public var errorDescription: String? {
		switch self {
		case .notRepository:
			return "the Bier data directory is not a Git repository"
		case .uncommittedChanges:
			return "the Bier data repository has uncommitted changes"
		case .dataMismatch:
			return "the repository history does not match the existing Bier data"
		case .nonFastForward:
			return "the peer repository has changes that are not in the incoming history"
		case .unrelatedHistories:
			return "the two Bier data histories have nothing in common"
		case let .gitFailed(message):
			return "Git failed: \(message)"
		}
	}

	/// What an authenticated peer may be told. Git's own output can name
	/// local paths, so it stays on this Mac.
	public var peerDescription: String {
		if case .gitFailed = self { return "Git failed on the peer" }
		return errorDescription ?? "unknown error"
	}
}

public struct GitRepository {
	public let root: URL

	public init(root: URL) {
		self.root = root
	}

	public var exists: Bool {
		FileManager.default.fileExists(atPath: root.appendingPathComponent(".git").path)
	}

	// A bundle carries committed history only, so uncommitted files on
	// this Mac are no reason to refuse it: they would block every peer
	// until somebody here commits.
	public func exportBundle(to destination: URL) throws {
		guard exists else { throw GitRepositoryError.notRepository }
		let temporary = destination.deletingLastPathComponent().appendingPathComponent(".\(destination.lastPathComponent).\(UUID().uuidString).tmp")
		defer { try? FileManager.default.removeItem(at: temporary) }
		try run(["bundle", "create", temporary.path, "HEAD"], in: root)
		if FileManager.default.fileExists(atPath: destination.path) {
			try FileManager.default.removeItem(at: destination)
		}
		try FileManager.default.moveItem(at: temporary, to: destination)
	}

	public func importBundle(from bundle: URL) throws {
		guard FileManager.default.isReadableFile(atPath: bundle.path) else {
			throw GitRepositoryError.gitFailed("the bundle is not readable")
		}
		if !exists {
			try adopt(bundle: bundle)
			return
		}
		try fetch(bundle)
		defer { _ = try? run(["update-ref", "-d", "refs/remotes/bier/incoming"], in: root) }
		// A repository that holds nothing but the installer's scaffolding
		// takes the incoming history whole. Its files may already be the
		// incoming ones: pairing sends the snapshot before the history.
		if isScaffolding("HEAD") {
			if !isClean {
				guard try matchesWorkingTree(bundle) else { throw GitRepositoryError.uncommittedChanges }
			}
			try run(["reset", "--hard", "--quiet", "refs/remotes/bier/incoming"], in: root)
			return
		}
		try requireClean()
		guard isAncestor("HEAD", of: "refs/remotes/bier/incoming") else { throw GitRepositoryError.nonFastForward }
		try run(["reset", "--hard", "--quiet", "refs/remotes/bier/incoming"], in: root)
	}

	public func reconcileBundle(from bundle: URL) throws {
		guard exists else { throw GitRepositoryError.notRepository }
		try requireClean()
		try fetch(bundle)
		defer { _ = try? run(["update-ref", "-d", "refs/remotes/bier/incoming"], in: root) }
		if isAncestor("HEAD", of: "refs/remotes/bier/incoming") {
			try run(["reset", "--hard", "--quiet", "refs/remotes/bier/incoming"], in: root)
			return
		}
		if isAncestor("refs/remotes/bier/incoming", of: "HEAD") { return }
		if (try? run(["merge-base", "HEAD", "refs/remotes/bier/incoming"], in: root)) == nil {
			try reconcileUnrelated()
			return
		}
		do {
			try run(["rebase", "refs/remotes/bier/incoming"], in: root)
		} catch {
			_ = try? run(["rebase", "--abort"], in: root)
			throw GitRepositoryError.nonFastForward
		}
	}

	// Every installation used to start its own history with a scaffolding
	// commit, so two Macs set up apart share no commit at all. Only that
	// scaffolding differs, never anybody's data: the peer that holds
	// nothing else is kept as it is, and otherwise this Mac's own
	// scaffolding is dropped and the rest replayed on the incoming history.
	private func reconcileUnrelated() throws {
		if isScaffolding("refs/remotes/bier/incoming") { return }
		let roots = try run(["rev-list", "--max-parents=0", "HEAD"], in: root).split(separator: "\n").map(String.init)
		guard roots.count == 1, let base = roots.first, isScaffolding(base) else {
			throw GitRepositoryError.unrelatedHistories
		}
		do {
			try run(["rebase", "--onto", "refs/remotes/bier/incoming", base], in: root)
		} catch {
			_ = try? run(["rebase", "--abort"], in: root)
			throw GitRepositoryError.nonFastForward
		}
	}

	/// A root commit that holds only what install.sh creates: the
	/// attributes file and an empty main list. The snapshot client uses
	/// the same definition of a pristine data store.
	private func isScaffolding(_ revision: String) -> Bool {
		guard let parents = try? run(["rev-list", "--parents", "-n", "1", revision], in: root),
			parents.split(separator: " ").count == 1,
			let tree = try? run(["ls-tree", "-r", "-l", "-z", revision], in: root) else { return false }
		return tree.split(separator: "\0").allSatisfy { line in
			let fields = line.split(separator: "\t", maxSplits: 1)
			guard fields.count == 2 else { return false }
			let size = fields[0].split(separator: " ", omittingEmptySubsequences: true).last
			return fields[1] == ".gitattributes" || (fields[1] == "Brewfiles/main" && size == "0")
		}
	}

	private var isClean: Bool {
		(try? requireClean()) != nil
	}

	private func matchesWorkingTree(_ bundle: URL) throws -> Bool {
		let checkout = root.deletingLastPathComponent().appendingPathComponent(".bier-repository-\(UUID().uuidString)")
		defer { try? FileManager.default.removeItem(at: checkout) }
		try run(["clone", "--quiet", bundle.path, checkout.path], in: root.deletingLastPathComponent())
		return try collectDataManifest(at: checkout).entries == collectDataManifest(at: root).entries
	}

	private func adopt(bundle: URL) throws {
		let manager = FileManager.default
		let parent = root.deletingLastPathComponent()
		let checkout = parent.appendingPathComponent(".bier-repository-\(UUID().uuidString)")
		defer { try? manager.removeItem(at: checkout) }
		try run(["clone", "--quiet", bundle.path, checkout.path], in: parent)
		let incoming = try collectDataManifest(at: checkout)
		let current = try collectDataManifest(at: root)
		guard incoming.entries == current.entries else { throw GitRepositoryError.dataMismatch }
		try manager.moveItem(at: checkout.appendingPathComponent(".git"), to: root.appendingPathComponent(".git"))
	}

	private func requireClean() throws {
		let status = try run(["status", "--porcelain", "--untracked-files=all"], in: root)
		guard status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
			throw GitRepositoryError.uncommittedChanges
		}
	}

	private func fetch(_ bundle: URL) throws {
		_ = try? run(["update-ref", "-d", "refs/remotes/bier/incoming"], in: root)
		try run(["fetch", "--quiet", bundle.path, "HEAD:refs/remotes/bier/incoming"], in: root)
	}

	private func isAncestor(_ older: String, of newer: String) -> Bool {
		(try? run(["merge-base", "--is-ancestor", older, newer], in: root)) != nil
	}

	@discardableResult
	private func run(_ arguments: [String], in directory: URL) throws -> String {
		let process = Process()
		let output = Pipe()
		process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
		process.arguments = ["-C", directory.path] + arguments
		process.environment = ProcessInfo.processInfo.environment.merging(["GIT_TERMINAL_PROMPT": "0"]) { _, new in new }
		process.standardOutput = output
		process.standardError = output
		try process.run()
		let data = output.fileHandleForReading.readDataToEndOfFile()
		process.waitUntilExit()
		let message = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown error"
		guard process.terminationStatus == 0 else { throw GitRepositoryError.gitFailed(message) }
		return message
	}
}
