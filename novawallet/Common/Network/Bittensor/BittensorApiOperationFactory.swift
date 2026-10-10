import Foundation
import Operation_iOS
import NovaCrypto

protocol BittensorApiWireChecked {
    func validateWire() throws
}

protocol BittensorApiGenerationalResponse {
    var generationOrder: BittensorApiGenerationOrder { get }
}

struct BittensorApiWireViolation: Error {
    let field: String
}

final class BittensorApiOperationFactory {
    static let pageSize = 100
    static let pageRange = 1 ... 100

    private let transport: BittensorApiTransportProtocol
    private let cache: BittensorApiResponseCache
    private let logger: LoggerProtocol

    init(
        transport: BittensorApiTransportProtocol,
        cache: BittensorApiResponseCache,
        logger: LoggerProtocol
    ) {
        self.transport = transport
        self.cache = cache
        self.logger = logger
    }
}

extension BittensorApiOperationFactory: BittensorApiOperationFactoryProtocol {
    func createSubnetsWrapper() -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.SubnetCollection>> {
        createWrapper(route: .subnets, path: "/subnets")
    }

    func peekSubnets() -> HTTPCachePeek<BittensorApiResult<BittensorApi.SubnetCollection>> {
        peek(route: .subnets, path: "/subnets")
    }

    func createValidatorsWrapper(
        netuid: UInt16
    ) -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.ValidatorCollection>> {
        createWrapper(route: .validators, path: "/subnets/\(netuid)/validators")
    }

    func peekValidators(netuid: UInt16) -> HTTPCachePeek<BittensorApiResult<BittensorApi.ValidatorCollection>> {
        peek(route: .validators, path: "/subnets/\(netuid)/validators")
    }

    func createRootYieldWrapper(
        page: Int
    ) -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.RootYieldCollection>> {
        createPagedWrapper(route: .rootYield, path: "/yields/root", page: page)
    }

    func peekRootYield(page: Int) -> HTTPCachePeek<BittensorApiResult<BittensorApi.RootYieldCollection>> {
        peekPage(route: .rootYield, path: "/yields/root", page: page)
    }

    func createAlphaYieldWrapper(
        netuid: UInt16,
        page: Int
    ) -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.AlphaYieldCollection>> {
        createPagedWrapper(route: .alphaYield, path: "/subnets/\(netuid)/yields/alpha", page: page)
    }

    func peekAlphaYield(
        netuid: UInt16,
        page: Int
    ) -> HTTPCachePeek<BittensorApiResult<BittensorApi.AlphaYieldCollection>> {
        peekPage(route: .alphaYield, path: "/subnets/\(netuid)/yields/alpha", page: page)
    }

    func createOperationsWrapper(
        accountSubject: AccountAddress,
        page: Int?
    ) -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.OperationCollection>> {
        createSearchWrapper(route: .operations, accountSubject: accountSubject, page: page)
    }

    func createPortfolioHistoryWrapper(
        accountSubject: AccountAddress,
        period: BittensorApi.PortfolioHistoryPeriod
    ) -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.PortfolioHistoryCollection>> {
        createAccountWrapper(
            route: .portfolioHistory,
            accountSubject: accountSubject,
            body: BittensorApi.PortfolioHistoryRequest(accountSubject: accountSubject, period: period)
        )
    }

    func createRecommendationsWrapper()
        -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.RecommendationCollection>> {
        createWrapper(route: .recommendations, path: "/recommendations")
    }

    func createRankedSubnetsWrapper()
        -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.SubnetRankingCollection>> {
        createWrapper(route: .rankedSubnets, path: "/recommendations/subnets")
    }

    func peekRankedSubnets() -> HTTPCachePeek<BittensorApiResult<BittensorApi.SubnetRankingCollection>> {
        peek(route: .rankedSubnets, path: "/recommendations/subnets")
    }
}

private extension BittensorApiOperationFactory {
    enum Route {
        case subnets
        case validators
        case rootYield
        case alphaYield
        case operations
        case portfolioHistory
        case recommendations
        case rankedSubnets

        var method: BittensorApiRequest.Method {
            switch self {
            case .operations, .portfolioHistory:
                return .post
            default:
                return .get
            }
        }

