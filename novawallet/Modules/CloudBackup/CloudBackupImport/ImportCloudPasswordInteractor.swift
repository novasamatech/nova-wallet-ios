import UIKit
import RobinHood
import SoraKeystore

final class ImportCloudPasswordInteractor {
    weak var presenter: ImportCloudPasswordInteractorOutputProtocol?

    let cloudBackupFacade: CloudBackupServiceFacadeProtocol
    let walletRepository: AnyDataProviderRepository<MetaAccountModel>
    let keystore: KeystoreProtocol
    
    init(
        cloudBackupFacade: CloudBackupServiceFacadeProtocol,
        walletRepository: AnyDataProviderRepository<MetaAccountModel>,
        keystore: KeystoreProtocol
    ) {
        self.cloudBackupFacade = cloudBackupFacade
        self.walletRepository = walletRepository
        self.keystore = keystore
    }
}

extension ImportCloudPasswordInteractor: ImportCloudPasswordInteractorInputProtocol {
    func importBackup(for password: String) {
        cloudBackupFacade.importBackup(
            to: walletRepository,
            keystore: keystore,
            password: password,
            runCompletionIn: .main
        ) { result in
            
        }
    }

    func deleteBackup() {
        cloudBackupFacade.deleteBackup(
            runCompletionIn: .main
        ) { result in
            
        }
    }
}
