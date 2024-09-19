import Foundation
import BigInt

struct SwipeGovBalanceAlertModel {
    let votingPower: VotingPowerLocal
    let invalidItems: [VotingBasketItemLocal]
    let assetInfo: AssetBalanceDisplayInfo
    let changeAction: () -> Void
}

protocol SwipeGovAlertPresentable {
    func presentBalanceAlert(
        from view: ControllerBackedProtocol?,
        model: SwipeGovBalanceAlertModel,
        locale: Locale
    )

    func presentRemoveListItem(
        from view: ControllerBackedProtocol?,
        for votingItem: VotingBasketItemLocal,
        locale: Locale,
        action: @escaping () -> Void
    )

    func presentReferendaExcluded(
        availableBalance: BigUInt,
        assetInfo: AssetBalanceDisplayInfo,
        locale: Locale
    )
    
    func presentReferendaExcluded(
        from view: ControllerBackedProtocol?,
        availableBalance: BigUInt,
        assetInfo: AssetBalanceDisplayInfo,
        locale: Locale
    )
}

extension SwipeGovAlertPresentable where Self: AlertPresentable {
    func presentBalanceAlert(
        from view: ControllerBackedProtocol?,
        model: SwipeGovBalanceAlertModel,
        locale: Locale
    ) {
        let languages = locale.rLanguages
        let amountDecimal = NSDecimalNumber(
            decimal: model.votingPower.amount.decimal(assetInfo: model.assetInfo)
        )

        let alertViewModel = AlertPresentableViewModel(
            title: R.string.localizable.swipeGovInsufficientBalanceAlertTitle(
                preferredLanguages: languages
            ),
            message: R.string.localizable.swipeGovInsufficientBalanceAlertMessage(
                amountDecimal.doubleValue,
                model.assetInfo.symbol,
                model.votingPower.conviction.rawValue,
                preferredLanguages: languages
            ),
            actions: [
                .init(
                    title: R.string.localizable.commonChange(
                        preferredLanguages: languages
                    ),
                    style: .normal,
                    handler: { model.changeAction() }
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
        availableBalance: BigUInt,
        assetInfo: AssetBalanceDisplayInfo,
        locale: Locale
    ) {
        let languages = locale.rLanguages
        
        let balance = NSDecimalNumber(
            decimal: availableBalance.decimal(assetInfo: assetInfo)
        )

        let alertViewModel = AlertPresentableViewModel(
            title: R.string.localizable.swipeGovReferendaExcludedAlertTitle(
                preferredLanguages: languages
            ),
            message: R.string.localizable.swipeGovReferendaExcludedAlertMessage(
                balance.doubleValue,
                assetInfo.symbol,
                preferredLanguages: languages
            ),
            actions: [],
            closeAction: R.string.localizable.commonOk(
                preferredLanguages: languages
            )
        )

        present(
            viewModel: alertViewModel,
            style: .alert,
            from: view
        )
    }
}
