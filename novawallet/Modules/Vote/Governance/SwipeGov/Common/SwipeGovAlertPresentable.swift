import Foundation
import BigInt

struct SwipeGovBalanceAlertModel {
    let votingAmount: String
    let votingConviction: String
}

protocol SwipeGovAlertPresentable {
    func presentBalanceAlert(
        from view: ControllerBackedProtocol?,
        model: SwipeGovBalanceAlertModel,
        locale: Locale,
        action: @escaping () -> Void
    )

    func presentRemoveListItem(
        from view: ControllerBackedProtocol?,
        for votingItem: VotingBasketItemLocal,
        locale: Locale,
        action: @escaping () -> Void
    )

    func presentReferendaExcluded(
        from view: ControllerBackedProtocol?,
        availableBalance: String,
        locale: Locale,
        action: @escaping () -> Void
    )
}

extension SwipeGovAlertPresentable where Self: AlertPresentable {
    func presentBalanceAlert(
        from view: ControllerBackedProtocol?,
        model: SwipeGovBalanceAlertModel,
        locale: Locale,
        action: @escaping () -> Void
    ) {
        let languages = locale.rLanguages

        let alertViewModel = AlertPresentableViewModel(
            title: R.string.localizable.swipeGovInsufficientBalanceAlertTitle(
                preferredLanguages: languages
            ),
            message: R.string.localizable.swipeGovInsufficientBalanceAlertMessage(
                model.votingAmount,
                model.votingConviction,
                preferredLanguages: languages
            ),
            actions: [
                .init(
                    title: R.string.localizable.commonChange(
                        preferredLanguages: languages
                    ),
                    style: .normal,
                    handler: action
                )
            ],
            closeAction: R.string.localizable.commonClose(
                preferredLanguages: languages
            )
        )

        present(
            viewModel: alertViewModel,
            style: .alert,
            from: view
        )
    }

    func presentRemoveListItem(
        from view: ControllerBackedProtocol?,
        for votingItem: VotingBasketItemLocal,
        locale: Locale,
        action: @escaping () -> Void
    ) {
        let languages = locale.rLanguages

        let alertViewModel = AlertPresentableViewModel(
            title: R.string.localizable.govVotingListItemRemoveAlertTitle(
                Int(votingItem.referendumId),
                preferredLanguages: languages
            ),
            message: R.string.localizable.govVotingListItemRemoveAlertMessage(
                preferredLanguages: languages
            ),
            actions: [
                .init(
                    title: R.string.localizable.commonCancel(
                        preferredLanguages: languages
                    ),
                    style: .cancel
                ),
                .init(
                    title: R.string.localizable.commonRemove(
                        preferredLanguages: languages
                    ),
                    style: .destructive,
                    handler: { action() }
                )
            ],
            closeAction: nil
        )

        present(
            viewModel: alertViewModel,
            style: .alert,
            from: view
        )
    }

    func presentReferendaExcluded(
        from view: ControllerBackedProtocol?,
        availableBalance: String,
        locale: Locale,
        action: @escaping () -> Void
    ) {
        let languages = locale.rLanguages

        let alertViewModel = AlertPresentableViewModel(
            title: R.string.localizable.swipeGovReferendaExcludedAlertTitle(
                preferredLanguages: languages
            ),
            message: R.string.localizable.swipeGovReferendaExcludedAlertMessage(
                availableBalance,
                preferredLanguages: languages
            ),
            actions: [
                .init(
                    title: R.string.localizable.commonOk(
                        preferredLanguages: languages
                    ),
                    style: .cancel,
                    handler: { action() }
                )
            ],
            closeAction: nil
        )

        present(
            viewModel: alertViewModel,
            style: .alert,
            from: view
        )
    }
}
