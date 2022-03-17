import Foundation
import RobinHood

protocol FileDownloadOperationFactoryProtocol {
    func createFileDownloadOperation(from remoteUrl: URL, to localUrl: URL) -> BaseOperation<URLResponse>
}

final class FileDownloadOperationFactory: FileDownloadOperationFactoryProtocol {
    let fileManager: FileManager

    init(fileManager: FileManager = FileManager.default) {
        self.fileManager = fileManager
    }

    func createFileDownloadOperation(from remoteUrl: URL, to localUrl: URL) -> BaseOperation<URLResponse> {
        FileDownloadOperation(remoteUrl: remoteUrl, localUrl: localUrl, fileManager: fileManager)
    }
}
