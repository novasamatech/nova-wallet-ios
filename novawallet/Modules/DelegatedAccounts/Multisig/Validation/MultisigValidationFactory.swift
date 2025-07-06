import Foundation
import BigInt
import Foundation_iOS

protocol MultisigDataValidatorFactoryProtocol: BaseDataValidatingFactoryProtocol {}

final class MultisigDataValidatorFactory: MultisigDataValidatorFactoryProtocol {
    weak var view: ControllerBackedProtocol?

    var basePresentable: BaseErrorPresentable { presentable }
    let presentable: MultisigErrorPresentable

    init(presentable: MultisigErrorPresentable) {
        self.presentable = presentable
    }
}
