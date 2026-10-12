import Foundation

final class NovaAuthHTTPDelegate: NSObject, URLSessionDataDelegate {
    private let mutex = NSLock()
    private var calls: [String: NovaAuthHTTPCall] = [:]

    func insert(_ call: NovaAuthHTTPCall, for task: URLSessionTask, session: URLSession) {
        mutex.lock()
        calls[key(task: task, session: session)] = call
        mutex.unlock()
    }

    @discardableResult func remove(task: URLSessionTask, session: URLSession) -> NovaAuthHTTPCall? {
        mutex.lock()
        defer { mutex.unlock() }
        return calls.removeValue(forKey: key(task: task, session: session))
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let call = call(task: dataTask, session: session), call.receive(response) else {
            call(task: dataTask, session: session)?.finish(.failure(NovaAuthError.invalidResponse))
            completionHandler(.cancel)
            return
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let call = call(task: dataTask, session: session) else { dataTask.cancel(); return }
        if !call.receive(data) { call.finish(.failure(NovaAuthError.invalidResponse)) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        remove(task: task, session: session)?.complete(error: error)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest _: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
        call(task: task, session: session)?.finish(.failure(NovaAuthError.invalidResponse))
    }

    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            completionHandler(.performDefaultHandling, nil)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        willCacheResponse proposedResponse: CachedURLResponse,
        completionHandler: @escaping (CachedURLResponse?) -> Void
    ) {
        let allowed = call(task: dataTask, session: session)?.kind == .businessRead && Self
            .isPublicCacheResponse(proposedResponse)
        completionHandler(allowed ? proposedResponse : nil)
    }

    static func isPublicCacheResponse(_ cached: CachedURLResponse) -> Bool {
        guard let response = cached.response as? HTTPURLResponse,
              (200 ..< 300).contains(response.statusCode) else { return false }
        let directives = (response.value(forHTTPHeaderField: "Cache-Control") ?? "").lowercased()
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard directives.contains("public"), !directives.contains("no-store"),
              !directives.contains(where: { $0 == "private" || $0.hasPrefix("private=") }) else { return false }
        for field in response.allHeaderFields.keys {
            guard let name = field as? String else { return false }
            if isIdentityHeader(name.lowercased()) { return false }
        }
        let vary = (response.value(forHTTPHeaderField: "Vary") ?? "").lowercased().split(separator: ",")
        return !vary.contains { value in
            let name = value.trimmingCharacters(in: .whitespaces)
            return name == "*" || isIdentityHeader(name)
        }
    }
}

private extension NovaAuthHTTPDelegate {
    func key(
        task: URLSessionTask,
        session: URLSession
    ) -> String { "\(ObjectIdentifier(session))-\(task.taskIdentifier)" }

    func call(task: URLSessionTask, session: URLSession) -> NovaAuthHTTPCall? {
        mutex.lock()
        defer { mutex.unlock() }
        return calls[key(task: task, session: session)]
    }

    static func isIdentityHeader(_ name: String) -> Bool {
        ["authorization", "proxy-authorization", "cookie", "cookie2", "set-cookie", "set-cookie2", "www-authenticate",
         "proxy-authenticate", "authentication-info"].contains(name) || name.contains("attestation") ||
            name.contains("app-attest") || name.contains("client-id") || name.contains("user-id") ||
            name.contains("session") || name.contains("token") || name.contains("identity") || name
            .contains("install") ||
            name.contains("account") || name.contains("proof") || name.contains("credential")
    }
}
