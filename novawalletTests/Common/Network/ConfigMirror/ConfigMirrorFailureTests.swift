import XCTest
import Operation_iOS
@testable import novawallet

final class ConfigMirrorFailureTests: XCTestCase {
    func testMirrorIsUnavailableWhenItCanNotBeReachedInTimeOrAnswersWithServerErrorOrLimit() {
        let failures: [ConfigMirrorFailure] = [
            .transport(URLError(.timedOut)),
            .transport(URLError(.cannotConnectToHost)),
            .transport(URLError(.cannotFindHost)),
            .transport(URLError(.dnsLookupFailed)),
            .transport(URLError(.networkConnectionLost)),
            .transport(URLError(.secureConnectionFailed)),
            .transport(URLError(.serverCertificateUntrusted)),
            .transport(URLError(.badServerResponse)),
            .transport(NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)),
            .deadlineExceeded,
            .unexpectedStatus(500),
            .unexpectedStatus(502),
            .unexpectedStatus(503),
            .unexpectedStatus(504),
            .unexpectedStatus(429)
        ]

        for failure in failures {
            XCTAssertEqual(failure.verdict, .unavailable, "\(failure)")
        }
    }

    func testMirrorIsReachableWhenItAnswersAboutOneFile() {
        let failures: [ConfigMirrorFailure] = [
            .unexpectedStatus(404),
            .unexpectedStatus(400),
            .unexpectedStatus(403),
            .unexpectedStatus(408),
            .unexpectedStatus(204),
            .unexpectedStatus(301),
            .unexpectedStatus(302),
            .emptyBody,
            .malformedJson,
            .missingCommitHeader
        ]

        for failure in failures {
            XCTAssertEqual(failure.verdict, .reachable, "\(failure)")
        }
    }

    func testCancellationAndDeviceConnectivitySayNothingAboutMirror() {
        let failures: [ConfigMirrorFailure] = [
            .transport(URLError(.cancelled)),
            .transport(URLError(.notConnectedToInternet)),
            .transport(URLError(.dataNotAllowed)),
            .transport(URLError(.internationalRoamingOff)),
            .transport(URLError(.callIsActive)),
            .transport(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)),
            .transport(NetworkBaseError.unexpectedEmptyData),
            .transport(NSError(domain: NSPOSIXErrorDomain, code: 57)),
            .unexpectedStatus(nil)
        ]

        for failure in failures {
            XCTAssertEqual(failure.verdict, .unknown, "\(failure)")
        }
    }
}
