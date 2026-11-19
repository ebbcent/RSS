# CLAUDE.md

## Règles du fork Vigie (prioritaires sur le reste de ce fichier)

Ce dépôt (`github.com/ebbcent/RSS`) est le fork personnel de NetNewsWire (MIT) de Clément, historien, pas développeur Swift. Il produit **Vigie**, une app **Mac uniquement**, à usage perso. La version App Store de NetNewsWire reste sur iPhone.

Objectifs : (1) une interface Mac plus belle, au goût de Clément ; (2) l'export direct d'un article vers le coffre Obsidian (`Claude/Lectures RSS`) en `.md`.

Règles :

1. **Branche `perso`** pour tout le travail. Elle part du **dernier tag de version Mac** (`mac-X.Y`), jamais de `main`. Pour mettre à jour : `git fetch upstream --tags`, puis rebaser ou fusionner `perso` sur le nouveau tag.
2. **Identité séparée** : bundle `fr.ebbcent.Vigie`, nom `Vigie`, flag Swift `VIGIE`. Ne jamais revenir aux identifiants `com.ranchero.*`. Les mises à jour Sparkle sont coupées.
3. **Ne pas toucher au code iOS** : `iOS/`, `Widget/`, cibles iOS et leurs xcconfig. Attention, `Shared/` est compilé aussi pour iOS : on n'y ajoute rien.
4. **Petites modifications.** Le nouveau code va dans des **fichiers séparés sous `Mac/Perso/`** ; ce dossier est un groupe synchronisé, donc ajouté automatiquement à la cible Mac. Une retouche d'un fichier amont se limite à quelques lignes, marquées `// VIGIE`.
5. **Jamais de modification dans les storyboards ni les `.xib`.** Les menus, éléments et styles sont ajoutés en code.
6. **Aucune pull request vers l'amont** (Ranchero-Software/NetNewsWire). Le remote `upstream` est en lecture seule.
7. **Aucune suppression de fichier sans l'accord explicite de Clément.**
8. Expliquer en français simple ; signaler ce qui n'a pas été compilé ou testé.

Build local : `../SharedXcodeSettings/DeveloperSettings.xcconfig`, avec `ORGANIZATION_IDENTIFIER = fr.ebbcent` et `DEVELOPER_ENTITLEMENTS = -dev` (pas de sandbox). Puis `xcodebuild -project NetNewsWire.xcodeproj -scheme NetNewsWire -configuration Release -destination "platform=macOS,arch=arm64" build`.

---

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Development Commands

### Building and Testing
- **Full build and test**: `./buildscripts/build_and_test.sh` - Builds both macOS and iOS targets and runs all tests
- **Quiet build and test**: `./buildscripts/quiet_build_and_test.sh` - Same as above with less verbose output
- **Manual Xcode builds**:
  - macOS: `xcodebuild -project NetNewsWire.xcodeproj -scheme NetNewsWire -destination "platform=macOS,arch=arm64" build`
  - iOS: `xcodebuild -project NetNewsWire.xcodeproj -scheme NetNewsWire-iOS -destination "platform=iOS Simulator,name=iPhone 17" build`

### Testing
- Run all tests: Use the `NetNewsWire.xctestplan` which includes tests from all modules
- Individual test runs follow same xcodebuild pattern with `test` action instead of `build`

### Setup
- First-time setup: Run `./setup.sh` to configure development environment and code signing
- Manual setup: Create `SharedXcodeSettings/DeveloperSettings.xcconfig` in parent directory

## Project Architecture

### High-Level Structure
NetNewsWire is a multi-platform RSS reader with separate targets for macOS and iOS, organized as a modular architecture with shared business logic.

### Key Modules (in /Modules)
- **RSCore**: Core utilities, extensions, and shared infrastructure
- **RSParser**: Feed parsing (RSS, Atom, JSON Feed, RSS-in-JSON)
- **RSWeb**: HTTP networking, downloading, caching, and web services
- **RSDatabase**: SQLite database abstraction layer using FMDB
- **Account**: Account management (Local, Feedbin, Feedly, NewsBlur, Reader API, CloudKit)
- **Articles**: Article and author data models
- **ArticlesDatabase**: Article storage and search functionality
- **SyncDatabase**: Cross-device synchronization state management
- **Secrets**: Secure credential and API key management

### Platform-Specific Code
- **Mac/**: macOS-specific UI (AppKit), preferences, main window management
- **iOS/**: iOS-specific UI (UIKit), settings, navigation
- **Shared/**: Cross-platform business logic, article rendering, smart feeds

### Key Architectural Patterns
- **Account System**: Pluggable account delegates for different sync services
- **Feed Management**: Hierarchical folder/feed organization with OPML import/export
- **Article Rendering**: Template-based HTML rendering with custom CSS themes
- **Smart Feeds**: Virtual feeds (Today, All Unread, Starred) implemented as PseudoFeed protocol
- **Timeline/Detail**: Classic three-pane interface (sidebar, timeline, detail)

### Extension Points
- Share extensions for both platforms
- Safari extension for feed subscription
- Widget support for iOS
- AppleScript support on macOS
- Intent extensions for Siri shortcuts

### Development Notes
- Uses Xcode project with Swift Package Manager for module dependencies
- Requires `xcbeautify` for formatted build output in scripts
- API keys are managed through buildscripts/updateSecrets.sh (runs during builds)
- Some features disabled in development builds due to private API keys
- Code signing configured through SharedXcodeSettings for development
- Documentation and technical notes are located in the `Technotes/` folder

## Code Formatting

Prefer idiomatic modern Swift.

Prefer `if let x` and `guard let x` over `if let x = x` and `guard let x = x`.

Don’t use `...` or `…` in Logger messages.

Guard statements should always put the return in a separate line.

Don’t do force unwrapping of optionals.

## Things to Know

Just because unit tests pass doesn’t mean a given bug is fixed. It may not have a test. It may not even be testable — it may require manual testing.
