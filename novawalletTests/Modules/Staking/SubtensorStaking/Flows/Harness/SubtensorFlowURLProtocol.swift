import Foundation
import XCTest
@testable import novawallet

struct SubtensorFlowHTTPRequest: Equatable {
    let method: String
    let url: String
    let headers: [String: String]
    let body: Data
}

struct SubtensorFlowHTTPReply {
    let statusCode: Int
    let headers: [String: String]
    let body: Data
}

struct SubtensorFlowPricePoint {
    let milliseconds: UInt64
    let value: Decimal
}

extension SubtensorFlowHTTPReply {
    static func json(_ document: Any) -> SubtensorFlowHTTPReply {
        let body = (try? JSONSerialization.data(withJSONObject: document, options: [.sortedKeys])) ?? Data()

        return SubtensorFlowHTTPReply(statusCode: 200, headers: ["Content-Type": "application/json"], body: body)
    }

    static func bittensor(_ document: [String: Any], route: BittensorApiFixtureRoute) -> SubtensorFlowHTTPReply {
        let reply = json(document)
        var headers = reply.headers
        headers[Constants.cacheControlHeader] = BittensorApiFixtureRouter.cacheControl(for: route, document: document)

        return SubtensorFlowHTTPReply(statusCode: reply.statusCode, headers: headers, body: reply.body)
    }

    static func jsonText(_ text: String) -> SubtensorFlowHTTPReply {
        SubtensorFlowHTTPReply(statusCode: 200, headers: ["Content-Type": "application/json"], body: Data(text.utf8))
    }

