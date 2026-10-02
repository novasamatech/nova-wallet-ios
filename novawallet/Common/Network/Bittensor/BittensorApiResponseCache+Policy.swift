import Foundation

extension BittensorApiResponseCache {
    static func isSuperseded(_ entry: BittensorApiCacheEntry, newest: BittensorApiGenerationOrder?) -> Bool {
        guard let acceptedNewest = entry.newestGenerationWhenAccepted, let newest else {
            return false
        }

        return acceptedNewest < newest
    }

    func routeNegativeKey(for job: BittensorApiCacheJob) -> NegativeKey {
        .route(method: job.routeKey.method, pathTemplate: job.routeKey.pathTemplate)
    }

    func negativeKeys(for job: BittensorApiCacheJob) -> [NegativeKey] {
        [routeNegativeKey(for: job), .request(job.key)]
    }

    func negativeKey(for error: BittensorApiError, job: BittensorApiCacheJob) -> NegativeKey {
        guard case .routeNotPublished = error else {
            return .request(job.key)
        }

        return routeNegativeKey(for: job)
    }

    func negativeLifetime(for error: BittensorApiError) -> TimeInterval? {
        switch error {
        case .routeNotPublished:
            return Self.routeNotPublishedLifetime
        case .datasetUnavailable:
            return Self.datasetUnavailableLifetime
        default:
            return nil
        }
    }

    func isBackoffTrigger(_ error: BittensorApiError) -> Bool {
        switch error {
        case .rateLimited, .upstreamUnavailable, .upstreamInvalidResponse, .attestationUnavailable:
            return true
        case let .server(statusCode, _, _):
            return (500 ... 599).contains(statusCode)
        default:
            return false
        }
    }
}
