import Foundation

protocol TransactionExpiredPresentable {
    func presentTransactionExpired(
        on view: ControllerBackedProtocol,
        validInMinutes: Int,
        locale: Locale,
        completingClosure: @escaping () -> Void
    )
}

extension TransactionExpiredPresentable where Self: AlertPresentable {
    func presentTransactionExpired(
        on view: ControllerBackedProtocol,
        validInMinutes: Int,
        locale: Locale,
        completingClosure: @escaping () -> Void
    ) {
        let title = R.string.localizable.commonQrCodeExpired(preferredLanguages: locale.rLanguages)
        let minutes = R.string.localizable.commonMinutesFormat(
            format: validInMinutes,
            preferredLanguages: locale.rLanguages
        )

        let message = R.string.localizable.commonTxQrExpiredMessage(
            minutes,
            preferredLanguages: locale.rLanguages
        )

        let action = AlertPresentableAction(
            title: R.string.localizable.commonOkBack(preferredLanguages: locale.rLanguages),
            handler: completingClosure
        )

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [action],
            closeAction: nil
        )

        present(viewModel: viewModel, style: .alert, from: view)
    }
}