        var pathTemplate: String {
            switch self {
            case .subnets:
                return "/subnets"
            case .validators:
                return "/subnets/{netuid}/validators"
            case .rootYield:
                return "/yields/root"
            case .alphaYield:
                return "/subnets/{netuid}/yields/alpha"
            case .operations:
                return "/operations/search"
            case .portfolioHistory:
                return "/portfolio/history/search"
            case .recommendations:
                return "/recommendations"
            case .rankedSubnets:
                return "/recommendations/subnets"
            }
        }
    }

    static let searchEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    func createPagedWrapper<T: Decodable & BittensorApiWireChecked>(
        route: Route,
        path: String,
        page: Int
    ) -> CompoundOperationWrapper<BittensorApiResult<T>> {
        guard Self.pageRange.contains(page) else {
            return .createWithError(BittensorApiError.invalidRequest(code: nil, requestId: nil))
        }

        return createWrapper(route: route, path: path, queryItems: Self.pagedQueryItems(page: page))
    }

    func peekPage<T>(route: Route, path: String, page: Int) -> HTTPCachePeek<BittensorApiResult<T>> {
        guard Self.pageRange.contains(page) else {
            return .miss
        }

        return peek(route: route, path: path, queryItems: Self.pagedQueryItems(page: page))
    }

    func peek<T>(route: Route, path: String, queryItems: [URLQueryItem] = []) -> HTTPCachePeek<BittensorApiResult<T>> {
        let cached = cache.peek(Self.cacheKey(route: route, path: path, queryItems: queryItems, jsonBody: nil))
        let isFromExpiredCache = !cached.isFresh

        return cached.map { try Self.makeResult(from: $0, isFromExpiredCache: isFromExpiredCache) }
    }

    func createSearchWrapper<T: Decodable & BittensorApiWireChecked>(
        route: Route,
        accountSubject: AccountAddress,
        page: Int?
    ) -> CompoundOperationWrapper<BittensorApiResult<T>> {
        guard page.map(Self.pageRange.contains) ?? true else {
            return .createWithError(BittensorApiError.invalidRequest(code: nil, requestId: nil))
        }

        return createAccountWrapper(
            route: route,
            accountSubject: accountSubject,
            body: BittensorApi.SearchRequest(accountSubject: accountSubject, page: page)
        )
    }

    func createAccountWrapper<Body: Encodable, T: Decodable & BittensorApiWireChecked>(
        route: Route,
        accountSubject: AccountAddress,
        body: Body
    ) -> CompoundOperationWrapper<BittensorApiResult<T>> {
        let invalidRequest = BittensorApiError.invalidRequest(code: nil, requestId: nil)

        guard Self.isValidAccountSubject(accountSubject) else {
            return .createWithError(invalidRequest)
        }

        let jsonBody: Data

        do {
            jsonBody = try Self.searchEncoder.encode(body)
        } catch {
            return .createWithError(invalidRequest)
        }

        return createWrapper(
            route: route,
            path: route.pathTemplate,
            jsonBody: jsonBody,
            accountDigest: Data(accountSubject.utf8).sha256()
        )
    }

    func createWrapper<T: Decodable & BittensorApiWireChecked>(
        route: Route,
        path: String,
        queryItems: [URLQueryItem] = [],
        jsonBody: Data? = nil,
        accountDigest: Data? = nil
    ) -> CompoundOperationWrapper<BittensorApiResult<T>> {
        let request = BittensorApiRequest(
            method: route.method,
            path: path,
            pathTemplate: route.pathTemplate,
            queryItems: queryItems,
            jsonBody: jsonBody
        )

        let job = BittensorApiCacheJob(
            key: Self.cacheKey(route: route, path: path, queryItems: queryItems, jsonBody: jsonBody),
            routeKey: BittensorApiRouteKey(
                method: route.method.rawValue,
                pathTemplate: route.pathTemplate,
                accountDigest: accountDigest
            ),
            fetch: { [transport, logger] in
                Self.createFetchWrapper(T.self, request: request, route: route, transport: transport, logger: logger)
            }
        )

        let deliveryWrapper = cache.createWrapper(for: job)

        let resultOperation = ClosureOperation<BittensorApiResult<T>> {
            let delivery = try deliveryWrapper.targetOperation.extractNoCancellableResultData()

            return try Self.makeResult(from: delivery.entry, isFromExpiredCache: delivery.isFromExpiredCache)
        }

        resultOperation.addDependency(deliveryWrapper.targetOperation)

        return deliveryWrapper.insertingTail(operation: resultOperation)
    }

