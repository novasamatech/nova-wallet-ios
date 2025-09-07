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
            title: R.string(preferredLanguages: languages
            ).localizable.swipeGovInsufficientBalanceAlertTitle(),
            message: R.string(preferredLanguages: languages
            ).localizable.swipeGovInsufficientBalanceAlertMessage(model.votingAmount, model.votingConviction),
            actions: [
                .init(
                    title: R.string(preferredLanguages: languages
                    ).localizable.commonChange(),
                    style: .normal,
                    handler: action
                )
            ],
            closeAction: R.string(preferredLanguages: languages
            ).localizable.commonClose()
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
            message: R.string(preferredLanguages: languages
            ).localizable.govVotingListItemRemoveAlertMessage(),
            actions: [
                .init(
                    title: R.string(preferredLanguages: languages
                    ).localizable.commonCancel(),
                    style: .cancel
                ),
                .init(
                    title: R.string(preferredLanguages: languages
                    ).localizable.commonRemove(),
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
            title: R.string(preferredLanguages: languages
            ).localizable.swipeGovReferendaExcludedAlertTitle(),
            message: R.string(preferredLanguages: languages
            ).localizable.swipeGovReferendaExcludedAlertMessage(availableBalance),
            actions: [
                .init(
                    title: R.string(preferredLanguages: languages
                    ).localizable.commonOk(),
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
