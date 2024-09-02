import Foundation

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
    func getCardsModel() -> [VoteCardView.ViewModel] {
        (0 ..< 10).map { index in
            let gradientModel = cardGradientFactory.createCardGratient(for: index)

            return VoteCardView.ViewModel(
                // swiftlint:disable:next line_length
                summary: "The Mythos Foundation and Mythical Games propose a token swap of 1,000,000 DOT for 20,000,000 MYTH tokens to celebrate Mythical Games joining Polkadot, enhancing blockchain gaming and benefiting DOT holders.",
                requestedAmount: .init(
                    assetAmount: "1M DOT",
                    fiatAmount: "$7,42M"
                ),
                gradientModel: gradientModel
            )
        }
    }
}
