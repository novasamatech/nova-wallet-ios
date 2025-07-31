import Foundation
import Foundation_iOS
import BigInt

extension GovernanceDelegateConfirmPresenter: GovernanceDelegateConfirmPresenterProtocol {
    func setup() {
        updateView()

        interactor.setup()

        refreshFee()
    }

    func presentSenderAccount() {
        guard
            let address = try? selectedAccount.chainAccount.accountId.toAddress(using: chain.chainFormat),
            let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: selectedLocale
        )
    }

    func presentDelegateAccount() {
        guard
            let address = try? delegation.delegateId.toAddress(using: chain.chainFormat),
            let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: selectedLocale
        )
    }

    func presentTracks() {
        wireframe.showTracks(from: view, tracks: delegationInfo.additions)
    }

    func confirm() {
        guard let assetInfo = chain.utilityAssetDisplayInfo() else {
            return
        }

        let params = GovernanceDelegateValidatingParams(
            assetBalance: assetBalance,
            newDelegation: delegation,
            fee: fee,
            votes: votesResult?.value?.votes,
            assetInfo: assetInfo,
            selfAccountId: selectedAccount.chainAccount.accountId
        )

        DataValidationRunner.validateDelegate(
            factory: dataValidatingFactory,
            params: params,
            selectedLocale: selectedLocale,
            feeErrorClosure: { [weak self] in
                self?.refreshFee()
            }, successClosure: { [weak self] in
                guard let delegation = self?.delegation, let voting = self?.votesResult?.value else {
                    return
                }

                self?.view?.didStartLoading()

                let actions = delegation.createActions(from: voting)

                self?.interactor.submit(actions: actions)
            }
        )
    }
}

extension GovernanceDelegateConfirmPresenter: GovernanceDelegateConfirmInteractorOutputProtocol {
    func didReceiveLocks(_ locks: AssetLocks) {
        assetLocks = locks

        provideTransferableAmountViewModel()
    }

    func didReceiveSubmissionResult(_ result: SubmitIndexedExtrinsicResult) {
        view?.didStopLoading()

        let handlers = MultiExtrinsicResultActions(
            onSuccess: { [weak self] in
                guard let strongSelf = self else {
                    return
                }

                strongSelf.wireframe.complete(
                    on: strongSelf.view,
                    sender: result.senders().first,
                    locale: strongSelf.selectedLocale
                )
            }, onErrorRetry: { [weak self] closure, indexes in
                self?.view?.didStartLoading()

                self?.interactor.retryMultiExtrinsic(
                    for: closure,
                    indexes: indexes
                )
            }, onErrorSkip: { [weak self] in
                self?.wireframe.skip(on: self?.view)
            }
        )

        wireframe.presentMultiExtrinsicStatusFromResult(
            on: view,
            result: result,
            locale: selectedLocale,
            handlers: handlers
        )
    }

    func didReceiveError(_ error: GovernanceDelegateConfirmInteractorError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .locksSubscriptionFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case let .submitFailed(internalError):
            view?.didStopLoading()

            wireframe.handleExtrinsicSigningErrorPresentationElseDefault(
                internalError,
                view: view,
                closeAction: .dismiss,
                locale: selectedLocale,
                completionClosure: nil
            )
        }
    }

    func didReceiveAssetBalance(_ assetBalance: AssetBalance?) {
        self.assetBalance = assetBalance
    }

    func didReceivePrice(_ priceData: PriceData?) {
        self.priceData = priceData

        provideAmountViewModel()
        provideFeeViewModel()
    }

    func didReceiveFee(_ fee: ExtrinsicFeeProtocol) {
        self.fee = fee

        provideFeeViewModel()
    }

    func didReceiveDelegateStateDiff(_ diff: GovernanceDelegateStateDiff) {
        lockDiff = diff

        provideTransferableAmountViewModel()
        provideLockedAmountViewModel()
        provideUndelegatingPeriodViewModel()
    }

    func didReceiveAccountVotes(_ votes: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>) {
        votesResult = votes

        refreshLockDiff()
    }

    func didReceiveBlockTime(_ blockTime: BlockTime) {
        self.blockTime = blockTime

        provideUndelegatingPeriodViewModel()
    }

    func didReceiveBaseError(_ error: GovernanceDelegateInteractorError) {
        logger.error("Did receive base error: \(error)")

        switch error {
        case .assetBalanceFailed, .priceFailed, .accountVotesFailed,
             .blockNumberSubscriptionFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case .feeFailed:
            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        case .blockTimeFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refreshBlockTime()
            }
        case .stateDiffFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshLockDiff()
            }
        }
    }
}

extension GovernanceDelegateConfirmPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
