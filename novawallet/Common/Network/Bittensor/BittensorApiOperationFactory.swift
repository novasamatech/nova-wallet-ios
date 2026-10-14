import Foundation
import NovaCrypto
import Operation_iOS

protocol BittensorApiWireChecked {
    func validateWire() throws
}

protocol BittensorApiGenerationalResponse {
    var generationOrder: BittensorApiGenerationOrder { get }
}

protocol BittensorApiContextObserving: AnyObject {
    func addContextObserver(_ owner: AnyObject, closure: @escaping () -> Void)
}

struct BittensorApiWireViolation: Error {
    let field: String
}

final class BittensorApiOperationFactory {
    static let pageSize = 100
    static let pageRange = 1 ... 100

    let transport: BittensorApiTransportProtocol
    let cache: BittensorApiResponseCache
    private let logger: LoggerProtocol

    init(
        transport: BittensorApiTransportProtocol,
        cache: BittensorApiResponseCache,
        logger: LoggerProtocol
    ) {
        self.transport = transport
        self.cache = cache
        self.logger = logger
        let revision = transport.addInvalidationObserver(cache) { [weak cache] in cache?.invalidate(before: $0) }
        cache.invalidate(before: revision)
    }
}

extension BittensorApiOperationFactory: BittensorApiContextObserving {
    func addContextObserver(_ owner: AnyObject, closure: @escaping () -> Void) {
        transport.addContextObserver(owner, closure: closure)
    }
}

extension BittensorApiOperationFactory: BittensorApiOperationFactoryProtocol {
    func createSubnetsWrapper() -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.SubnetCollection>> {
        createWrapper(route: .subnets, path: "/subnets")
    }

    func peekSubnets() -> HTTPCachePeek<BittensorApiResult<BittensorApi.SubnetCollection>> {
        peek(path: "/subnets")
    }

    func createValidatorsWrapper(
        netuid: UInt16
    ) -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.ValidatorCollection>> {
        createWrapper(route: .validators, path: "/subnets/\(netuid)/validators")
    }

    func createAlphaYieldWrapper(
        netuid: UInt16,
        page: Int
    ) -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.AlphaYieldCollection>> {
        guard netuid != 0 else {
            return .createWithError(BittensorApiError.rejected(code: nil, requestId: nil))
        }
        return createPagedWrapper(route: .alphaYield, path: "/subnets/\(netuid)/yields/alpha", page: page)
    }

    func peekAlphaYield(
        netuid: UInt16,
        page: Int
    ) -> HTTPCachePeek<BittensorApiResult<BittensorApi.AlphaYieldCollection>> {
        guard netuid != 0 else { return .miss }
        return peekPage(path: "/subnets/\(netuid)/yields/alpha", page: page)
    }

    func createRootValidatorsWrapper()
        -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.RootValidatorCollection>> {
        createWrapper(route: .rootValidators, path: "/root/validators")
    }

    func peekRootValidators() -> HTTPCachePeek<BittensorApiResult<BittensorApi.RootValidatorCollection>> {
        peek(path: "/root/validators")
    }

    func createRootOverviewWrapper() -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.RootOverview>> {
        createWrapper(route: .rootOverview, path: "/root/overview")
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
        createSearchWrapper(
            route: .portfolioHistory,
            accountSubject: accountSubject,
            page: nil,
            queryItems: [URLQueryItem(name: "period", value: period.rawValue)]
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
        peek(path: "/recommendations/subnets")
    }

    func createRankedValidatorsWrapper(
        netuid: UInt16
    ) -> CompoundOperationWrapper<BittensorApiResult<BittensorApi.RankedValidatorCollection>> {
        createWrapper(route: .rankedValidators, path: "/recommendations/subnets/\(netuid)/validators")
    }
}

private extension BittensorApiOperationFactory {
    enum Route {
        case subnets
        case validators
        case alphaYield
        case rootValidators
        case rootOverview
        case operations
        case portfolioHistory
        case recommendations
        case rankedSubnets
        case rankedValidators

        var pathTemplate: String {
            switch self {
            case .subnets:
                return "/subnets"
            case .validators:
                return "/subnets/{netuid}/validators"
            case .alphaYield:
                return "/subnets/{netuid}/yields/alpha"
            case .rootValidators:
                return "/root/validators"
            case .rootOverview:
                return "/root/overview"
            case .operations:
                return "/operations/search"
            case .portfolioHistory:
                return "/portfolio/history/search"
            case .recommendations:
                return "/recommendations"
            case .rankedSubnets:
                return "/recommendations/subnets"
            case .rankedValidators:
                return "/recommendations/subnets/{netuid}/validators"
            }
        }
    }

