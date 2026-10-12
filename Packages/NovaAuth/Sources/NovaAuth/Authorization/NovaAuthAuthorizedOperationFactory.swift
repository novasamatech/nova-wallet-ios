import Foundation
import Operation_iOS

protocol NovaAuthCredentialAuthority: AnyObject {
    var http: NovaAuthHTTPProtocol { get }
    var requestQueue: OperationQueue { get }
    func demand(
        context: NovaAuthContext,
        intent: NovaAuthRequestIntent,
        cancellation: NovaAuthCancellation,
        completion: @escaping (Result<NovaAuthTokenRecord, Error>) -> Void
    )
    func checkSend(request: NovaAuthRequest, record: NovaAuthTokenRecord) throws
    func receive(_ result: Result<NovaAuthResponse, Error>, context: NovaAuthContext) throws
    func reject(record: NovaAuthTokenRecord, repeated: Bool, requestID: String?) throws
}

final class NovaAuthAuthorizedOperationFactory {
    private let owner: NovaAuthCredentialAuthority

    init(owner: NovaAuthCredentialAuthority) { self.owner = owner }

    func createWrapper(
        request: NovaAuthRequest,
        beforeSend: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<NovaAuthResponse> {
        let operation = NovaAuthWaiterOperation<NovaAuthResponse> { [owner] cancellation, completion in
            let exchange = NovaAuthBusinessExchange(
                owner: owner,
                request: request,
                cancellation: cancellation,
                beforeSend: beforeSend,
                completion: completion
            )
            exchange.admit(repeated: false)
        }
        return CompoundOperationWrapper(targetOperation: operation)
    }
}

private final class NovaAuthBusinessExchange {
    let owner: NovaAuthCredentialAuthority
    let request: NovaAuthRequest
    let cancellation: NovaAuthCancellation
    let beforeSend: () throws -> Void
    let completion: (Result<NovaAuthResponse, Error>) -> Void

    init(
        owner: NovaAuthCredentialAuthority,
        request: NovaAuthRequest,
        cancellation: NovaAuthCancellation,
        beforeSend: @escaping () throws -> Void,
        completion: @escaping (Result<NovaAuthResponse, Error>) -> Void
    ) {
        self.owner = owner
        self.request = request
        self.cancellation = cancellation
        self.beforeSend = beforeSend
        self.completion = completion
    }

    func admit(repeated: Bool) {
        owner.demand(context: request.context, intent: request.intent, cancellation: cancellation) { [self] result in
            do {
                try cancellation.check()
                try send(record: result.get(), repeated: repeated)
            } catch { finish(.failure(NovaAuth.safeError(error))) }
        }
    }

    func send(record: NovaAuthTokenRecord, repeated: Bool) throws {
        var urlRequest = URLRequest(url: try request.makeURL())
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        urlRequest.setValue("Bearer " + record.accessToken, forHTTPHeaderField: "Authorization")
        if let type = request.contentType { urlRequest.setValue(type, forHTTPHeaderField: "Content-Type") }
        if let body = request.body { urlRequest.setValue(String(body.count), forHTTPHeaderField: "Content-Length") }
        let kind: NovaAuthHTTPKind = request.method == .post ? .businessPost : .businessRead
        let wrapper = owner.http.createResponseWrapper(for: urlRequest, kind: kind) { [self] in
            try cancellation.check()
            try owner.checkSend(request: request, record: record)
            try beforeSend()
            try cancellation.check()
            try owner.checkSend(request: request, record: record)
        }
        cancellation.install { wrapper.cancel() }
        let target = wrapper.targetOperation
        target.completionBlock = { [self, weak target] in
            let result = target?.result ?? .failure(NovaAuthError.cancelled)
            target?.completionBlock = nil
            do {
                try cancellation.check()
                try owner.receive(result, context: request.context)
                let response = try result.get()
                if NovaAuthBearerDenial.isInvalidToken(response, request: request) {
                    let requestID = NovaAuthWire.requestID(response.response)
                    try owner.reject(record: record, repeated: repeated, requestID: requestID)
                    if repeated { throw NovaAuthError.authorizationDenied(requestID: requestID) }
                    admit(repeated: true)
                } else { finish(.success(response)) }
            } catch { finish(.failure(NovaAuth.safeError(error))) }
        }
        owner.requestQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    func finish(_ result: Result<NovaAuthResponse, Error>) {
        if !cancellation.isCancelled { completion(result) }
    }
}
