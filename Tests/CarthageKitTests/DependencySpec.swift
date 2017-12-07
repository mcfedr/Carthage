import CarthageKit
import Foundation
import Nimble
import Quick
import Tentacle

class DependencySpec: QuickSpec {
	override func spec() {
		var dependencyType: String!

		sharedExamples("invalid dependency") { (sharedExampleContext: @escaping SharedExampleContext) in

			beforeEach {
				guard let type = sharedExampleContext()["dependencyType"] as? String else {
					fail("no dependency type")
					return
				}

				dependencyType = type
			}

			it("should fail without dependency") {
				let scanner = Scanner(string: dependencyType)

				let error = Dependency.from(scanner).error

				let expectedError = ScannableError(message: "expected string after dependency type", currentLine: dependencyType)
				expect(error) == expectedError
			}

			it("should fail without closing quote on dependency") {
				let scanner = Scanner(string: "\(dependencyType!) \"dependency")

				let error = Dependency.from(scanner).error

				let expectedError = ScannableError(message: "empty or unterminated string after dependency type", currentLine: "\(dependencyType!) \"dependency")
				expect(error) == expectedError
			}

			it("should fail with empty dependency") {
				let scanner = Scanner(string: "\(dependencyType!) \" \"")

				let error = Dependency.from(scanner).error

				let expectedError = ScannableError(message: "empty or unterminated string after dependency type", currentLine: "\(dependencyType!) \" \"")
				expect(error) == expectedError
			}
		}

		describe("name") {
			context ("github") {
				it("should equal the name of a github.com repo") {
					let dependency = Dependency.gitHub(.dotCom, Repository(owner: "owner", name: "name"))

					expect(dependency.name) == "name"
				}

				it("should equal the name of an enterprise github repo") {
					let enterpriseRepo = Repository(
						owner: "owner",
						name: "name")

					let dependency = Dependency.gitHub(.enterprise(url: URL(string: "http://server.com")!), enterpriseRepo)

					expect(dependency.name) == "name"
				}
			}

			context("git") {
				it("should be the last component of the URL") {
					let dependency = Dependency.git(GitURL("ssh://server.com/myproject"))

					expect(dependency.name) == "myproject"
				}
				
				it("should be the domain when there is no path") {
					let dependency = Dependency.git(GitURL("ssh://server.com"))
					
					expect(dependency.name) == "server.com"
				}

				it("should not include the trailing git suffix") {
					let dependency = Dependency.git(GitURL("ssh://server.com/myproject.git"))

					expect(dependency.name) == "myproject"
				}

				it("should be the entire URL string if there is no last component") {
					let dependency = Dependency.git(GitURL("whatisthisurleven"))

					expect(dependency.name) == "whatisthisurleven"
				}
				
				it("should be the last component of scp url with a path") {
					let dependency = Dependency.git(GitURL("git@github.com:antitypical/Result.git"))
					
					expect(dependency.name) == "Result"
				}
				
				it("should be the last component of scp url") {
					let dependency = Dependency.git(GitURL("git@github.com:Result.git"))
					
					expect(dependency.name) == "Result"
				}
			}

			context("binary") {
				it("should be the last component of the URL") {
					let dependency = Dependency.binary(URL(string: "https://server.com/myproject")!)

					expect(dependency.name) == "myproject"
				}
				
				it("should be the domain when there is no path") {
					let dependency = Dependency.git(GitURL("https://server.com"))
					
					expect(dependency.name) == "server.com"
				}

				it("should not include the trailing git suffix") {
					let dependency = Dependency.binary(URL(string: "https://server.com/myproject.json")!)

					expect(dependency.name) == "myproject"
				}
			}
		}
		
		describe("cacheName") {
			context ("github") {
				it("should equal owner_name of a github.com repo") {
					let dependency = Dependency.gitHub(.dotCom, Repository(owner: "owner", name: "name"))
					
					expect(dependency.cacheName) == "owner_name"
				}
				
				it("should equal owner_name of an enterprise github repo") {
					let enterpriseRepo = Repository(
						owner: "owner",
						name: "name")
					
					let dependency = Dependency.gitHub(.enterprise(url: URL(string: "http://server.com")!), enterpriseRepo)
					
					expect(dependency.cacheName) == "owner_name"
				}
			}
			
			context("git") {
				it("should be the last component of the URL") {
					let dependency = Dependency.git(GitURL("ssh://server.com/myproject"))
					
					expect(dependency.cacheName) == "server_com_myproject"
				}
				
				it("should not include the trailing git suffix") {
					let dependency = Dependency.git(GitURL("ssh://server.com/myproject.git"))
					
					expect(dependency.cacheName) == "server_com_myproject"
				}
				
				it("should be the entire URL string if there is no last component") {
					let dependency = Dependency.git(GitURL("whatisthisurleven"))
					
					expect(dependency.cacheName) == "whatisthisurleven"
				}
				
				it("should be the owner_name when there are 3 components of the path") {
					let dependency = Dependency.git(GitURL("path/to/project"))
					
					expect(dependency.cacheName) == "path_to_project"
				}
				
				it("should be the name when there is one components of the URL") {
					let dependency = Dependency.git(GitURL("path/project"))
					
					expect(dependency.cacheName) == "path_project"
				}
				
				it("should be the owner_name when there are 2 components of the URL") {
					let dependency = Dependency.git(GitURL("ssh://server.com/myname/myproject"))
					
					expect(dependency.cacheName) == "server_com_myname_myproject"
				}
				
				it("should be the owner_name when there are 2 components of the URL and still no trailing git suffix") {
					let dependency = Dependency.git(GitURL("ssh://server.com/myname/myproject.git"))
					
					expect(dependency.cacheName) == "server_com_myname_myproject"
				}
			}
			
			context("binary") {
				it("should be the last component of the URL") {
					let dependency = Dependency.binary(URL(string: "https://server.com/myproject")!)
					
					expect(dependency.cacheName) == "https___server_com_myproject"
				}
				
				it("should be the domain when there is no path") {
					let dependency = Dependency.binary(URL(string: "https://server.com")!)
					
					expect(dependency.cacheName) == "https___server_com"
				}
				
				it("should not include the trailing json suffix") {
					let dependency = Dependency.binary(URL(string: "https://server.com/myproject.json")!)
					
					expect(dependency.cacheName) == "https___server_com_myproject_json"
				}
				
				it("should be owner_name when there are multiple components of the path") {
					let dependency = Dependency.binary(URL(string: "path/to/project")!)
					
					expect(dependency.cacheName) == "path_to_project"
				}
				
				it("should be owner_name when there are 2 components of the path") {
					let dependency = Dependency.binary(URL(string: "path/project")!)
					
					expect(dependency.cacheName) == "path_project"
				}
				
				it("should be owner_name when there are 2 components of the URL") {
					let dependency = Dependency.binary(URL(string: "https://server.com/myname/myproject")!)
					
					expect(dependency.cacheName) == "https___server_com_myname_myproject"
				}
				
				it("should be owner_name when there are 2 components of the URL and still no trailing json suffix") {
					let dependency = Dependency.binary(URL(string: "https://server.com/myname/myproject.json")!)
					
					expect(dependency.cacheName) == "https___server_com_myname_myproject_json"
				}
			}
		}

		describe("from") {
			context("github") {
				it("should read a github.com dependency") {
					let scanner = Scanner(string: "github \"ReactiveCocoa/ReactiveCocoa\"")

					let dependency = Dependency.from(scanner).value

					let expectedRepo = Repository(owner: "ReactiveCocoa", name: "ReactiveCocoa")
					expect(dependency) == .gitHub(.dotCom, expectedRepo)
				}

				it("should read a github.com dependency with full url") {
					let scanner = Scanner(string: "github \"https://github.com/ReactiveCocoa/ReactiveCocoa\"")

					let dependency = Dependency.from(scanner).value

					let expectedRepo = Repository(owner: "ReactiveCocoa", name: "ReactiveCocoa")
					expect(dependency) == .gitHub(.dotCom, expectedRepo)
				}

				it("should read an enterprise github dependency") {
					let scanner = Scanner(string: "github \"http://mysupercoolinternalwebhost.com/ReactiveCocoa/ReactiveCocoa\"")

					let dependency = Dependency.from(scanner).value

					let expectedRepo = Repository(
						owner: "ReactiveCocoa",
						name: "ReactiveCocoa"
					)
					expect(dependency) == .gitHub(.enterprise(url: URL(string: "http://mysupercoolinternalwebhost.com")!), expectedRepo)
				}

				it("should fail with invalid github.com dependency") {
					let scanner = Scanner(string: "github \"Whatsthis\"")

					let error = Dependency.from(scanner).error

					let expectedError = ScannableError(message: "invalid GitHub repository identifier \"Whatsthis\"")
					expect(error) == expectedError
				}

				it("should fail with invalid enterprise github dependency") {
					let scanner = Scanner(string: "github \"http://mysupercoolinternalwebhost.com/ReactiveCocoa\"")

					let error = Dependency.from(scanner).error

					let expectedError = ScannableError(message: "invalid GitHub repository identifier \"http://mysupercoolinternalwebhost.com/ReactiveCocoa\"")
					expect(error) == expectedError
				}

				itBehavesLike("invalid dependency") { ["dependencyType": "github"] }
			}

			context("git") {
				it("should read a git URL") {
					let scanner = Scanner(string: "git \"mygiturl\"")

					let dependency = Dependency.from(scanner).value

					expect(dependency) == .git(GitURL("mygiturl"))
				}

				it("should read a git dependency as github") {
					let scanner = Scanner(string: "git \"ssh://git@github.com:owner/name\"")

					let dependency = Dependency.from(scanner).value

					let expectedRepo = Repository(owner: "owner", name: "name")

					expect(dependency) == .gitHub(.dotCom, expectedRepo)
				}

				it("should read a git dependency as github") {
					let scanner = Scanner(string: "git \"https://github.com/owner/name\"")

					let dependency = Dependency.from(scanner).value

					let expectedRepo = Repository(owner: "owner", name: "name")

					expect(dependency) == .gitHub(.dotCom, expectedRepo)
				}

				it("should read a git dependency as github") {
					let scanner = Scanner(string: "git \"git@github.com:owner/name\"")

					let dependency = Dependency.from(scanner).value

					let expectedRepo = Repository(owner: "owner", name: "name")

					expect(dependency) == .gitHub(.dotCom, expectedRepo)
				}

				itBehavesLike("invalid dependency") { ["dependencyType": "git"] }
			}

			context("binary") {
				it("should read a URL with https scheme") {
					let scanner = Scanner(string: "binary \"https://mysupercoolinternalwebhost.com/\"")

					let dependency = Dependency.from(scanner).value

					expect(dependency) == .binary(URL(string: "https://mysupercoolinternalwebhost.com/")!)
				}

				it("should read a URL with file scheme") {
					let scanner = Scanner(string: "binary \"file:///my/domain/com/framework.json\"")
					
					let dependency = Dependency.from(scanner).value
					
					expect(dependency) == .binary(URL(string: "file:///my/domain/com/framework.json")!)
				}

				it("should fail with non-https URL") {
					let scanner = Scanner(string: "binary \"nope\"")

					let error = Dependency.from(scanner).error

					expect(error) == ScannableError(message: "non-https, non-file URL found for dependency type `binary`", currentLine: "binary \"nope\"")
				}

				it("should fail with invalid URL") {
					let scanner = Scanner(string: "binary \"nop@%@#^@e\"")

					let error = Dependency.from(scanner).error

					expect(error) == ScannableError(message: "invalid URL found for dependency type `binary`", currentLine: "binary \"nop@%@#^@e\"")
				}

				itBehavesLike("invalid dependency") { ["dependencyType": "binary"] }
			}
		}
	}
}
