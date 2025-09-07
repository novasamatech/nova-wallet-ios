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
            R.string(preferredLanguages: locale.rLanguages).localizable.commonMinutesFormat(
                format: value
            )
        } ?? ""

        let message = R.string(preferredLanguages: locale.rLanguages).localizable.commonTxQrExpiredMessage(
            minutes,
            typeName
        )

        let action = AlertPresentableAction(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.commonOkBack(),
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
