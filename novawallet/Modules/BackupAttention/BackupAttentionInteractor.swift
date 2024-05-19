import UIKit

final class BackupAttentionInteractor {
    weak var presenter: BackupAttentionInteractorOutputProtocol?
}

extension BackupAttentionInteractor: BackupAttentionInteractorInputProtocol {}