    func createPagedWrapper<T: Decodable & BittensorApiWireChecked>(
        route: Route,
        path: String,
        page: Int
    ) -> CompoundOperationWrapper<BittensorApiResult<T>> {
        guard Self.pageRange.contains(page) else {
            return .createWithError(BittensorApiError.rejected(code: nil, requestId: nil))
        }

        return createWrapper(route: route, path: path, queryItems: Self.pagedQueryItems(page: page))
    }

    func peekPage<T>(path: String, page: Int) -> HTTPCachePeek<BittensorApiResult<T>> {
        guard Self.pageRange.contains(page) else {
            return .miss
        }

        return peek(path: path, queryItems: Self.pagedQueryItems(page: page))
    }

    func peek<T>(path: String, queryItems: [URLQueryItem] = []) -> HTTPCachePeek<BittensorApiResult<T>> {
        cache.peek(
            Self.cacheKey(path: path, queryItems: queryItems),
            invalidationRevision: transport.invalidationRevision
        ).map { try Self.makeResult(from: $0, isFromExpiredCache: true) }
    }

    func createSearchWrapper<T: Decodable & BittensorApiWireChecked>(
        route: Route,
        accountSubject: AccountAddress,
        page: Int?,
        queryItems: [URLQueryItem] = []
    ) -> CompoundOperationWrapper<BittensorApiResult<T>> {
        guard Self.isValidAccountSubject(accountSubject), page.map(Self.pageRange.contains) ?? true else {
            return .createWithError(BittensorApiError.rejected(code: nil, requestId: nil))
        }

        let subjectItem = URLQueryItem(name: "accountSubject", value: accountSubject)
        let pageItems = page.map { [URLQueryItem(name: "page", value: String($0))] } ?? []

        return createWrapper(
            route: route,
            path: route.pathTemplate,
            queryItems: [subjectItem] + pageItems + queryItems
        )
    }

    func createWrapper<T: Decodable & BittensorApiWireChecked>(
        route: Route,
        path: String,
        queryItems: [URLQueryItem] = []
    ) -> CompoundOperationWrapper<BittensorApiResult<T>> {
        let request = BittensorApiRequest(
            path: path,
            pathTemplate: route.pathTemplate,
            queryItems: queryItems
        )

        let job = BittensorApiCacheJob(
            key: Self.cacheKey(path: path, queryItems: queryItems),
            currentInvalidationRevision: { [transport] in transport.invalidationRevision },
            admit: { [transport] in transport.createAdmissionWrapper() },
            fetch: { [transport, logger] admission in
                Self.createFetchWrapper(
                    T.self, responseWrapper: transport.createResponseWrapper(for: request, admission: admission),
                    route: route, logger: logger
                )
            }
        )

        let entryWrapper = cache.createWrapper(for: job)

        let resultOperation = ClosureOperation<BittensorApiResult<T>> {
            let entry = try entryWrapper.targetOperation.extractNoCancellableResultData()

            return try Self.makeResult(from: entry, isFromExpiredCache: false)
        }

        resultOperation.addDependency(entryWrapper.targetOperation)

        return entryWrapper.insertingTail(operation: resultOperation)
    }

    static func pagedQueryItems(page: Int) -> [URLQueryItem] {
        [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "pageSize", value: String(pageSize))
        ]
    }

    static func cacheKey(path: String, queryItems: [URLQueryItem]) -> BittensorApiCacheKey {
        BittensorApiCacheKey(
            path: path,
            query: queryItems.map { "\($0.name)=\($0.value ?? "")" }.sorted()
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
        responseWrapper: CompoundOperationWrapper<BittensorApiRawResponse>,
        route: Route,
        logger: LoggerProtocol
    ) -> CompoundOperationWrapper<BittensorApiFetchedValue> {
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
                detail: "GET \(route.pathTemplate): invalid \(violation.field)",
                requestId: response.requestId
            )
        } catch {
            throw BittensorApiError.contractViolation(
                detail: "GET \(route.pathTemplate): \(describe(error))",
                requestId: response.requestId
            )
        }

        let generational = value as? BittensorApiGenerationalResponse

        return BittensorApiFetchedValue(
            value: value,
            requestId: response.requestId,
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

    static func isValidAccountSubject(_ subject: AccountAddress) -> Bool {
        let factory = SS58AddressFactory()

        do {
            let type = try factory.type(fromAddress: subject).uint16Value

            guard type == SubstrateConstants.genericAddressPrefix else {
                return false
            }

            _ = try factory.accountId(fromAddress: subject, type: type)

            return true
        } catch {
            return false
        }
    }
}
