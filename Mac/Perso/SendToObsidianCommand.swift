//
//  SendToObsidianCommand.swift
//  Vigie
//
//  VIGIE: entrée « Obsidian » du bouton Partager (barre d'outils et menu contextuel).
//

import AppKit
import RSCore
import Articles

@MainActor final class SendToObsidianCommand: SendToCommand {

	let title = "Obsidian"

	var image: RSImage? {
		guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "md.obsidian") else {
			return nil
		}
		return NSWorkspace.shared.icon(forFile: appURL.path(percentEncoded: false))
	}

	func canSendObject(_ object: Any?, selectedText: String?) -> Bool {
		object is ArticlePasteboardWriter
	}

	func sendObject(_ object: Any?, selectedText: String?) {
		guard let article = (object as? ArticlePasteboardWriter)?.article else {
			return
		}
		ObsidianExporter.shared.export([article])
	}
}
