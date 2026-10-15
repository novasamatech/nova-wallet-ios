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
}
