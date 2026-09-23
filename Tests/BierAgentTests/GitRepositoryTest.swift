import Foundation

@main
struct GitRepositoryTest {
	static func git(_ arguments: [String], at directory: URL) throws {
		let process = Process()
		process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
		process.arguments = ["-C", directory.path] + arguments
		process.standardOutput = FileHandle.nullDevice
		process.standardError = FileHandle.nullDevice
		try process.run()
		process.waitUntilExit()
		guard process.terminationStatus == 0 else {
			throw NSError(domain: "GitRepositoryTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "git \(arguments.joined(separator: " ")) failed"])
		}
	}

	static func write(_ value: String, to root: URL) throws {
		let file = root.appendingPathComponent("Brewfiles/main")
		try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
		try value.write(to: file, atomically: true, encoding: .utf8)
	}

	static func commit(_ message: String, at root: URL) throws {
		try git(["add", "Brewfiles"], at: root)
		try git(["commit", "--quiet", "-m", message], at: root)
	}

	static func main() throws {
		let manager = FileManager.default
		let work = manager.temporaryDirectory.appendingPathComponent("bier-git-test-\(UUID().uuidString)")
		defer { try? manager.removeItem(at: work) }
		let source = work.appendingPathComponent("source")
		let target = work.appendingPathComponent("target")
		let bundle = work.appendingPathComponent("data.bundle")
		try manager.createDirectory(at: source, withIntermediateDirectories: true)
		try git(["init", "--quiet", "--initial-branch=main"], at: source)
		try git(["config", "user.email", "test@example.com"], at: source)
		try git(["config", "user.name", "Test"], at: source)
		try write("brew \"jq\"\n", to: source)
		try commit("first", at: source)
		try GitRepository(root: source).exportBundle(to: bundle)

		try manager.createDirectory(at: target.appendingPathComponent("Brewfiles"), withIntermediateDirectories: true)
		try manager.copyItem(at: source.appendingPathComponent("Brewfiles/main"), to: target.appendingPathComponent("Brewfiles/main"))
		try GitRepository(root: target).importBundle(from: bundle)
		guard GitRepository(root: target).exists else { throw GitRepositoryError.notRepository }

		try write("brew \"jq\"\nbrew \"tree\"\n", to: source)
		try commit("second", at: source)
		try GitRepository(root: source).exportBundle(to: bundle)
		try GitRepository(root: target).importBundle(from: bundle)
		guard try String(contentsOf: target.appendingPathComponent("Brewfiles/main"), encoding: .utf8).contains("tree") else {
			throw GitRepositoryError.dataMismatch
		}

		try git(["config", "user.email", "test@example.com"], at: target)
		try git(["config", "user.name", "Test"], at: target)
		try write("brew \"local-only\"\n", to: target)
		try commit("diverged", at: target)
		do {
			try GitRepository(root: target).importBundle(from: bundle)
			throw NSError(domain: "GitRepositoryTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "divergent history was accepted"])
		} catch GitRepositoryError.nonFastForward {}
		guard try String(contentsOf: target.appendingPathComponent("Brewfiles/main"), encoding: .utf8).contains("local-only") else {
			throw GitRepositoryError.dataMismatch
		}

		let transferTarget = work.appendingPathComponent("transfer-target")
		try manager.createDirectory(at: transferTarget.appendingPathComponent("Brewfiles"), withIntermediateDirectories: true)
		try manager.copyItem(at: source.appendingPathComponent("Brewfiles/main"), to: transferTarget.appendingPathComponent("Brewfiles/main"))
		let exporter = try GitBundleStore(repository: GitRepository(root: source), stateDirectory: work.appendingPathComponent("export-state"))
		let descriptor = try exporter.beginExport()
		let importer = try GitBundleStore(repository: GitRepository(root: transferTarget), stateDirectory: work.appendingPathComponent("import-state"))
		try importer.beginImport(descriptor)
		var offset: UInt64 = 0
		while offset < descriptor.bytes {
			let chunk = try exporter.readExport(descriptor.id, offset: offset, length: 17)
			try importer.putImport(descriptor.id, offset: offset, data: chunk)
			offset += UInt64(chunk.count)
		}
		try importer.commitImport(descriptor.id)
		guard GitRepository(root: transferTarget).exists else { throw GitRepositoryError.notRepository }

		// An adopted repository is on a branch and has no leftover origin.
		try expect(try output(["symbolic-ref", "HEAD"], at: transferTarget) == "refs/heads/main", "an adopted repository must be on main")
		try expect(try output(["remote"], at: transferTarget).isEmpty, "the temporary bundle must not stay behind as origin")
		// And one adopted by an older version is put right on the next exchange.
		try git(["checkout", "--quiet", "--detach"], at: transferTarget)
		try git(["remote", "add", "origin", "/private/tmp/gone/import.bundle"], at: transferTarget)
		try GitRepository(root: transferTarget).importBundle(from: bundle)
		try expect(try output(["symbolic-ref", "HEAD"], at: transferTarget) == "refs/heads/main", "a detached repository must be put back on main")
		try expect(try output(["remote"], at: transferTarget).isEmpty, "a leftover bundle origin must go")

		try installedMacs(in: work)
		print("Swift Bier Git repository tests passed.")
	}

	static func expect(_ condition: Bool, _ message: String) throws {
		guard condition else { throw NSError(domain: "GitRepositoryTest", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
	}

	static func output(_ arguments: [String], at directory: URL) throws -> String {
		let process = Process()
		let pipe = Pipe()
		process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
		process.arguments = ["-C", directory.path] + arguments
		process.standardOutput = pipe
		process.standardError = FileHandle.nullDevice
		try process.run()
		let data = pipe.fileHandleForReading.readDataToEndOfFile()
		process.waitUntilExit()
		return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
	}

	/// What install.sh leaves behind: its own scaffolding commit, so two
	/// Macs set up apart share no history.
	static func install(_ name: String, date: String, in work: URL) throws -> URL {
		let root = work.appendingPathComponent(name)
		try FileManager.default.createDirectory(at: root.appendingPathComponent("Brewfiles"), withIntermediateDirectories: true)
		try git(["init", "--quiet", "--initial-branch=main"], at: root)
		try git(["config", "user.email", "test@example.com"], at: root)
		try git(["config", "user.name", "Test"], at: root)
		try "Brewfiles/* merge=union\nSafe/** binary -merge\n".write(to: root.appendingPathComponent(".gitattributes"), atomically: true, encoding: .utf8)
		try "".write(to: root.appendingPathComponent("Brewfiles/main"), atomically: true, encoding: .utf8)
		try git(["add", "-A"], at: root)
		try git(["commit", "--quiet", "--date", date, "-m", "bier: scaffolding"], at: root)
		return root
	}

	static func record(_ host: String, _ line: String, at root: URL) throws {
		try "\(line)\n".write(to: root.appendingPathComponent("Brewfiles/\(host)"), atomically: true, encoding: .utf8)
		try git(["add", "-A"], at: root)
		try git(["commit", "--quiet", "-m", "\(host): inventory recorded"], at: root)
	}

	static func installedMacs(in work: URL) throws {
		let manager = FileManager.default
		let first = try install("first", date: "2026-01-01T00:00:00Z", in: work)
		let second = try install("second", date: "2026-02-01T00:00:00Z", in: work)
		try expect(try output(["rev-parse", "HEAD"], at: first) != output(["rev-parse", "HEAD"], at: second), "the two installations must not share a root")
		try record("first", "brew \"jq\"", at: first)
		try record("second", "brew \"tree\"", at: second)

		// Uncommitted files do not stop a Mac from handing out its history.
		try "brew \"wget\"\n".write(to: second.appendingPathComponent("Brewfiles/second"), atomically: true, encoding: .utf8)
		let fromSecond = work.appendingPathComponent("second.bundle")
		try GitRepository(root: second).exportBundle(to: fromSecond)
		try git(["checkout", "--quiet", "--", "Brewfiles/second"], at: second)

		// The first Mac drops its own scaffolding and replays the rest.
		try GitRepository(root: first).reconcileBundle(from: fromSecond)
		try expect(manager.fileExists(atPath: first.appendingPathComponent("Brewfiles/first").path), "the own inventory must survive")
		try expect(manager.fileExists(atPath: first.appendingPathComponent("Brewfiles/second").path), "the peer inventory must arrive")
		try expect(try output(["rev-list", "--max-parents=0", "HEAD"], at: first) == output(["rev-list", "--max-parents=0", "HEAD"], at: second), "both Macs must share one root afterwards")

		// And the second Mac takes the result as a fast-forward.
		let fromFirst = work.appendingPathComponent("first.bundle")
		try GitRepository(root: first).exportBundle(to: fromFirst)
		try GitRepository(root: second).importBundle(from: fromFirst)
		try expect(try output(["rev-parse", "HEAD"], at: first) == output(["rev-parse", "HEAD"], at: second), "both Macs must end on the same commit")

		// A Mac that holds only scaffolding is kept as it is by the other side.
		let bare = try install("bare", date: "2026-03-01T00:00:00Z", in: work)
		let fromBare = work.appendingPathComponent("bare.bundle")
		try GitRepository(root: bare).exportBundle(to: fromBare)
		let before = try output(["rev-parse", "HEAD"], at: first)
		try GitRepository(root: first).reconcileBundle(from: fromBare)
		try expect(try output(["rev-parse", "HEAD"], at: first) == before, "a bare scaffolding must not change anything")
		try GitRepository(root: bare).importBundle(from: fromFirst)
		try expect(try output(["rev-parse", "HEAD"], at: bare) == before, "the bare Mac must take the whole history")

		// Pairing: the snapshot arrives first, the history afterwards.
		let paired = try install("paired", date: "2026-04-01T00:00:00Z", in: work)
		for path in ["Brewfiles/first", "Brewfiles/second", "Brewfiles/main", ".gitattributes"] {
			let target = paired.appendingPathComponent(path)
			try? manager.removeItem(at: target)
			try manager.copyItem(at: first.appendingPathComponent(path), to: target)
		}
		try GitRepository(root: paired).importBundle(from: fromFirst)
		try expect(try output(["rev-parse", "HEAD"], at: paired) == before, "the snapshot files must not block the history")

		// Anything else uncommitted on a bare Mac is somebody's work.
		let busy = try install("busy", date: "2026-05-01T00:00:00Z", in: work)
		try "brew \"own\"\n".write(to: busy.appendingPathComponent("Brewfiles/busy"), atomically: true, encoding: .utf8)
		do {
			try GitRepository(root: busy).importBundle(from: fromFirst)
			try expect(false, "uncommitted work was overwritten")
		} catch GitRepositoryError.uncommittedChanges {}
		try expect(manager.fileExists(atPath: busy.appendingPathComponent("Brewfiles/busy").path), "uncommitted work must stay")

		// Histories that are more than scaffolding apart stay apart.
		let foreign = work.appendingPathComponent("foreign")
		try manager.createDirectory(at: foreign.appendingPathComponent("Brewfiles"), withIntermediateDirectories: true)
		try git(["init", "--quiet", "--initial-branch=main"], at: foreign)
		try git(["config", "user.email", "test@example.com"], at: foreign)
		try git(["config", "user.name", "Test"], at: foreign)
		try write("brew \"old\"\n", to: foreign)
		try commit("old central history", at: foreign)
		try record("foreign", "brew \"x\"", at: foreign)
		do {
			try GitRepository(root: foreign).reconcileBundle(from: fromFirst)
			try expect(false, "unrelated data histories were joined")
		} catch GitRepositoryError.unrelatedHistories {}
	}
}
