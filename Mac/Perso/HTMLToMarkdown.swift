//
//  HTMLToMarkdown.swift
//  Vigie
//
//  VIGIE: convertit le HTML d'un article en Markdown avec Turndown (MIT),
//  exécuté dans un WKWebView invisible. Voir Resources/vigie-markdown.js.
//

import AppKit
import WebKit
import os
import RSCore

@MainActor final class HTMLToMarkdown: NSObject, WKNavigationDelegate {

	static let shared = HTMLToMarkdown()

	static private let logger = Logger(subsystem: Logger.nnwSubsystem, category: "HTMLToMarkdown")

	private static let scriptNames = ["turndown", "turndown-plugin-gfm", "vigie-markdown"]
	private static let blankPage = "<!doctype html><html><head><meta charset=\"utf-8\"></head><body></body></html>"

	private var webView: WKWebView?
	private var isReady = false
	private var waiters = [CheckedContinuation<Bool, Never>]()

	/// Renvoie le Markdown du HTML donné, ou nil si la conversion échoue.
	/// - Parameter baseURL: URL de l'article, pour rendre absolus les liens et les images relatifs.
	func markdown(from html: String, baseURL: String?) async -> String? {
		guard await prepareIfNeeded(), let webView else {
			return nil
		}

		do {
			let result = try await webView.callAsyncJavaScript(
				"return window.vigieHTMLToMarkdown(html, baseURL);",
				arguments: ["html": html, "baseURL": baseURL ?? ""],
				in: nil,
				contentWorld: .page
			)
			return result as? String
		} catch {
			Self.logger.error("HTMLToMarkdown: conversion failed: \(error.localizedDescription)")
			return nil
		}
	}

	// MARK: - WKNavigationDelegate

	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		isReady = true
		resumeWaiters(true)
	}

	func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
		loadFailed(error)
	}

	func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
		loadFailed(error)
	}
}

private extension HTMLToMarkdown {

	func prepareIfNeeded() async -> Bool {
		if isReady {
			return true
		}
		if webView == nil {
			webView = makeWebView()
			webView?.loadHTMLString(Self.blankPage, baseURL: nil)
		}
		return await withCheckedContinuation { continuation in
			waiters.append(continuation)
		}
	}

	func makeWebView() -> WKWebView {
		let contentController = WKUserContentController()
		for name in Self.scriptNames {
			guard let url = Bundle.main.url(forResource: name, withExtension: "js"),
				  let source = try? String(contentsOf: url, encoding: .utf8) else {
				Self.logger.error("HTMLToMarkdown: missing script \(name, privacy: .public)")
				continue
			}
			let script = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
			contentController.addUserScript(script)
		}

		let configuration = WKWebViewConfiguration()
		configuration.userContentController = contentController

		let webView = WKWebView(frame: .zero, configuration: configuration)
		webView.navigationDelegate = self
		return webView
	}

	func loadFailed(_ error: any Error) {
		Self.logger.error("HTMLToMarkdown: page load failed: \(error.localizedDescription)")
		webView = nil
		isReady = false
		resumeWaiters(false)
	}

	func resumeWaiters(_ success: Bool) {
		let waitersToResume = waiters
		waiters.removeAll()
		for waiter in waitersToResume {
			waiter.resume(returning: success)
		}
	}
}
