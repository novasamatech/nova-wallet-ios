import UIKit

final class ImportCloudPasswordInteractor {
    weak var presenter: ImportCloudPasswordInteractorOutputProtocol?
}

extension ImportCloudPasswordInteractor: ImportCloudPasswordInteractorInputProtocol {}
