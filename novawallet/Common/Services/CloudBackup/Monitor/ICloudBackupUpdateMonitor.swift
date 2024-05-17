import Foundation

final class ICloudBackupUpdateMonitor {
    let notificationCenter: NotificationCenter
    let filename: String
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var monitor: NSMetadataQuery?

    private var closure: CloudBackupUpdateMonitoringClosure?

    init(
        filename: String,
        operationQueue: OperationQueue, // must be maxConcurrentOperation = 1
        notificationCenter: NotificationCenter,
        logger: LoggerProtocol
    ) {
        self.notificationCenter = notificationCenter
        self.operationQueue = operationQueue
        self.filename = filename
        self.logger = logger
    }

    @objc private func queryDidUpdate(_ notification: Notification) {
        logger.debug("Query did update \(filename): \(notification)")

        handle(notification: notification)
    }

    @objc private func queryDidCompleteGathering(_ notification: Notification) {
        logger.debug("Query did complete gathering \(filename): \(notification)")

        handle(notification: notification)
    }

    private func handle(notification _: Notification) {
        guard
            let monitor,
            monitor.resultCount > 0,
            let item = monitor.result(at: 0) as? NSMetadataItem else {
            closure?(.success(.noFile))
            logger.warning("No update metadata found for: \(filename)")
            return
        }

        let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String

        logger.debug("Cloud backup status: \(String(describing: status))")

        switch status {
        case nil,
             NSMetadataUbiquitousItemDownloadingStatusNotDownloaded,
             NSMetadataUbiquitousItemDownloadingStatusDownloaded:
            closure?(.success(.notDownloaded))
        case NSMetadataUbiquitousItemDownloadingStatusCurrent:
            closure?(.success(.downloaded))
        default:
            closure?(.success(.unknown))
        }
    }
}

extension ICloudBackupUpdateMonitor: CloudBackupUpdateMonitoring {
    func start(with closure: @escaping CloudBackupUpdateMonitoringClosure) {
        guard monitor == nil else {
            return
        }

        self.closure = closure

        let metadataQuery = NSMetadataQuery()
        metadataQuery.predicate = NSPredicate(format: "%K == %@", NSMetadataItemFSNameKey, filename)
        metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]

        metadataQuery.operationQueue = operationQueue

        notificationCenter.addObserver(
            self,
            selector: #selector(queryDidUpdate(_:)),
            name: .NSMetadataQueryDidUpdate,
            object: metadataQuery
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(queryDidCompleteGathering(_:)),
            name: .NSMetadataQueryDidFinishGathering,
            object: metadataQuery
        )

        monitor = metadataQuery

        operationQueue.addOperation {
            metadataQuery.start()
        }
    }

    func stop() {
        monitor?.stop()
        monitor = nil

        closure = nil
    }
}
