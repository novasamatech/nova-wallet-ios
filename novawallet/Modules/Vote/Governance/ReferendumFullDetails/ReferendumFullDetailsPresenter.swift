import Foundation

final class ReferendumFullDetailsPresenter {
    weak var view: ReferendumFullDetailsViewProtocol?
    let wireframe: ReferendumFullDetailsWireframeProtocol

    let chain: ChainModel
    let referendum: ReferendumLocal
    let actionDetails: ReferendumActionLocal
    let identities: [AccountAddress: AccountIdentity]

    init(
        wireframe: ReferendumFullDetailsWireframeProtocol,
        chain: ChainModel,
        referendum: ReferendumLocal,
        actionDetails: ReferendumActionLocal,
        identities: [AccountAddress: AccountIdentity]
    ) {
        self.wireframe = wireframe
        self.chain = chain
        self.referendum = referendum
        self.actionDetails = actionDetails
        self.identities = identities
    }
}

extension ReferendumFullDetailsPresenter: ReferendumFullDetailsPresenterProtocol {
    func setup() {}
}
