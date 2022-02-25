import Foundation
import RobinHood

final class FileDownloadOperation: BaseOperation<URLResponse> {
    public lazy var networkSession = URLSession.shared

    private var networkTask: URLSessionDownloadTask?

    let remoteUrl: URL
    let localUrl: URL
    let fileManager: FileManager

    public init(remoteUrl: URL, localUrl: URL, fileManager: FileManager) {
        self.remoteUrl = remoteUrl
        self.localUrl = localUrl
        self.fileManager = fileManager

        super.init()
    }

    override public func main() {
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        let semaphore = DispatchSemaphore(value: 0)

        var receivedResponse: URLResponse?
        var receivedError: Error?

        if isCancelled {
            return
        }

        let currentLocalUrl = localUrl
        let directoryUrl = localUrl.deletingLastPathComponent()
        let currentFileManager = fileManager

        let dataTask = networkSession.downloadTask(with: remoteUrl) { tempUrl, response, networkError in
            do {
                if let tempUrl = tempUrl {
                    if !currentFileManager.fileExists(atPath: directoryUrl.path) {
                        try currentFileManager.createDirectory(
                            at: directoryUrl,
                            withIntermediateDirectories: true,
                            attributes: nil
                        )
                    }

                    if currentFileManager.fileExists(atPath: currentLocalUrl.path), tempUrl != currentLocalUrl {
                        try currentFileManager.removeItem(at: currentLocalUrl)
                    }

                    if tempUrl != currentLocalUrl {
                        try currentFileManager.copyItem(at: tempUrl, to: currentLocalUrl)
                    }
                }

                receivedResponse = response
                receivedError = networkError
            } catch {
                receivedError = error
            }

            semaphore.signal()
        }

        networkTask = dataTask
        dataTask.resume()

        _ = semaphore.wait(timeout: .distantFuture)

        if let error = receivedError, NetworkOperationHelper.isCancellation(error: error) {
            return
        }

        if let response = receivedResponse {
            result = .success(response)
        } else if let receivedError = receivedError {
            result = .failure(receivedError)
        } else {
            result = .failure(NetworkBaseError.unexpectedResponseObject)
        }
    }

    override public func cancel() {
        networkTask?.cancel()

        super.cancel()
    }
}
