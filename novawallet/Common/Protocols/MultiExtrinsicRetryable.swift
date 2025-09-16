import Foundation

struct MultiExtrinsicRetryParams {
    let errors: [Error]
    let totalExtrinsics: Int
}

protocol MultiExtrinsicRetryable {
    func presentMultiExtrinsicStatus(
        on view: ControllerBackedProtocol?,
        params: MultiExtrinsicRetryParams,
        locale: Locale?,
        onRetry: @escaping () -> Void,
        onSkip: @escaping () -> Void
    )
}

extension MultiExtrinsicRetryable where Self: AlertPresentable {
    private func createMessage(from params: MultiExtrinsicRetryParams, locale: Locale?) -> String {
        let failedCountString = "\(params.errors.count)/\(params.totalExtrinsics)"

        if let error = params.errors.first as? ErrorContentConvertible {
            let details = error.toErrorContent(for: locale).message

            return R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonMultiTxErrorHasDetailsMessage(
                failedCountString,
                details
            )
        } else {
            return R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonMultiTxErrorNoDetailsMessage(
                failedCountString
            )
        }
    }

    func presentMultiExtrinsicStatus(
        on view: ControllerBackedProtocol?,
        params: MultiExtrinsicRetryParams,
        locale: Locale?,
        onRetry: @escaping () -> Void,
        onSkip: @escaping () -> Void
    ) {
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonMultiTxErrorTitle()
        let message = createMessage(from: params, locale: locale)

        let skipAction = AlertPresentableAction(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.commonSkip(),
            style: .cancel,
            handler: onSkip
        )

        let retryAction = AlertPresentableAction(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.commonRetry(),
            style: .normal,
            handler: onRetry
        )

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [skipAction, retryAction],
            closeAction: nil
        )

        present(viewModel: viewModel, style: .alert, from: view)
    }
}

struct MultiExtrinsicResultActions {
    let onSuccess: () -> Void
    let onErrorRetry: (@escaping ExtrinsicBuilderIndexedClosure, IndexSet) -> Void
    let onErrorSkip: () -> Void
}

extension MultiExtrinsicRetryable where Self: AlertPresentable & ErrorPresentable & ExtrinsicSigningErrorHandling {
    func presentMultiExtrinsicStatusFromResult(
        on view: ControllerBackedProtocol?,
        result: SubmitIndexedExtrinsicResult,
        locale: Locale?,
        handlers: MultiExtrinsicResultActions
    ) {
        let errors = result.errors()

        guard !errors.isEmpty else {
            handlers.onSuccess()
            return
        }

        let error = errors[0]

        guard !handleExtrinsicSigningErrorPresentation(
            error,
            view: view,
            closeAction: .dismiss,
            completionClosure: nil
        ) else {
            return
        }

        if let builderClosure = result.builderClosure {
            presentMultiExtrinsicStatus(
                on: view,
                params: .init(errors: errors, totalExtrinsics: result.results.count),
                locale: locale,
                onRetry: {
                    handlers.onErrorRetry(builderClosure, result.failedIndexes())
                }, onSkip: {
                    handlers.onErrorSkip()
                }
            )
        } else {
            _ = present(error: error, from: view, locale: locale)
        }
    }
}
