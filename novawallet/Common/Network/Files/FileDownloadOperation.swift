import Foundation
import Operation_iOS

final class FileDownloadOperation: BaseOperation<URLResponse> {
    public lazy var networkSession = URLSession.shared

    private let mutex = NSLock()
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

    private func moveDownloadedFile(from tempUrl: URL?) throws {
        guard let tempUrl else {
            return
        }

        let directoryUrl = localUrl.deletingLastPathComponent()

        var isDirectory: ObjCBool = false
        let parentExists = fileManager.fileExists(
            atPath: directoryUrl.path,
            isDirectory: &isDirectory
        )

        if !parentExists || !isDirectory.boolValue {
            if parentExists {
                try fileManager.removeItem(at: directoryUrl)
            }

            try fileManager.createDirectory(
                at: directoryUrl,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        if fileManager.fileExists(atPath: localUrl.path), tempUrl != localUrl {
            try fileManager.removeItem(at: localUrl)
        }

        if tempUrl != localUrl {
            try fileManager.copyItem(at: tempUrl, to: localUrl)
        }
    }

    override func performAsync(_ callback: @escaping (Result<URLResponse, Error>) -> Void) throws {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let dataTask = networkSession.downloadTask(with: remoteUrl) { tempUrl, response, error in
            do {
                try self.moveDownloadedFile(from: tempUrl)

                if let response {
                    callback(.success(response))
                } else if let error {
                    guard !NetworkOperationHelper.isCancellation(error: error) else {
                        return
                    }

                    callback(.failure(error))
                } else {
                    callback(.failure(NetworkBaseError.unexpectedResponseObject))
                }

            } catch {
                callback(.failure(error))
            }
        }

        networkTask = dataTask
        dataTask.resume()
    }

    override public func cancel() {
        mutex.lock()

        networkTask?.cancel()

        mutex.unlock()

        super.cancel()
    }
}
