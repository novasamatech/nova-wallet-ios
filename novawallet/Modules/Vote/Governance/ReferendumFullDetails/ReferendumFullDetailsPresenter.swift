import Foundation
import SubstrateSdk

final class ReferendumFullDetailsPresenter {
    weak var view: ReferendumFullDetailsViewProtocol?
    let wireframe: ReferendumFullDetailsWireframeProtocol
    let interactor: ReferendumFullDetailsInteractorInputProtocol
    let chainIconGenerator: IconGenerating

    let chain: ChainModel
    let referendum: ReferendumLocal
    let actionDetails: ReferendumActionLocal
    let identities: [AccountAddress: AccountIdentity]
    private var price: PriceData?
    private var json: String?

    init(
        interactor: ReferendumFullDetailsInteractorInputProtocol,
        wireframe: ReferendumFullDetailsWireframeProtocol,
        chainIconGenerator: IconGenerating,
        chain: ChainModel,
        referendum: ReferendumLocal,
        actionDetails: ReferendumActionLocal,
        identities: [AccountAddress: AccountIdentity]
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chain = chain
        self.referendum = referendum
        self.actionDetails = actionDetails
        self.identities = identities
        self.chainIconGenerator = chainIconGenerator
    }

    private func updateView() {
        guard let view = view else {
            return
        }
        getProposer().map {
            view.didReceive(proposerModel: .init(
                title: "Proposer",
                model: .init(
                    details: $0.name,
                    imageViewModel: $0.icon
                )
            ))
        }
        let approvalCurveModel = referendum.state.approvalCurve.map {
            TitleWithSubtitleViewModel(
                title: "Approve Curve",
                subtitle: $0.displayName
            )
        }
        let supportCurveModel = referendum.state.supportCurve.map {
            TitleWithSubtitleViewModel(
                title: "Support Curve",
                subtitle: $0.displayName
            )
        }
        let callHashModel = referendum.state.callHash.map {
            TitleWithSubtitleViewModel(
                title: "Call Hash",
                subtitle: $0
            )
        }

        view.didReceive(
            approveCurve: approvalCurveModel,
            supportCurve: supportCurveModel,
            callHash: callHashModel
        )
    }

    private func getProposer() -> (name: String, icon: ImageViewModelProtocol?)? {
        guard let proposer = referendum.proposer,
              let proposerAddress = try? proposer.toAddress(using: chain.chainFormat) else {
            return nil
        }

        let chainAccountIcon = icon(
            generator: chainIconGenerator,
            from: proposer
        )

        let name = identities[proposerAddress]?.displayName ?? proposerAddress

        return (name: name, icon: chainAccountIcon)
    }

    private func icon(
        generator: IconGenerating,
        from imageData: Data?
    ) -> DrawableIconViewModel? {
        guard let data = imageData,
              let icon = try? generator.generateFromAccountId(data) else {
            return nil
        }

        return DrawableIconViewModel(icon: icon)
    }
    
    private func updatePriceDependentViews() {
        view?.didReceive(deposit: .init(topValue: "3.33333 KSM",
                                        bottomValue: "$200"),
                         title: "Deposit")
    }
}

extension ReferendumFullDetailsPresenter: ReferendumFullDetailsPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension ReferendumFullDetailsPresenter: ReferendumFullDetailsInteractorOutputProtocol {
    func didReceive(price: PriceData?) {
        self.price = price
        updatePriceDependentViews()
    }

    func didReceive(json: String?) {
        view?.didReceive(json: json, jsonTitle: "Parameters JSON")
    }

    func didReceive(error: ReferendumFullDetailsError) {
        print("Received error: \(error.localizedDescription)")
    }
}
