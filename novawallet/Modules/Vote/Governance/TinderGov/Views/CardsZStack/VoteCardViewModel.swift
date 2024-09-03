import Foundation

final class VoteCardViewModel {
    struct RequestedAmount {
        let assetAmount: String
        let fiatAmount: String
    }

    weak var view: StackCardViewUpdatable?
    let gradient: GradientModel
    let locale: Locale

    private let onVote: (VoteResult, ReferendumIdLocal) -> Void
    private let onBecomeTop: (ReferendumIdLocal) -> Void
    private let referendum: ReferendumLocal

    init(
        referendum: ReferendumLocal,
        gradient: GradientModel,
        locale: Locale,
        onVote: @escaping (VoteResult, ReferendumIdLocal) -> Void,
        onBecomeTop: @escaping (ReferendumIdLocal) -> Void
    ) {
        self.referendum = referendum
        self.gradient = gradient
        self.locale = locale
        self.onVote = onVote
        self.onBecomeTop = onBecomeTop
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

    func onPop(direction: CardsZStack.DismissalDirection) {
        let voteResult = VoteResult(from: direction)

        onVote(voteResult, referendum.index)
    }

    func onBecomeTopView() {
        onBecomeTop(referendum.index)
    }

    func onSetup() {
        view?.setBackgroundGradient(model: gradient)
    }
}
