import Foundation

protocol TransactionExpiredPresentable {
    func presentTransactionExpired(
        on view: ControllerBackedProtocol,
        typeName: String,
        validInMinutes: Int?,
        locale: Locale,
        completingClosure: @escaping () -> Void
    )
}

extension TransactionExpiredPresentable where Self: AlertPresentable {
    func presentTransactionExpired(
        on view: ControllerBackedProtocol,
        typeName: String,
        validInMinutes: Int?,
        locale: Locale,
        completingClosure: @escaping () -> Void
    ) {
        let title = R.string.localizable.commonQrCodeExpired(preferredLanguages: locale.rLanguages)
        let minutes = validInMinutes.map { value in
            R.string.localizable.commonMinutesFormat(
                format: value,
                preferredLanguages: locale.rLanguages
            )
        } ?? ""

        let message = R.string.localizable.commonTxQrExpiredMessage(
            minutes,
            typeName,
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
