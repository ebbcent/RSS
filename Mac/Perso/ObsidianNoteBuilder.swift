//
//  ObsidianNoteBuilder.swift
//  Vigie
//
//  VIGIE: construit la note Markdown (front matter YAML + corps) et son nom de fichier.
//

import Foundation
import Account
import Articles

@MainActor struct ObsidianNoteBuilder {

	let article: Article

	/// Nom de fichier lisible : « AAAA-MM-JJ Titre.md », sans caractères gênants pour Obsidian.
	var baseFileName: String {
		let date = Self.dayFormatter.string(from: article.logicalDatePublished)
		return "\(date) \(Self.sanitizedFileNamePart(title))"
	}

	var title: String {
		let trimmed = (article.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? "Sans titre" : trimmed
	}

	/// Contenu complet de la note.
	func noteText() async -> String {
		let body = await bodyMarkdown()
		var lines = [String]()

		lines.append("# \(title)")
		lines.append("")
		if let sourceLine {
			lines.append("> \(sourceLine)")
			lines.append("")
		}
		lines.append(body)

		return frontMatter() + "\n" + lines.joined(separator: "\n") + "\n"
	}

	/// Lit `article_id` dans le front matter d'une note existante.
	static func articleID(inNoteHeader text: String) -> String? {
		var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
		guard lines.first == "---" else {
			return nil
		}
		lines.removeFirst()
		for line in lines {
			if line == "---" {
				return nil
			}
			guard line.hasPrefix("article_id:") else {
				continue
			}
			var value = line.dropFirst("article_id:".count).trimmingCharacters(in: .whitespaces)
			if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
				value = String(value.dropFirst().dropLast())
				value = value.replacingOccurrences(of: "\\\"", with: "\"").replacingOccurrences(of: "\\\\", with: "\\")
			}
			return value.isEmpty ? nil : value
		}
		return nil
	}
}

private extension ObsidianNoteBuilder {

	static let dayFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.calendar = Calendar(identifier: .gregorian)
		formatter.dateFormat = "yyyy-MM-dd"
		return formatter
	}()

	static let minuteFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.calendar = Calendar(identifier: .gregorian)
		formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
		return formatter
	}()

	var feed: Feed? {
		article.feed
	}

	var authorNames: [String] {
		let articleAuthors = article.authors ?? []
		let authors = articleAuthors.isEmpty ? (feed?.authors ?? []) : articleAuthors
		let names = authors.compactMap { $0.name?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
		return Array(Set(names)).sorted()
	}

	var sourceLine: String? {
		var parts = [String]()
		if let feed {
			let feedLink = feed.homePageURL ?? feed.url
			parts.append("Source : [\(Self.escapedLinkText(feed.nameForDisplay))](\(Self.escapedLinkTarget(feedLink)))")
		}
		if let link = article.preferredLink {
			parts.append("[Lire l’article en ligne](\(Self.escapedLinkTarget(link)))")
		}
		return parts.isEmpty ? nil : parts.joined(separator: " · ")
	}

	func frontMatter() -> String {
		var lines = ["---"]
		lines.append("title: \(Self.yamlString(title))")
		if let link = article.preferredLink {
			lines.append("url: \(Self.yamlString(link))")
		}
		let authors = authorNames
		if !authors.isEmpty {
			lines.append("author:")
			for name in authors {
				lines.append("  - \(Self.yamlString(name))")
			}
		}
		if let feed {
			lines.append("feed: \(Self.yamlString(feed.nameForDisplay))")
			lines.append("feed_url: \(Self.yamlString(feed.url))")
		}
		if let published = article.datePublished ?? article.dateModified {
			lines.append("published: \(Self.dayFormatter.string(from: published))")
		}
		lines.append("exported: \(Self.minuteFormatter.string(from: Date()))")
		lines.append("article_id: \(Self.yamlString(article.articleID))")
		lines.append("tags:")
		lines.append("  - rss")
		lines.append("---")
		return lines.joined(separator: "\n") + "\n"
	}

	/// Corps en Markdown : Markdown fourni par le flux, sinon HTML converti, sinon texte brut.
	func bodyMarkdown() async -> String {
		if let markdown = Self.nonEmpty(article.markdown) {
			return markdown
		}
		for html in [article.contentHTML, article.summary] {
			guard let html = Self.nonEmpty(html) else {
				continue
			}
			if let converted = await HTMLToMarkdown.shared.markdown(from: html, baseURL: article.preferredLink), !converted.isEmpty {
				return converted
			}
		}
		if let text = Self.nonEmpty(article.contentText) {
			return text
		}
		return "*(Le flux ne fournit pas le texte de cet article.)*"
	}

	static func nonEmpty(_ string: String?) -> String? {
		guard let string, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
			return nil
		}
		return string
	}

	static func yamlString(_ string: String) -> String {
		let singleLine = string.replacingOccurrences(of: "\r\n", with: " ")
			.replacingOccurrences(of: "\n", with: " ")
			.replacingOccurrences(of: "\r", with: " ")
		let escaped = singleLine.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
		return "\"\(escaped)\""
	}

	static func escapedLinkText(_ string: String) -> String {
		string.replacingOccurrences(of: "[", with: "\\[").replacingOccurrences(of: "]", with: "\\]")
	}

	static func escapedLinkTarget(_ string: String) -> String {
		string.replacingOccurrences(of: " ", with: "%20")
			.replacingOccurrences(of: "(", with: "%28")
			.replacingOccurrences(of: ")", with: "%29")
	}

	/// Retire les caractères interdits ou gênants dans un nom de note Obsidian.
	static func sanitizedFileNamePart(_ string: String) -> String {
		let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|#^[]").union(.newlines).union(.controlCharacters)
		let cleaned = string.unicodeScalars.map { forbidden.contains($0) ? " " : String($0) }.joined()
		let collapsed = cleaned.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
		var result = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: " ."))
		if result.count > 120 {
			result = String(result.prefix(120)).trimmingCharacters(in: CharacterSet(charactersIn: " ."))
		}
		return result.isEmpty ? "Sans titre" : result
	}
}
