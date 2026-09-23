import Foundation

public enum GitRepositoryError: LocalizedError {
	case notRepository
	case uncommittedChanges
	case dataMismatch
	case nonFastForward
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
		case let .gitFailed(message):
			return "Git failed: \(message)"
		}
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

	public func exportBundle(to destination: URL) throws {
		guard exists else { throw GitRepositoryError.notRepository }
		try requireClean()
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
		try requireClean()
		try run(["fetch", "--quiet", bundle.path, "HEAD:refs/remotes/bier/incoming"], in: root)
		do {
			try run(["merge-base", "--is-ancestor", "HEAD", "refs/remotes/bier/incoming"], in: root)
		} catch {
			_ = try? run(["update-ref", "-d", "refs/remotes/bier/incoming"], in: root)
			throw GitRepositoryError.nonFastForward
		}
		try run(["reset", "--hard", "--quiet", "refs/remotes/bier/incoming"], in: root)
		try run(["update-ref", "-d", "refs/remotes/bier/incoming"], in: root)
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
		do {
			try run(["rebase", "refs/remotes/bier/incoming"], in: root)
		} catch {
			_ = try? run(["rebase", "--abort"], in: root)
			throw GitRepositoryError.nonFastForward
		}
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
