import Foundation
import SoraFoundation

final class ReferendumVoteSetupPresenter: BaseReferendumVoteSetupPresenter {
    let supportsAbstainVoting: Bool

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
        self.wireframe = wireframe

        super.init(
            chain: chain,
            referendumIndex: referendumIndex,
            initData: initData,
            dataValidatingFactory: dataValidatingFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            referendumFormatter: referendumFormatter,
            chainAssetViewModelFactory: chainAssetViewModelFactory,
            referendumStringsViewModelFactory: referendumStringsViewModelFactory,
            lockChangeViewModelFactory: lockChangeViewModelFactory,
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: localizationManager,
            logger: logger
        )
    }

    override func updateView() {
        provideAbstainAvailable()
        provideReferendumIndex()
        super.updateView()
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
