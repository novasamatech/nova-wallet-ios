import Foundation
import SubstrateSdk

final class ReferendumFullDetailsPresenter {
    weak var view: ReferendumFullDetailsViewProtocol?
    let wireframe: ReferendumFullDetailsWireframeProtocol
    let chainIconGenerator: IconGenerating

    let chain: ChainModel
    let referendum: ReferendumLocal
    let actionDetails: ReferendumActionLocal
    let identities: [AccountAddress: AccountIdentity]

    init(
        wireframe: ReferendumFullDetailsWireframeProtocol,
        chainIconGenerator: IconGenerating,
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
}

extension ReferendumFullDetailsPresenter: ReferendumFullDetailsPresenterProtocol {
    func setup() {}
}

extension ReferendumStateLocal {
    var approvalCurve: Referenda.Curve? {
        switch voting {
        case let .supportAndVotes(model):
            return model.approvalFunction?.curve
        case .none:
            return nil
        }
    }

    var supportCurve: Referenda.Curve? {
        switch voting {
        case let .supportAndVotes(model):
            return model.supportFunction?.curve
        case .none:
            return nil
        }
    }

    var callHash: String? {
        switch proposal {
        case let .lookup(lookup):
            return String(data: lookup.hash, encoding: .utf8)
        case let .legacy(hash):
            return String(data: hash, encoding: .utf8)
        case .inline, .unknown, .none:
            return nil
        }
    }

    var voting: Voting? {
        switch self {
        case let .preparing(model):
            return model.voting
        case let .deciding(model):
            return model.voting
        case .approved,
             .rejected,
             .cancelled,
             .timedOut,
             .killed,
             .executed:
            return nil
        }
    }
}

extension Referenda.Curve {
    // TODO: localize?
    var displayName: String {
        switch self {
        case .linearDecreasing:
            return "Linear Decreasing"
        case .reciprocal:
            return "Reciprocal"
        case .steppedDecreasing:
            return "Stepped Decreasing"
        case .unknown:
            return "Unknown"
        }
    }
}
