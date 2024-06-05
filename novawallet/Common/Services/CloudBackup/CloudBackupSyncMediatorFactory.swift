import Foundation

enum CloudBackupSyncMediatorFacade {
    static let sharedMediator: CloudBackupSyncMediating = CloudBackupSyncMediatorFactory.createDefaultMediator()
}

enum CloudBackupSyncMediatorFactory {
    static func createDefaultMediator() -> CloudBackupSyncMediating {
        let syncService = CloudBackupSyncService.createService()

        return CloudBackupSyncMediator(
            syncService: syncService,
            eventCenter: EventCenter.shared,
            selectedWalletSettings: SelectedWalletSettings.shared,
            operationQueue: OperationManagerFacade.cloudBackupQueue,
            logger: Logger.shared
        )
    }
}
