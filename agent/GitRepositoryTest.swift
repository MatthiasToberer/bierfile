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
		print("Swift Bier Git repository tests passed.")
	}
}
