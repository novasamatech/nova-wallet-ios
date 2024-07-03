import UIKit

final class KnownNetworksListInteractor {
    weak var presenter: KnownNetworksListInteractorOutputProtocol?
    
    let dataFetchFactory: DataOperationFactoryProtocol
    let chainConverter: ChainModelConversionProtocol
    
    init(
        dataFetchFactory: any DataOperationFactoryProtocol,
        chainConverter: any ChainModelConversionProtocol
    ) {
        self.dataFetchFactory = dataFetchFactory
        self.chainConverter = chainConverter
    }
}

extension KnownNetworksListInteractor: KnownNetworksListInteractorInputProtocol {
    func provideChains() {
        
    }
}