    static func marketChart(_ points: [SubtensorFlowPricePoint]) -> SubtensorFlowHTTPReply {
        let prices = points.map { "[\($0.milliseconds),\($0.value)]" }.joined(separator: ",")

        return jsonText(#"{"prices":[\#(prices)]}"#)
    }

    static func notFoundPlainText() -> SubtensorFlowHTTPReply {
        SubtensorFlowHTTPReply(
            statusCode: 404,
            headers: ["Content-Type": "text/plain; charset=utf-8"],
            body: Data("404 page not found".utf8)
        )
    }

    static func apiError(statusCode: Int, code: String, requestId: String) -> SubtensorFlowHTTPReply {
        SubtensorFlowHTTPReply(
            statusCode: statusCode,
            headers: [
                "Content-Type": "application/json",
                "X-Request-ID": requestId,
                Constants.cacheControlHeader: "no-store"
            ],
            body: Data(#"{"error":{"code":"\#(code)","message":"disabled"}}"#.utf8)
        )
    }
}

private extension SubtensorFlowHTTPReply {
    enum Constants {
        static let cacheControlHeader = "Cache-Control"
    }
}

enum SubtensorFlowHost {
    static let bittensorGateway = URL(string: "https://bittensor.test/")!
    static let subnetLogos = URL(string: "https://subnet-logos.test/subnets.json")!

    static let priceAPI = PriceAPI.baseURL.absoluteString

    static let subnetMarkets = priceAPI + "/coins/markets" +
        "?vs_currency=usd&category=bittensor-subnets&per_page=250&page=1&sparkline=true&price_change_percentage=7d"

    static func bittensor(_ path: String) -> String {
        "https://bittensor.test/v1/bittensor" + path
    }

    static func marketChart(coinId: String, days: String) -> String {
        "\(priceAPI)/coins/\(coinId)/market_chart?vs_currency=usd&days=\(days)"
    }
}

final class SubtensorFlowURLProtocol: URLProtocol {
    private struct Route: Hashable {
        let method: String
        let url: String
        let body: Data
    }

    private static let lock = NSLock()
    private static var routes: [Route: SubtensorFlowHTTPReply] = [:]
    private static var requests: [SubtensorFlowHTTPRequest] = []
    private static var unexpected: [SubtensorFlowHTTPRequest] = []

    static func install() {
        reset()
        URLProtocol.registerClass(Self.self)
    }

    static func uninstall() -> [SubtensorFlowHTTPRequest] {
        URLProtocol.unregisterClass(Self.self)

        let unexpectedRequests = unexpectedRequests
        reset()

        return unexpectedRequests
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [Self.self]

        return URLSession(configuration: configuration)
    }

    static func serve(_ method: String, _ url: String, body: Data = Data(), reply: SubtensorFlowHTTPReply) {
        lock.lock()
        routes[Route(method: method, url: url, body: body)] = reply
        lock.unlock()
    }

    static func serveBittensor(_ path: String, reply: SubtensorFlowHTTPReply) {
        serve("GET", SubtensorFlowHost.bittensor(path), reply: reply)
    }

    static func serveFixture(_ route: BittensorApiFixtureRoute) {
        guard let path = fixturePath(for: route) else {
            XCTFail("The flow stub serves GET fixture routes only, not \(route)")
            return
        }

        serveBittensor(path, reply: .bittensor(BittensorApiFixtureRouter.document(for: route), route: route))
    }

    static func serveOperationsFixture(accountSubject: AccountAddress, pages: ClosedRange<Int>) {
        for page in pages {
            let route = BittensorApiFixtureRoute.operations(page: page)

            serve(
                "POST",
                SubtensorFlowHost.bittensor("/operations/search"),
                body: operationsSearchBody(accountSubject: accountSubject, page: page),
                reply: .bittensor(BittensorApiFixtureRouter.document(for: route), route: route)
            )
        }
    }

    static func operationsSearchBody(accountSubject: AccountAddress, page: Int) -> Data {
        Data(#"{"accountSubject":"\#(accountSubject)","page":\#(page)}"#.utf8)
    }

    static func serveSubnetLogos() {
        serve(
            "GET",
            SubtensorFlowHost.subnetLogos.absoluteString,
            reply: .jsonText(SubtensorFlowChainWorld.subnetLogosJSON)
        )
    }

    static func serveMarketChart(coinId: String, days: String, points: [SubtensorFlowPricePoint]) {
        serve("GET", SubtensorFlowHost.marketChart(coinId: coinId, days: days), reply: .marketChart(points))
    }

    static func serveSubnetMarkets(chutesWeekStart start: Decimal, end: Decimal) {
        serve("GET", SubtensorFlowHost.subnetMarkets, reply: .json([[
            "id": "chutes",
            "symbol": "sn64",
            "last_updated": ISO8601DateFormatter().string(from: Date()),
            "price_change_percentage_7d_in_currency": NSDecimalNumber(decimal: (end / start - 1) * 100),
            "sparkline_in_7d": ["price": [NSDecimalNumber(decimal: start), NSDecimalNumber(decimal: end)]]
        ]]))
    }

    static var recordedRequests: [SubtensorFlowHTTPRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }

    static var unexpectedRequests: [SubtensorFlowHTTPRequest] {
        lock.lock()
        defer { lock.unlock() }
        return unexpected
    }

    override class func canInit(with _: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let recorded = SubtensorFlowHTTPRequest(
            method: request.httpMethod ?? "GET",
            url: request.url?.absoluteString ?? "",
            headers: request.allHTTPHeaderFields ?? [:],
            body: Self.readBody(of: request)
        )

        Self.lock.lock()
        Self.requests.append(recorded)
        let reply = Self.routes[Route(method: recorded.method, url: recorded.url, body: recorded.body)]

        if reply == nil {
            Self.unexpected.append(recorded)
        }

        Self.lock.unlock()

        guard let reply, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: reply.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: reply.headers
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private extension SubtensorFlowURLProtocol {
    static func reset() {
        lock.lock()
        routes = [:]
        requests = []
        unexpected = []
        lock.unlock()
    }

    static func fixturePath(for route: BittensorApiFixtureRoute) -> String? {
        switch route {
        case .subnets:
            return "/subnets"
        case let .validators(netuid):
            return "/subnets/\(netuid)/validators"
        case let .rootYield(page, pageSize):
            return "/yields/root?page=\(page)&pageSize=\(pageSize)"
        case let .alphaYield(netuid, page, pageSize):
            return "/subnets/\(netuid)/yields/alpha?page=\(page)&pageSize=\(pageSize)"
        case .recommendations:
            return "/recommendations"
        case .rankedSubnets:
            return "/recommendations/subnets"
        case .operations:
            return nil
        }
    }

    static func readBody(of request: URLRequest) -> Data {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return Data()
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)

        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }

        return data
    }
}
