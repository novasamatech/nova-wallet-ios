import Foundation

final class CloudBackupEnterPasswordSetInteractor: BaseBackupEnterPasswordInteractor {
    let syncMetadataManager: CloudBackupSyncMetadataManaging

    init(
        cloudBackupSyncFacade: CloudBackupSyncFacadeProtocol,
        cloudBackupServiceFacade: CloudBackupServiceFacadeProtocol,
        syncMetadataManager: CloudBackupSyncMetadataManaging
    ) {
        self.syncMetadataManager = syncMetadataManager

        super.init(
            cloudBackupSyncFacade: cloudBackupSyncFacade,
            cloudBackupServiceFacade: cloudBackupServiceFacade
        )
    }

    override func proceedAfterPasswordValid(_ password: String) {
        do {
            try syncMetadataManager.savePassword(password)
            cloudBackupSyncFacade.syncUp()
            presenter?.didImportBackup(with: password)
        } catch {
            presenter?.didReceive(error: .importInternal(error))
        }
    }
}
