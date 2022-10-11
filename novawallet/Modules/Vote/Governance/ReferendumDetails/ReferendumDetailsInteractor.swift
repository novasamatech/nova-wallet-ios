import UIKit
import SubstrateSdk

final class ReferendumDetailsInteractor {
    weak var presenter: ReferendumDetailsInteractorOutputProtocol?

    let referendum: ReferendumLocal
    let chain: ChainModel
    let actionDetailsOperationFactory: ReferendumActionOperationFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let identityOperationFactory: IdentityOperationFactoryProtocol

    init(
        referendum: ReferendumLocal,
        chain: ChainModel,
        actionDetailsOperationFactory: ReferendumActionOperationFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        identityOperationFactory: IdentityOperationFactoryProtocol
    ) {
        self.referendum = referendum
        self.chain = chain
        self.actionDetailsOperationFactory = actionDetailsOperationFactory
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.identityOperationFactory = identityOperationFactory
    }
}

extension ReferendumDetailsInteractor: ReferendumDetailsInteractorInputProtocol {}
