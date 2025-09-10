import Foundation

protocol ParaStkYieldBoostErrorPresentable: BaseErrorPresentable {
    func presentInvalidTaskExecutionTime(from view: ControllerBackedProtocol, locale: Locale?)

    func presentNotEnoughBalanceForThreshold(
        from view: ControllerBackedProtocol,
        threshold: String,
        fee: String,
        balance: String,
        locale: Locale?
    )

    func presentNotEnoughBalanceForExecutionFee(
        from view: ControllerBackedProtocol,
        executionFee: String,
        extrinsicFee: String,
        balance: String,
        locale: Locale?
    )

    func presentCancelTasksForCollators(
        from view: ControllerBackedProtocol,
        collator: String,
        action: @escaping () -> Void,
        locale: Locale?
    )

    func presentCancellingTaskNotExists(from view: ControllerBackedProtocol, locale: Locale?)
}

extension ParaStkYieldBoostErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentInvalidTaskExecutionTime(from view: ControllerBackedProtocol, locale: Locale?) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.yieldBoostTimeNotLoadedTitle()

        let message = R.string(preferredLanguages: locale.rLanguages).localizable.yieldBoostTimeNotLoadedMessage()

        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentNotEnoughBalanceForThreshold(
        from view: ControllerBackedProtocol,
        threshold: String,
        fee: String,
        balance: String,
        locale: Locale?
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.yieldBoostNotEnoughThresholdTitle()

        let message = R.string(preferredLanguages: locale.rLanguages).localizable.yieldBoostNotEnoughThresholdMessage(
            fee,
            threshold,
            balance
        )

        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentNotEnoughBalanceForExecutionFee(
        from view: ControllerBackedProtocol,
        executionFee: String,
        extrinsicFee: String,
        balance: String,
        locale: Locale?
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.yieldBoostNotEnoughExecutionFeeTitle()

        let message = R.string(preferredLanguages: locale.rLanguages).localizable.yieldBoostNotEnoughExecutionFeeMessage(
            extrinsicFee,
            executionFee,
            balance
        )

        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentCancelTasksForCollators(
        from view: ControllerBackedProtocol,
        collator: String,
        action: @escaping () -> Void,
        locale: Locale?
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.yieldBoostChangeTitle()
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.yieldBoostChangeMessage(collator)

        presentWarning(
            for: title,
            message: message,
            action: action,
            view: view,
            locale: locale
        )
    }

    func presentCancellingTaskNotExists(from view: ControllerBackedProtocol, locale: Locale?) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.yieldBoostTaskNotFoundTitle()

        let message = R.string(preferredLanguages: locale.rLanguages).localizable.yieldBoostTaskNotFoundMessage()

        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }
}
