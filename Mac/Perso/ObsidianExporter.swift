//
//  ObsidianExporter.swift
//  Vigie
//
//  VIGIE: exporte des articles en notes .md dans le coffre Obsidian, sans doublon
//  (repérage par `article_id` dans le front matter des notes déjà présentes).
//

import AppKit
import UserNotifications
import os
import RSCore
import Articles

@MainActor final class ObsidianExporter {

	static let shared = ObsidianExporter()

	static private let logger = Logger(subsystem: Logger.nnwSubsystem, category: "ObsidianExporter")

	/// Nombre d'octets lus en tête de chaque note pour trouver `article_id`.
	private static let headerByteCount = 4096

	private var isExporting = false

	/// Exporte les articles ; ouvre la note dans Obsidian quand il n'y en a qu'une.
	func export(_ articles: [Article]) {
		guard !articles.isEmpty, !isExporting else {
			return
		}
		guard let folder = ObsidianExportSettings.exportFolderURL() ?? ObsidianExportSettings.chooseExportFolder() else {
			return
		}

		isExporting = true
		Task {
			await export(articles, to: folder)
			isExporting = false
		}
	}
}

private extension ObsidianExporter {

	struct ExportResult {
		var created = [URL]()
		var alreadyExported = [URL]()
		var failures = [String]()
	}

	func export(_ articles: [Article], to folder: URL) async {
		var result = ExportResult()
		var index = existingNotesByArticleID(in: folder)

		for article in articles {
			if let existing = index[article.articleID] {
				result.alreadyExported.append(existing)
				continue
			}

			let builder = ObsidianNoteBuilder(article: article)
			let text = await builder.noteText()
			let fileURL = availableFileURL(baseName: builder.baseFileName, in: folder)
			do {
				try Data(text.utf8).write(to: fileURL, options: .atomic)
				index[article.articleID] = fileURL
				result.created.append(fileURL)
			} catch {
				Self.logger.error("ObsidianExporter: could not write note: \(error.localizedDescription)")
				result.failures.append(builder.title)
			}
		}

		report(result)
	}

	/// Index `article_id → note` de toutes les notes .md du dossier (sous-dossiers compris).
	func existingNotesByArticleID(in folder: URL) -> [String: URL] {
		var index = [String: URL]()
		let keys: [URLResourceKey] = [.isRegularFileKey]
		guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
			return index
		}

		for case let url as URL in enumerator {
			guard url.pathExtension.lowercased() == "md",
				  (try? url.resourceValues(forKeys: Set(keys)))?.isRegularFile == true,
				  let header = Self.readHeader(of: url),
				  let articleID = ObsidianNoteBuilder.articleID(inNoteHeader: header) else {
				continue
			}
			index[articleID] = url
		}
		return index
	}

	static func readHeader(of url: URL) -> String? {
		guard let handle = try? FileHandle(forReadingFrom: url) else {
			return nil
		}
		defer {
			try? handle.close()
		}
		guard let data = try? handle.read(upToCount: headerByteCount) else {
			return nil
		}
		return String(decoding: data, as: UTF8.self)
	}

	/// « Nom.md », sinon « Nom (2).md », « Nom (3).md »…
	func availableFileURL(baseName: String, in folder: URL) -> URL {
		var candidate = folder.appending(path: "\(baseName).md", directoryHint: .notDirectory)
		var counter = 2
		while FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) {
			candidate = folder.appending(path: "\(baseName) (\(counter)).md", directoryHint: .notDirectory)
			counter += 1
		}
		return candidate
	}

	func report(_ result: ExportResult) {
		let notes = result.created + result.alreadyExported

		if !result.failures.isEmpty {
			let alert = NSAlert()
			alert.alertStyle = .warning
			alert.messageText = "Export Obsidian incomplet"
			alert.informativeText = "Impossible d’écrire : " + result.failures.joined(separator: ", ")
			alert.runModal()
		}

		if notes.count == 1, let note = notes.first {
			let isNew = !result.created.isEmpty
			postNotification(title: isNew ? "Exporté vers Obsidian" : "Déjà exporté", body: note.deletingPathExtension().lastPathComponent)
			open(note)
			return
		}

		if notes.count > 1 {
			postNotification(title: "Export Obsidian", body: "\(result.created.count) exporté(s), \(result.alreadyExported.count) déjà présent(s)")
		}
	}

	/// Ouvre la note dans Obsidian ; à défaut, la montre dans le Finder.
	func open(_ note: URL) {
		var allowed = CharacterSet.alphanumerics
		allowed.insert(charactersIn: "-._~")
		let path = note.path(percentEncoded: false)
		if let encodedPath = path.addingPercentEncoding(withAllowedCharacters: allowed),
		   let obsidianURL = URL(string: "obsidian://open?path=\(encodedPath)"),
		   NSWorkspace.shared.urlForApplication(toOpen: obsidianURL) != nil {
			NSWorkspace.shared.open(obsidianURL)
		} else {
			NSWorkspace.shared.activateFileViewerSelecting([note])
		}
	}

	func postNotification(title: String, body: String) {
		let content = UNMutableNotificationContent()
		content.title = title
		content.body = body
		let request = UNNotificationRequest(identifier: "vigie.obsidian.\(UUID().uuidString)", content: content, trigger: nil)
		UNUserNotificationCenter.current().add(request)
	}
}
