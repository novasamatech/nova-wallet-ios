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
