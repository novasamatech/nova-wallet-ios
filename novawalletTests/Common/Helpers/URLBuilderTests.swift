import XCTest
@testable import novawallet

class URLBuilderTests: XCTestCase {
    private struct Pagination: Codable {
        var offset: Int
        var count: Int
    }

    private struct ProjectVote: Equatable, Codable {
        enum CodingKeys: String, CodingKey {
            case projectId
            case votes
        }

        var projectId: String
        var votes: String
    }

    func testQueryParams() {
        // given
        let offset = 10
        let count = 10
        let template = "https://novawallet.io/project?offset={offset}&count={count}"
        let enpointBuilder = URLBuilder(urlTemplate: template)

        do {
            let url = try enpointBuilder.buildURL(with: Pagination(offset: offset, count: count))

            let expectedUrl = URL(string: "https://novawallet.io/project?offset=\(offset)&count=\(count)")

            XCTAssertEqual(url, expectedUrl)

            let regex = try enpointBuilder.buildRegex()
            let expectedRegex = "https://novawallet\\.io/project\\?offset=\(URLBuilder.regexReplacement)&count=\(URLBuilder.regexReplacement)"
            XCTAssertEqual(regex, expectedRegex)
        } catch {
            XCTFail("Error: \(error)")
        }
    }

    func testPathWithQueryParams() {
        // given
        let projectId = "1234"
        let votes = "10.2"
        let template = "https://novawallet.io/project/{projectId}/vote?{votes}"
        let enpointBuilder = URLBuilder(urlTemplate: template)

        do {
            let url = try enpointBuilder.buildURL(with: ProjectVote(projectId: projectId, votes: votes))

            let expectedUrl = URL(string: "https://novawallet.io/project/\(projectId)/vote?\(votes)")

            XCTAssertEqual(url, expectedUrl)

            let regex = try enpointBuilder.buildRegex()
            let expectedRegex = "https://novawallet\\.io/project/\(URLBuilder.regexReplacement)/vote\\?\(URLBuilder.regexReplacement)"
            XCTAssertEqual(regex, expectedRegex)
        } catch {
            XCTFail("Error: \(error)")
        }
    }

    func testSingleParameter() {
        // given
        let code = "123213"
        let template = "https://novawallet.io/invitations/{invitationCode}"
        let enpointBuilder = URLBuilder(urlTemplate: template)

        do {
            let url = try enpointBuilder.buildParameterURL(code)
            let expectedUrl = URL(string: "https://novawallet.io/invitations/\(code)")

            XCTAssertEqual(url, expectedUrl)
        } catch {
            XCTFail("Error: \(error)")
        }
    }

    func testClosureParameters() {
        // given
        let keys: [String: String] = [
            "apikey1": "0",
            "apikey2": "1"
        ]

        let template = "https://novawallet.io/api/{apikey1}?key={apikey2}"
        let enpointBuilder = URLBuilder(urlTemplate: template)

        do {
            let url = try enpointBuilder.buildBy { param in
                guard let key = keys[param] else {
                    throw CommonError.undefined
                }

                return key
            }

            let expectedUrl = URL(string: "https://novawallet.io/api/0?key=1")

            XCTAssertEqual(url, expectedUrl)
        } catch {
            XCTFail("Error: \(error)")
        }
    }
}
