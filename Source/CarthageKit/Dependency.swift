import Foundation
import Result
import Tentacle

/// Uniquely identifies a project that can be used as a dependency.
public enum Dependency {
	/// A repository hosted on GitHub.com or GitHub Enterprise.
	case gitHub(Server, Repository)

	/// An arbitrary Git repository.
	case git(GitURL)

	/// A binary-only framework
	case binary(URL)

	/// The unique, user-visible name for this project.
	public var name: String {
		switch self {
		case let .gitHub(_, repo):
			return repo.name

		case let .git(url):
			return url.name ?? url.urlString

		case let .binary(url):
			let name = url.lastPathComponent.stripping(suffix: ".json")
			// lastPathComponent gives empty string when no path
			if name == "" {
				return url.host ?? "unknown"
			}
			return name
		}
	}

	public var cacheName: String {
		switch self {
		case let .gitHub(.dotCom, repo):
			return "\(name)/\(repo.owner)"
		case let .gitHub(.enterprise(url), repo):
			return "\(name)/\(url.absoluteString.cacheSafeName)_\(repo.owner)"
		case let .git(url):
			// Replace all non a-z0-9 chars with _
			return "\(name)/\(url.normalizedURLString.cacheSafeName)"
		case let .binary(url):
			return "\(name)/\(url.absoluteString.cacheSafeName)"
		}
	}

	/// The path at which this project will be checked out, relative to the
	/// working directory of the main project.
	public var relativePath: String {
		return (carthageProjectCheckoutsPath as NSString).appendingPathComponent(name)
	}
}

extension Dependency {
	fileprivate init(gitURL: GitURL) {
		let githubHostIdentifier = "github.com"
		let urlString = gitURL.urlString

		if urlString.contains(githubHostIdentifier) {
			let gitbubHostScanner = Scanner(string: urlString)

			gitbubHostScanner.scanUpTo(githubHostIdentifier, into: nil)
			gitbubHostScanner.scanString(githubHostIdentifier, into: nil)

			// find an SCP or URL path separator
			let separatorFound = (gitbubHostScanner.scanString("/", into: nil) || gitbubHostScanner.scanString(":", into: nil)) && !gitbubHostScanner.isAtEnd

			let startOfOwnerAndNameSubstring = gitbubHostScanner.scanLocation

			if separatorFound && startOfOwnerAndNameSubstring <= urlString.utf16.count {
				let ownerAndNameSubstring = String(urlString[urlString.index(urlString.startIndex, offsetBy: startOfOwnerAndNameSubstring)..<urlString.endIndex])

				switch Repository.fromIdentifier(ownerAndNameSubstring as String) {
				case .success(let server, let repository):
					self = Dependency.gitHub(server, repository)

				default:
					self = Dependency.git(gitURL)
				}

				return
			}
		}

		self = Dependency.git(gitURL)
	}
}

extension Dependency: Comparable {
	public static func == (_ lhs: Dependency, _ rhs: Dependency) -> Bool {
		switch (lhs, rhs) {
		case let (.gitHub(left), .gitHub(right)):
			return left == right

		case let (.git(left), .git(right)):
			return left == right

		case let (.binary(left), .binary(right)):
			return left == right

		default:
			return false
		}
	}

	public static func < (_ lhs: Dependency, _ rhs: Dependency) -> Bool {
		return lhs.name.caseInsensitiveCompare(rhs.name) == .orderedAscending
	}
}

extension Dependency: Hashable {
	public var hashValue: Int {
		switch self {
		case let .gitHub(server, repo):
			return server.hashValue ^ repo.hashValue

		case let .git(url):
			return url.hashValue

		case let .binary(url):
			return url.hashValue
		}
	}
}

extension Dependency: Scannable {
	/// Attempts to parse a Dependency.
	public static func from(_ scanner: Scanner) -> Result<Dependency, ScannableError> {
		let parser: (String) -> Result<Dependency, ScannableError>

		if scanner.scanString("github", into: nil) {
			parser = { repoIdentifier in
				return Repository.fromIdentifier(repoIdentifier).map { self.gitHub($0, $1) }
			}
		} else if scanner.scanString("git", into: nil) {
			parser = { urlString in

				return .success(Dependency(gitURL: GitURL(urlString)))
			}
		} else if scanner.scanString("binary", into: nil) {
			parser = { urlString in
				if let url = URL(string: urlString) {
					if url.scheme == "https" || url.scheme == "file" {
						return .success(self.binary(url))
					} else {
						return .failure(ScannableError(message: "non-https, non-file URL found for dependency type `binary`", currentLine: scanner.currentLine))
					}
				} else {
					return .failure(ScannableError(message: "invalid URL found for dependency type `binary`", currentLine: scanner.currentLine))
				}
			}
		} else {
			return .failure(ScannableError(message: "unexpected dependency type", currentLine: scanner.currentLine))
		}

		if !scanner.scanString("\"", into: nil) {
			return .failure(ScannableError(message: "expected string after dependency type", currentLine: scanner.currentLine))
		}

		var address: NSString?
		if !scanner.scanUpTo("\"", into: &address) || !scanner.scanString("\"", into: nil) {
			return .failure(ScannableError(message: "empty or unterminated string after dependency type", currentLine: scanner.currentLine))
		}

		if let address = address {
			return parser(address as String)
		} else {
			return .failure(ScannableError(message: "empty string after dependency type", currentLine: scanner.currentLine))
		}
	}
}

extension Dependency: CustomStringConvertible {
	public var description: String {
		switch self {
		case let .gitHub(server, repo):
			let repoDescription: String
			switch server {
			case .dotCom:
				repoDescription = "\(repo.owner)/\(repo.name)"

			case .enterprise:
				repoDescription = "\(server.url(for: repo))"
			}
			return "github \"\(repoDescription)\""

		case let .git(url):
			return "git \"\(url)\""

		case let .binary(url):
			return "binary \"\(url.absoluteString)\""
		}
	}
}

extension Dependency {
	/// Returns the URL that the dependency's remote repository exists at.
	func gitURL(preferHTTPS: Bool) -> GitURL? {
		switch self {
		case let .gitHub(server, repository):
			if preferHTTPS {
				return server.httpsURL(for: repository)
			} else {
				return server.sshURL(for: repository)
			}

		case let .git(url):
			return url

		case .binary:
			return nil
		}
	}
}
