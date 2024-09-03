import Foundation

protocol StackCardViewTextProtocol: AnyObject {
    func setSummary(loadingState: LoadableViewModelState<String>)
    func setRequestedAmount(loadingState: LoadableViewModelState<VoteCardViewModel.RequestedAmount?>)
}

protocol StackCardBackgroundProtocol: AnyObject {
    func setBackgroundGradient(model: GradientModel)
}

typealias StackCardViewUpdatable = StackCardViewTextProtocol & StackCardBackgroundProtocol

final class VoteCardViewModel {
    struct RequestedAmount {
        let assetAmount: String
        let fiatAmount: String
    }

    weak var view: StackCardViewUpdatable?
    let gradient: GradientModel

    private let referendum: ReferendumLocal

    init(
        referendum: ReferendumLocal,
        gradient: GradientModel
    ) {
        self.referendum = referendum
        self.gradient = gradient
    }

    func onAddToStack() {
        // TODO: implement data calls

        view?.setSummary(
            // swiftlint:disable:next line_length
            loadingState: .loaded(value: "The Mythos Foundation and Mythical Games propose a token swap of 1,000,000 DOT for 20,000,000 MYTH tokens to celebrate Mythical Games joining Polkadot, enhancing blockchain gaming and benefiting DOT holders.")
        )
        view?.setRequestedAmount(
            loadingState: .loaded(value: .init(
                assetAmount: "1M DOT",
                fiatAmount: "$7,42M"
            ))
        )
    }

    func onSetup() {
        view?.setBackgroundGradient(model: gradient)
    }
}

final class TinderGovViewModel {
    weak var view: TinderGovViewProtocol?
    let wireframe: TinderGovWireframeProtocol

    private let referendums: [ReferendumLocal] = []
    private let cardGradientFactory = TinderGovGradientFactory()

    init(wireframe: TinderGovWireframeProtocol) {
        self.wireframe = wireframe
    }
}

extension TinderGovViewModel: TinderGovViewModelProtocol {
    func bind() {}

    func actionBack() {
        wireframe.back(from: view)
    }

    // TODO: Change to binding model
    func getCardsModel() -> [VoteCardViewModel] {
        (0 ..< 10).map { index in
            let gradientModel = cardGradientFactory.createCardGratient(for: index)

            return VoteCardViewModel(
                referendum: .init(index: 0, state: .executed, proposer: .empty),
                gradient: gradientModel
            )
        }
    }
}
