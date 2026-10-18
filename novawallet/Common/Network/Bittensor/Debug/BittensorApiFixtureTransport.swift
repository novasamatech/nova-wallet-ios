import Foundation
import Operation_iOS

#if DEBUG
    final class BittensorApiFixtureTransport {
        private let mutex = NSLock()
        private var requestCount = 0

        private func nextRequestId() -> String {
            mutex.lock()

            defer {
                mutex.unlock()
            }

            requestCount += 1

            return "fixture-\(requestCount)"
        }
    }

    extension BittensorApiFixtureTransport: BittensorApiTransportProtocol {
        func createResponseWrapper(
            for request: BittensorApiRequest
        ) -> CompoundOperationWrapper<BittensorApiRawResponse> {
            let requestId = nextRequestId()

            let operation = ClosureOperation<BittensorApiRawResponse> {
                let route = try BittensorApiFixtureRouter.route(for: request, requestId: requestId)
                let document = BittensorApiFixtureRouter.document(for: route)
                let body = try JSONSerialization.data(withJSONObject: document, options: [.sortedKeys])
                let cacheControl = BittensorApiFixtureRouter.cacheControl(for: route, document: document)

                return BittensorApiRawResponse(
                    statusCode: 200,
                    requestId: requestId,
                    body: body,
                    cacheDirectives: HTTPCacheDirectives(cacheControl: cacheControl, age: nil)
                )
            }

            return CompoundOperationWrapper(targetOperation: operation)
        }
    }
#endif
