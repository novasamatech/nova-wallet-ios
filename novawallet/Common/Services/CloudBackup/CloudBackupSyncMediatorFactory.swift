import Foundation

enum CloudBackupSyncMediatorFacade {
    static let sharedMediator: CloudBackupSyncMediating = CloudBackupSyncMediatorFactory.createDefaultMediator()
}

enum CloudBackupSyncMediatorFactory {
    static func createDefaultMediator() -> CloudBackupSyncMediating {
        let syncFacade = CloudBackupSyncFacade.createFacade()
        let backupApplyFactory = CloudBackupUpdateApplicationFactory.createDefault()

        return CloudBackupSyncMediator(
            syncFacade: syncFacade,
            cloudBackupApplyFactory: backupApplyFactory,
            eventCenter: EventCenter.shared,
            selectedWalletSettings: SelectedWalletSettings.shared,
            operationQueue: OperationManagerFacade.cloudBackupQueue,
            logger: Logger.shared
        )
    }
}
