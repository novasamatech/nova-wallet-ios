import Foundation
import SoraFoundation

final class TinderGovSetupPresenter: BaseReferendumVoteSetupPresenter {
    weak var view: TinderGovSetupViewProtocol? {
        get {
            baseView as? TinderGovSetupViewProtocol
        }
        set {
            baseView = newValue
        }
    }

    let interactor: TinderGovSetupInteractorInputProtocol
    let wireframe: TinderGovSetupWireframeProtocol

    let metaAccount: MetaAccountModel

    init(
        chain: ChainModel,
        metaAccount: MetaAccountModel,
        initData: ReferendumVotingInitData,
        dataValidatingFactory: GovernanceValidatorFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        referendumFormatter: LocalizableResource<NumberFormatter>,
        chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol,
        referendumStringsViewModelFactory: ReferendumDisplayStringFactoryProtocol,
        lockChangeViewModelFactory: ReferendumLockChangeViewModelFactoryProtocol,
        baseInteractor: ReferendumVoteSetupInteractorInputProtocol,
        interactor: TinderGovSetupInteractorInputProtocol,
        wireframe: TinderGovSetupWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.metaAccount = metaAccount
        self.interactor = interactor
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
            baseInteractor: baseInteractor,
            wireframe: wireframe,
            localizationManager: localizationManager,
            logger: logger
        )
    }

    override func refreshLockDiff() {
        guard let trackVoting = votesResult?.value else {
            return
        }

        baseInteractor.refreshLockDiff(
            for: trackVoting,
            newVote: nil,
            blockHash: votesResult?.blockHash
        )
    }

    override func updateVotesView() {
        guard
            let assetInfo = chain.utilityAssetDisplayInfo(),
            let votingAmount = deriveVotePower(using: assetInfo)
        else {
            return
        }

        let voteString = referendumStringsViewModelFactory.createVotes(
            from: votingAmount.votingAmount,
            chain: chain,
            locale: selectedLocale
        )

        baseView?.didReceiveVotes(viewModel: voteString ?? "")
    }
}

// MARK: TinderGovSetupPresenterProtocol

extension TinderGovSetupPresenter: TinderGovSetupPresenterProtocol {
    func proceed() {
        performValidation { [weak self] in
            guard
                let self,
                let assetInfo = chain.utilityAssetDisplayInfo(),
                let votingPower = deriveVotePower(using: assetInfo)
            else {
                return
            }

            interactor.process(votingPower: votingPower)
        }
    }
}

// MARK: TinderGovSetupInteractorOutputProtocol

extension TinderGovSetupPresenter: TinderGovSetupInteractorOutputProtocol {
    func didProcessVotingPower() {
        wireframe.showTinderGov(
            from: view,
            locale: selectedLocale
        )
    }
}

// MARK: Private

private extension TinderGovSetupPresenter {
    func performValidation(notifying completionBlock: @escaping DataValidationRunnerCompletion) {
        guard let assetInfo = chain.utilityAssetDisplayInfo() else {
            return
        }

        let votePower = deriveVotePower(using: assetInfo)

        let params = GovernanceVotePowerValidatingParams(
            assetBalance: assetBalance,
            votePower: votePower,
            assetInfo: assetInfo
        )

        let handlers = GovernanceVoteValidatingHandlers(
            convictionUpdateClosure: { [weak self] in
                self?.selectConvictionValue(0)
                self?.provideConviction()
            },
            feeErrorClosure: { [weak self] in
                // TODO: Implement validation error processing
            }
        )

        DataValidationRunner.validateVotingPower(
            factory: dataValidatingFactory,
            params: params,
            selectedLocale: selectedLocale,
            handlers: handlers,
            successClosure: completionBlock
        )
    }

    func deriveVotePower(using assetInfo: AssetBalanceDisplayInfo) -> VotingPowerLocal? {
        guard let amount = inputResult?.absoluteValue(from: balanceMinusFee()).toSubstrateAmount(
            precision: assetInfo.assetPrecision
        ) else {
            return nil
        }

        return VotingPowerLocal(
            chainId: chain.chainId,
            metaId: metaAccount.metaId,
            conviction: .init(from: conviction),
            amount: amount
        )
    }
}