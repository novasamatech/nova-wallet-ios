import Foundation

protocol CrowdloanDataValidatingFactoryProtocol: BaseDataValidatingFactoryProtocol {}

final class CrowdloanDataValidatingFactory: CrowdloanDataValidatingFactoryProtocol {
    weak var view: ControllerBackedProtocol?
    let presentable: CrowdloanErrorPresentable

    var basePresentable: BaseErrorPresentable { presentable }

    init(presentable: CrowdloanErrorPresentable) {
        self.presentable = presentable
    }
}
