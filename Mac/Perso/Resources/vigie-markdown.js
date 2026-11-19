// VIGIE: conversion HTML → Markdown pour l'export Obsidian (s'appuie sur Turndown, MIT).
(function () {
	'use strict';

	function makeService() {
		var service = new TurndownService({
			headingStyle: 'atx',
			hr: '---',
			bulletListMarker: '-',
			codeBlockStyle: 'fenced',
			emDelimiter: '*',
			strongDelimiter: '**',
			linkStyle: 'inlined'
		});
		service.use(turndownPluginGfm.gfm);
		service.remove(['script', 'style', 'noscript', 'iframe', 'form', 'button']);
		return service;
	}

	// Rend absolus les liens et les images relatifs, par rapport à l'URL de l'article.
	function absolutize(doc, baseURL) {
		if (!baseURL) {
			return;
		}
		var resolve = function (value) {
			try {
				return new URL(value, baseURL).href;
			} catch (e) {
				return value;
			}
		};
		Array.prototype.forEach.call(doc.querySelectorAll('a[href]'), function (a) {
			a.setAttribute('href', resolve(a.getAttribute('href')));
		});
		Array.prototype.forEach.call(doc.querySelectorAll('img[src]'), function (img) {
			img.setAttribute('src', resolve(img.getAttribute('src')));
		});
	}

	window.vigieHTMLToMarkdown = function (html, baseURL) {
		// Document inerte : ni script exécuté, ni image chargée.
		var doc = document.implementation.createHTMLDocument('');
		doc.body.innerHTML = html || '';
		absolutize(doc, baseURL);
		return makeService().turndown(doc.body).trim();
	};
})();
