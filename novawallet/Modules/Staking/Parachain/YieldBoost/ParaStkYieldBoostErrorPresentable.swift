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
        action: @escaping () -> Void,
        locale: Locale?
    )

    func presentCancellingTaskNotExists(from view: ControllerBackedProtocol, locale: Locale?)
}

extension ParaStkYieldBoostErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentInvalidTaskExecutionTime(from view: ControllerBackedProtocol, locale: Locale?) {
        let title = R.string.localizable.yieldBoostTimeNotLoadedTitle(
            preferredLanguages: locale?.rLanguages
        )

        let message = R.string.localizable.yieldBoostTimeNotLoadedMessage(
            preferredLanguages: locale?.rLanguages
        )

        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentNotEnoughBalanceForThreshold(
        from view: ControllerBackedProtocol,
        threshold: String,
        fee: String,
        balance: String,
        locale: Locale?
    ) {
        let title = R.string.localizable.yieldBoostNotEnoughThresholdTitle(
            preferredLanguages: locale?.rLanguages
        )

        let message = R.string.localizable.yieldBoostNotEnoughThresholdMessage(
            fee,
            threshold,
            balance,
            preferredLanguages: locale?.rLanguages
        )

        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentNotEnoughBalanceForExecutionFee(
        from view: ControllerBackedProtocol,
        executionFee: String,
        extrinsicFee: String,
        balance: String,
        locale: Locale?
    ) {
        let title = R.string.localizable.yieldBoostNotEnoughExecutionFeeTitle(
            preferredLanguages: locale?.rLanguages
        )

        let message = R.string.localizable.yieldBoostNotEnoughExecutionFeeMessage(
            extrinsicFee,
            executionFee,
            balance,
            preferredLanguages: locale?.rLanguages
        )

        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentCancelTasksForCollators(
        from view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale: Locale?
    ) {
        let title = R.string.localizable.yieldBoostAlreadyEnabledTitle(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable.yieldBoostAlreadyEnabledMessage(preferredLanguages: locale?.rLanguages)

        presentWarning(
            for: title,
            message: message,
            action: action,
            view: view,
            locale: locale
        )
    }

    func presentCancellingTaskNotExists(from view: ControllerBackedProtocol, locale: Locale?) {
        let title = R.string.localizable.yieldBoostTaskNotFoundTitle(
            preferredLanguages: locale?.rLanguages
        )

        let message = R.string.localizable.yieldBoostTaskNotFoundMessage(
            preferredLanguages: locale?.rLanguages
        )

        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }
}
