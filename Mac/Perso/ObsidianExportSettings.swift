//
//  ObsidianExportSettings.swift
//  Vigie
//
//  VIGIE: dossier de destination des exports Obsidian, choisi une fois puis mémorisé.
//

import AppKit
import os
import RSCore

@MainActor enum ObsidianExportSettings {

	static private let logger = Logger(subsystem: Logger.nnwSubsystem, category: "ObsidianExportSettings")

	private static let bookmarkKey = "VigieObsidianExportFolderBookmark"

	/// Coffre « Claude », dossier « Lectures RSS » (iCloud Obsidian).
	static var suggestedFolderURL: URL {
		FileManager.default.homeDirectoryForCurrentUser
			.appending(path: "Library/Mobile Documents/iCloud~md~obsidian/Documents/Claude/Lectures RSS", directoryHint: .isDirectory)
	}

	/// Le dossier mémorisé, s'il existe encore.
	static func exportFolderURL() -> URL? {
		guard let bookmark = UserDefaults.standard.data(forKey: bookmarkKey) else {
			return nil
		}

		var isStale = false
		guard let url = try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale) else {
			return nil
		}
		if isStale {
			remember(url)
		}

		var isDirectory: ObjCBool = false
		guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory), isDirectory.boolValue else {
			return nil
		}
		return url
	}

	/// Demande le dossier d'export (pré-positionné sur le dossier suggéré) et le mémorise.
	@discardableResult
	static func chooseExportFolder() -> URL? {
		let suggested = suggestedFolderURL
		let vaultFolder = suggested.deletingLastPathComponent()
		if FileManager.default.fileExists(atPath: vaultFolder.path(percentEncoded: false)) {
			try? FileManager.default.createDirectory(at: suggested, withIntermediateDirectories: true)
		}

		let panel = NSOpenPanel()
		panel.title = "Dossier d’export Obsidian"
		panel.message = "Choisis le dossier du coffre Obsidian où Vigie enregistrera les articles."
		panel.prompt = "Choisir"
		panel.canChooseFiles = false
		panel.canChooseDirectories = true
		panel.canCreateDirectories = true
		panel.allowsMultipleSelection = false
		panel.directoryURL = exportFolderURL() ?? suggested

		guard panel.runModal() == .OK, let url = panel.url else {
			return nil
		}
		remember(url)
		return url
	}
}

private extension ObsidianExportSettings {

	static func remember(_ url: URL) {
		do {
			let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
			UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
		} catch {
			logger.error("ObsidianExportSettings: could not save folder bookmark: \(error.localizedDescription)")
		}
	}
}
