import UIKit

final class AdvancedExportInteractor {
    weak var presenter: AdvancedExportInteractorOutputProtocol?
}

extension AdvancedExportInteractor: AdvancedExportInteractorInputProtocol {}