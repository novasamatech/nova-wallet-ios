import Foundation
import SoraFoundation

final class ICloudBackupUploadMonitor {
    let notificationCenter: NotificationCenter
    let filename: String
    let operationQueue: OperationQueue
    let timeoutInterval: TimeInterval
    let logger: LoggerProtocol

    private var monitor: NSMetadataQuery?
    private var timeoutScheduler: Scheduler?

    private var closure: CloudBackupUploadMonitoringClosure?

    init(
        filename: String,
        operationQueue: OperationQueue, // must be maxConcurrentOperation = 1
        notificationCenter: NotificationCenter,
        timeoutInteval: TimeInterval,
        logger: LoggerProtocol
    ) {
        self.notificationCenter = notificationCenter
        self.operationQueue = operationQueue
        self.filename = filename
        timeoutInterval = timeoutInteval
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
            logger.warning("No uploading metadata found for: \(filename)")
            return
        }

        let isUploaded = item.value(forAttribute: NSMetadataUbiquitousItemIsUploadedKey) as? Bool ?? false
        let isUploading = item.value(forAttribute: NSMetadataUbiquitousItemIsUploadingKey) as? Bool ?? false
        let uploadError = item.value(forAttribute: NSMetadataUbiquitousItemUploadingErrorKey) as? NSError
        let progress = item.value(forAttribute: NSMetadataUbiquitousItemPercentUploadedKey) as? Double

        if isUploaded {
            stopAndNotify(with: .success(()))
        } else if !isUploading, let error = uploadError {
            let monitorError = CloudBackupUploadError(icloudError: error)
            stopAndNotify(with: .failure(monitorError))
        } else if isUploading {
            logger.debug("Uploading progress \(filename): \(progress ?? 0)")
        } else {
            logger.warning("Not uploading: \(filename)")
        }
    }

    private func stopAndNotify(with result: Result<Void, CloudBackupUploadError>) {
        monitor?.stop()
        monitor = nil

        timeoutScheduler?.cancel()
        timeoutScheduler = nil

        closure?(result)
    }
}

extension ICloudBackupUploadMonitor: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        stopAndNotify(with: .failure(.timeout))
    }
}

extension ICloudBackupUploadMonitor: CloudBackupUploadMonitoring {
    func start(with closure: @escaping CloudBackupUploadMonitoringClosure) {
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

        timeoutScheduler = Scheduler(with: self)
        timeoutScheduler?.notifyAfter(timeoutInterval)
    }

    func stop() {
        monitor?.stop()
        monitor = nil

        closure = nil
    }
}

extension CloudBackupUploadError {
    init(icloudError: NSError) {
        if
            icloudError.domain == NSCocoaErrorDomain,
            icloudError.code == NSUbiquitousFileNotUploadedDueToQuotaError ||
            icloudError.code == NSFileWriteOutOfSpaceError
        {
            self = .notEnoughSpace
        } else {
            self = .internalError(icloudError)
        }
    }
}
