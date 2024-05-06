import Foundation

protocol ExtrinsicSignedExtensionFacadeProtocol {
    func createFactory(for chainId: ChainModel.Id) -> ExtrinsicSignedExtensionFactoryProtocol
}

final class ExtrinsicSignedExtensionFacade {}

extension ExtrinsicSignedExtensionFacade: ExtrinsicSignedExtensionFacadeProtocol {
    func createFactory(for chainId: ChainModel.Id) -> ExtrinsicSignedExtensionFactoryProtocol {
        switch chainId {
        case KnowChainId.avail, KnowChainId.availTuringTestnet:
            AvailSignedExtension.Factory()
        default:
            ExtrinsicSignedExtensionFactory()
        }
    }
}
