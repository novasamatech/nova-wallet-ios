import Foundation
import SoraFoundation

final class ReferendumVoteSetupPresenter: BaseReferendumVoteSetupPresenter {
    let supportsAbstainVoting: Bool
    let referendumIndex: ReferendumIdLocal

    weak var view: ReferendumVoteSetupViewProtocol? {
        get {
            baseView as? ReferendumVoteSetupViewProtocol
        }
        set {
            baseView = newValue
        }
    }

    let wireframe: ReferendumVoteSetupWireframeProtocol

    init(
        chain: ChainModel,
        referendumIndex: ReferendumIdLocal,
        initData: ReferendumVotingInitData,
        supportsAbstainVoting: Bool,
        dataValidatingFactory: GovernanceValidatorFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        referendumFormatter: LocalizableResource<NumberFormatter>,
        chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol,
        referendumStringsViewModelFactory: ReferendumDisplayStringFactoryProtocol,
        lockChangeViewModelFactory: ReferendumLockChangeViewModelFactoryProtocol,
        interactor: ReferendumVoteSetupInteractorInputProtocol,
        wireframe: ReferendumVoteSetupWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.supportsAbstainVoting = supportsAbstainVoting
        self.referendumIndex = referendumIndex
        self.wireframe = wireframe

        super.init(
            chain: chain,
            initData: initData,
            dataValidatingFactory: dataValidatingFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            referendumFormatter: referendumFormatter,
            chainAssetViewModelFactory: chainAssetViewModelFactory,
            referendumStringsViewModelFactory: referendumStringsViewModelFactory,
            lockChangeViewModelFactory: lockChangeViewModelFactory,
            baseInteractor: interactor,
            wireframe: wireframe,
            localizationManager: localizationManager,
            logger: logger
        )
    }

    override func updateAfterAmountChanged() {
        super.updateAfterAmountChanged()

        refreshFee()
    }

    override func updateView() {
        super.updateView()

        provideAbstainAvailable()
        provideReferendumIndex()
    }

    override func updateVotesView() {
        guard let vote = deriveNewVote() else {
            return
        }

        let voteValue = vote.voteAction.conviction().votes(for: vote.voteAction.amount()) ?? 0

        let voteString = referendumStringsViewModelFactory.createVotes(
            from: voteValue,
            chain: chain,
            locale: selectedLocale
        )

        baseView?.didReceiveVotes(viewModel: voteString ?? "")
    }

    override func refreshLockDiff() {
        guard let trackVoting = votesResult?.value, let newVote = deriveNewVote() else {
            return
        }

        baseInteractor.refreshLockDiff(
            for: trackVoting,
            newVote: newVote,
            blockHash: votesResult?.blockHash
        )
    }

    override func updateAfterConvictionSelect() {
        super.updateAfterConvictionSelect()

        refreshFee()
    }

    override func updateAfterBalanceReceive() {
        super.updateAfterBalanceReceive()

        refreshFee()
    }

    override func processError(_ error: ReferendumVoteInteractorError) {
        super.processError(error)

        if case .feeFailed = error {
            wireframe.presentFeeStatus(on: baseView, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        }
    }
}

// MARK: ReferendumVoteSetupPresenterProtocol

extension ReferendumVoteSetupPresenter: ReferendumVoteSetupPresenterProtocol {
    func proceedNay() {
        proceed(with: .nay)
    }

    func proceedAye() {
        proceed(with: .aye)
    }

    func proceedAbstain() {
        proceed(with: .abstain)
    }
}

// MARK: Private

private extension ReferendumVoteSetupPresenter {
    func deriveNewVote(_ selectedAction: VoteAction = .aye) -> ReferendumNewVote? {
        let amount = inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0

        guard
            let precision = chain.utilityAsset()?.displayInfo.assetPrecision,
            let amountInPlank = amount.toSubstrateAmount(precision: precision) else {
            return nil
        }

        let model = ReferendumVoteActionModel(
            amount: amountInPlank,
            conviction: conviction
        )

        let voteAction: ReferendumVoteAction = switch selectedAction {
        case .aye: .aye(model)
        case .nay: .nay(model)
        case .abstain: .abstain(amount: model.amount)
        }

        return ReferendumNewVote(index: referendumIndex, voteAction: voteAction)
    }

    func refreshFee() {
        guard let newVote = deriveNewVote() else {
            return
        }

        baseInteractor.estimateFee(for: newVote.voteAction)
    }

    func proceed(with voteAction: VoteAction) {
        performValidation(for: voteAction) { [weak self] in
            guard let newVote = self?.deriveNewVote(voteAction) else {
                return
            }

            let initData = ReferendumVotingInitData(
                votesResult: self?.votesResult,
                blockNumber: self?.blockNumber,
                blockTime: self?.blockTime,
                referendum: self?.referendum,
                lockDiff: self?.lockDiff
            )

            self?.wireframe.showConfirmation(
                from: self?.view,
                vote: newVote,
                initData: initData
            )
        }
    }

    func performValidation(
        for voteAction: VoteAction,
        notifying completionBlock: @escaping DataValidationRunnerCompletion
    ) {
        guard let assetInfo = chain.utilityAssetDisplayInfo() else {
            return
        }

        let newVote = deriveNewVote(voteAction)

        let params = GovernanceVoteValidatingParams(
            assetBalance: assetBalance,
            referendum: referendum,
            newVote: newVote,
            selectedConviction: conviction,
            fee: fee,
            votes: votesResult?.value?.votes,
            assetInfo: assetInfo
        )

        let handlers = GovernanceVoteValidatingHandlers(
            convictionUpdateClosure: { [weak self] in
                self?.selectConvictionValue(0)
                self?.provideConviction()
            },
            feeErrorClosure: { [weak self] in
                self?.refreshFee()
            }
        )

        DataValidationRunner.validateVote(
            factory: dataValidatingFactory,
            params: params,
            selectedLocale: selectedLocale,
            handlers: handlers,
            successClosure: completionBlock
        )
    }

    func provideAbstainAvailable() {
        view?.didReceive(abstainAvailable: supportsAbstainVoting)
    }

    func provideReferendumIndex() {
        let referendumString = referendumFormatter.value(for: selectedLocale).string(from: referendumIndex as NSNumber)
        view?.didReceive(referendumNumber: referendumString ?? "")
    }
}
