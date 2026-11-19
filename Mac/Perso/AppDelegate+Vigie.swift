//
//  AppDelegate+Vigie.swift
//  Vigie
//
//  VIGIE: réglages propres au fork, appliqués au lancement (menus ajoutés en code, pas dans les xib).
//

import AppKit
import Articles

extension AppDelegate {

	func setUpVigie() {
		// Les mises à jour Sparkle sont coupées : on masque l'entrée de menu correspondante.
		checkForUpdatesMenuItem?.isHidden = true
		VigieMenuController.shared.installMenuItems()
	}
}

@MainActor final class VigieMenuController: NSObject, NSMenuItemValidation {

	static let shared = VigieMenuController()

	func installMenuItems() {
		guard let menu = articleMenu() else {
			return
		}

		let exportItem = NSMenuItem(title: "Exporter vers Obsidian", action: #selector(exportSelectedArticlesToObsidian(_:)), keyEquivalent: "o")
		exportItem.keyEquivalentModifierMask = [.control, .command]
		exportItem.target = self

		let chooseFolderItem = NSMenuItem(title: "Choisir le dossier d’export Obsidian…", action: #selector(chooseObsidianExportFolder(_:)), keyEquivalent: "")
		chooseFolderItem.target = self

		menu.addItem(.separator())
		menu.addItem(exportItem)
		menu.addItem(chooseFolderItem)
	}

	@objc func exportSelectedArticlesToObsidian(_ sender: Any?) {
		ObsidianExporter.shared.export(appDelegate.scriptingSelectedArticles)
	}

	/// Entrée « Exporter vers Obsidian » du menu contextuel de la liste d'articles.
	func contextualExportMenuItem(_ articles: [Article]) -> NSMenuItem {
		let item = NSMenuItem(title: "Exporter vers Obsidian", action: #selector(exportArticlesFromContextualMenu(_:)), keyEquivalent: "")
		item.target = self
		item.representedObject = articles
		return item
	}

	@objc func exportArticlesFromContextualMenu(_ sender: Any?) {
		guard let articles = (sender as? NSMenuItem)?.representedObject as? [Article] else {
			return
		}
		ObsidianExporter.shared.export(articles)
	}

	@objc func chooseObsidianExportFolder(_ sender: Any?) {
		ObsidianExportSettings.chooseExportFolder()
	}

	// MARK: - NSMenuItemValidation

	func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
		if menuItem.action == #selector(exportSelectedArticlesToObsidian(_:)) {
			return !appDelegate.scriptingSelectedArticles.isEmpty
		}
		return true
	}
}

private extension VigieMenuController {

	/// Le menu « Article » du menu principal (celui qui contient « Marquer comme lu »).
	func articleMenu() -> NSMenu? {
		guard let mainMenu = NSApp.mainMenu else {
			return nil
		}
		let toggleRead = #selector(MainWindowController.toggleRead(_:))
		return mainMenu.items.compactMap(\.submenu).first { submenu in
			submenu.items.contains { $0.action == toggleRead }
		}
	}
}
