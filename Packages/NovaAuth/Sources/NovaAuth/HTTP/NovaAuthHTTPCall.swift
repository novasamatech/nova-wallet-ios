import Foundation

final class NovaAuthHTTPCall {
    let request: URLRequest
    let kind: NovaAuthHTTPKind
    private let timeout: TimeInterval
    private let mutex = NSLock()
    private var task: URLSessionDataTask?
    private var completion: ((Result<NovaAuthResponse, Error>) -> Void)?
    private var response: HTTPURLResponse?
    private var data = Data()
    private var finished = false
    private var timer: DispatchWorkItem?
    private var limit: Int { kind == .bootstrap ? 16384 : 32 * 1024 * 1024 }

    init(request: URLRequest, kind: NovaAuthHTTPKind, timeout: TimeInterval) {
        self.request = request
        self.kind = kind
        self.timeout = timeout
    }

    func prepare(task: URLSessionDataTask, completion: @escaping (Result<NovaAuthResponse, Error>) -> Void) {
        mutex.lock()
        guard !finished else { mutex.unlock(); task.cancel(); completion(.failure(NovaAuthError.cancelled)); return }
        self.task = task
        self.completion = completion
        mutex.unlock()
    }

    func resume() throws {
        mutex.lock()
        defer { mutex.unlock() }
        guard !finished, let task else { throw NovaAuthError.cancelled }
        let timer = DispatchWorkItem { [weak self] in self?.finish(.failure(NovaAuthError.transport(.timedOut))) }
        self.timer = timer
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: timer)
        task.resume()
    }

    func receive(_ response: URLResponse) -> Bool {
        mutex.lock()
        defer { mutex.unlock() }
        guard !finished, let response = response as? HTTPURLResponse, response.url == request.url,
              response.expectedContentLength <= Int64(limit) else { return false }
        self.response = response
        return true
    }

    func receive(_ chunk: Data) -> Bool {
        mutex.lock()
        defer { mutex.unlock() }
        guard !finished, chunk.count <= limit - data.count else { return false }
        data.append(chunk)
        return true
    }

    func complete(error: Error?) {
        mutex.lock()
        let response = response
        let bytes = data
        mutex.unlock()
        if let error = error as? URLError {
            finish(.failure(NovaAuthError.transport(error.code)))
        } else if error != nil {
            finish(.failure(NovaAuthError.transport(.unknown)))
        } else if let response {
            finish(.success(NovaAuthResponse(response: response, body: bytes)))
        } else {
            finish(.failure(NovaAuthError.invalidResponse))
        }
    }

    func finish(_ result: Result<NovaAuthResponse, Error>) {
        mutex.lock()
        guard !finished else { mutex.unlock(); return }
        finished = true
        let completion = completion
        let task = task
        self.task = nil
        self.completion = nil
        data.removeAll()
        timer?.cancel()
        timer = nil
        mutex.unlock()
        if case .failure = result { task?.cancel() }
        completion?(result)
    }
}
