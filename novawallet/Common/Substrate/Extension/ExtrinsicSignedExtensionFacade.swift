import Foundation

protocol ExtrinsicSignedExtensionFacadeProtocol {
    func createFactory(for chainId: ChainModel.Id) -> ExtrinsicSignedExtensionFactoryProtocol
}

final class ExtrinsicSignedExtensionFacade {}

extension ExtrinsicSignedExtensionFacade: ExtrinsicSignedExtensionFacadeProtocol {
    func createFactory(for _: ChainModel.Id) -> ExtrinsicSignedExtensionFactoryProtocol {
        ExtrinsicSignedExtensionFactory()
    }
}
