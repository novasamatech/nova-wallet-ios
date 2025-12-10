import Foundation
import Operation_iOS

final class ICloudBackupSyncMonitor {
    let notificationCenter: NotificationCenter
    let filename: String
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var monitor: NSMetadataQuery?

    private var closure: CloudBackupUpdateMonitoringClosure?
    private var notificationQueue: DispatchQueue?

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

    private func getDownloadingStatus(from item: NSMetadataItem) -> CloudBackupSyncMonitorStatus? {
        let downloadError = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingErrorKey) as? NSError

        if let downloadError {
            logger.error("Downloading \(filename) error: \(downloadError)")
            return .downloading(.failure(downloadError))
        }

        let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String

        logger.debug("Cloud backup status: \(String(describing: status))")

        switch status {
        case NSMetadataUbiquitousItemDownloadingStatusNotDownloaded,
             NSMetadataUbiquitousItemDownloadingStatusDownloaded:

            let downloadProgress = item.value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? Double

            if let downloadProgress {
                logger.debug("Download progress \(filename) \(downloadProgress)")
                return .downloading(.success(downloadProgress))
            } else {
                let downloadRequested = item.value(forAttribute: NSMetadataUbiquitousItemDownloadRequestedKey) as? Bool

                logger.debug("Download requested \(filename) \(String(describing: downloadProgress))")
                return .notDownloaded(requested: downloadRequested ?? false)
            }
        case NSMetadataUbiquitousItemDownloadingStatusCurrent:
            return nil
        default:
            return nil
        }
    }

    private func getUploadingStatus(from item: NSMetadataItem) -> CloudBackupSyncMonitorStatus? {
        let isUploaded = item.value(forAttribute: NSMetadataUbiquitousItemIsUploadedKey) as? Bool ?? false
        let isUploading = item.value(forAttribute: NSMetadataUbiquitousItemIsUploadingKey) as? Bool ?? false
        let uploadError = item.value(forAttribute: NSMetadataUbiquitousItemUploadingErrorKey) as? NSError
        let progress = item.value(forAttribute: NSMetadataUbiquitousItemPercentUploadedKey) as? Double

        if isUploaded {
            logger.debug("Uploaded \(filename)")
            return nil
        } else if !isUploading, let error = uploadError {
            logger.error("Uploading error: \(error)")
            return .uploading(.failure(error))
        } else if isUploading {
            logger.debug("Uploading progress \(filename): \(progress ?? 0)")
            return .uploading(.success(progress ?? 0))
        } else {
            logger.warning("Uploading unknown \(filename)")
            return nil
        }
    }

    private func handle(notification _: Notification) {
        guard
            let monitor,
            monitor.resultCount > 0,
            let item = monitor.result(at: 0) as? NSMetadataItem else {
            logger.warning("No update metadata found for: \(filename)")

            dispatchInQueueWhenPossible(notificationQueue) { [weak self] in
                self?.closure?(.noFile)
            }

            return
        }

        if let downloadingStatus = getDownloadingStatus(from: item) {
            dispatchInQueueWhenPossible(notificationQueue) { [weak self] in
                self?.closure?(downloadingStatus)
            }
        } else if let uploadingStatus = getUploadingStatus(from: item) {
            dispatchInQueueWhenPossible(notificationQueue) { [weak self] in
                self?.closure?(uploadingStatus)
            }
        } else {
            dispatchInQueueWhenPossible(notificationQueue) { [weak self] in
                self?.closure?(.synced)
            }
        }
    }
}

extension ICloudBackupSyncMonitor: CloudBackupSyncMonitoring {
    func start(notifyingIn queue: DispatchQueue, with closure: @escaping CloudBackupUpdateMonitoringClosure) {
        guard monitor == nil else {
            return
        }

        self.closure = closure
        notificationQueue = queue

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
        notificationQueue = nil
    }
}