    static func pagedQueryItems(page: Int) -> [URLQueryItem] {
        [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "pageSize", value: String(Self.pageSize))
        ]
    }

    static func cacheKey(
        route: Route,
        path: String,
        queryItems: [URLQueryItem],
        jsonBody: Data?
    ) -> BittensorApiCacheKey {
        BittensorApiCacheKey(
            method: route.method.rawValue,
            path: path,
            query: queryItems.map { "\($0.name)=\($0.value ?? "")" }.sorted(),
            bodyDigest: jsonBody?.sha256()
        )
    }

    static func makeResult<T>(
        from entry: BittensorApiCacheEntry,
        isFromExpiredCache: Bool
    ) throws -> BittensorApiResult<T> {
        guard let value = entry.value as? T else {
            throw BaseOperationError.unexpectedDependentResult
        }

        return BittensorApiResult(
            value: value,
            requestId: entry.requestId,
            receivedAt: entry.receivedAt,
            isFromExpiredCache: isFromExpiredCache
        )
    }

    static func createFetchWrapper<T: Decodable & BittensorApiWireChecked>(
        _ type: T.Type,
        request: BittensorApiRequest,
        route: Route,
        transport: BittensorApiTransportProtocol,
        logger: LoggerProtocol
    ) -> CompoundOperationWrapper<BittensorApiFetchedValue> {
        let responseWrapper = transport.createResponseWrapper(for: request)

        let parseOperation = ClosureOperation<BittensorApiFetchedValue> {
            let response = try responseWrapper.targetOperation.extractNoCancellableResultData()

            do {
                return try parse(type, response: response, route: route)
            } catch let BittensorApiError.contractViolation(detail, requestId) {
                logger.warning("Bittensor API contract violation, request id \(requestId ?? "none"): \(detail)")

                throw BittensorApiError.contractViolation(detail: detail, requestId: requestId)
            }
        }

        parseOperation.addDependency(responseWrapper.targetOperation)

        return responseWrapper.insertingTail(operation: parseOperation)
    }

    static func parse<T: Decodable & BittensorApiWireChecked>(
        _ type: T.Type,
        response: BittensorApiRawResponse,
        route: Route
    ) throws -> BittensorApiFetchedValue {
        let value: T

        do {
            value = try JSONDecoder().decode(type, from: response.body)
            try value.validateWire()
        } catch let violation as BittensorApiWireViolation {
            throw BittensorApiError.contractViolation(
                detail: "\(route.method.rawValue) \(route.pathTemplate): invalid \(violation.field)",
                requestId: response.requestId
            )
        } catch {
            throw BittensorApiError.contractViolation(
                detail: "\(route.method.rawValue) \(route.pathTemplate): \(describe(error))",
                requestId: response.requestId
            )
        }

        let generational = value as? BittensorApiGenerationalResponse

        return BittensorApiFetchedValue(
            value: value,
            requestId: response.requestId,
            cacheDirectives: response.cacheDirectives,
            generation: generational?.generationOrder
        )
    }

    static func describe(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return "undecodable body"
        }

        switch decodingError {
        case let .dataCorrupted(context):
            return "invalid value at \(codingPath(context.codingPath))"
        case let .keyNotFound(key, context):
            return "missing \(codingPath(context.codingPath + [key]))"
        case let .typeMismatch(_, context):
            return "type mismatch at \(codingPath(context.codingPath))"
        case let .valueNotFound(_, context):
            return "null at \(codingPath(context.codingPath))"
        @unknown default:
            return "undecodable body"
        }
    }

    static func codingPath(_ keys: [CodingKey]) -> String {
        let path = keys.map { key in key.intValue.map { "[\($0)]" } ?? "." + key.stringValue }.joined()

        return path.isEmpty ? "body" : path
    }
}
