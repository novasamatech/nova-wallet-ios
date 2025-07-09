import Foundation
import BigInt
import Foundation_iOS

enum MultisigBalanceValidationModeParams {
    case rootSigner(params: MultisigBalanceValidationParams)

    case delegatedSigner(
        rootSignerParams: MultisigBalanceValidationParams,
        delegateSignerParams: MultisigBalanceValidationParams
    )
}

struct MultisigBalanceValidationParams {
    let metaAccountResponse: MetaChainAccountResponse
    let available: BigUInt
    let deposit: BigUInt?
    let fee: ExtrinsicFeeProtocol?
    let asset: AssetBalanceDisplayInfo
}

final class MultisigValidationPresenter {
    let view: ControllerBackedProtocol

    private let wireframe: MultisigValidationWireframeProtocol
    private let interactor: MultisigValidationInteractorInputProtocol

    private let validationMode: MultisigValidationMode

    private let dataValidationFactory: MultisigDataValidatorFactoryProtocol
    private let chainAsset: ChainAsset
    private let localizationManager: LocalizationManagerProtocol
    private let logger: LoggerProtocol
    private let completionClosure: DelegatedSignValidationCompletion

    private var deposit: BigUInt?
    private var balances: [AccountId: AssetBalance]?
    private var fee: ExtrinsicFeeProtocol?
    private var balanceExistence: AssetBalanceExistence?

    init(
        view: ControllerBackedProtocol,
        interactor: MultisigValidationInteractorInputProtocol,
        validationMode: MultisigValidationMode,
        wireframe: MultisigValidationWireframeProtocol,
        dataValidationFactory: MultisigDataValidatorFactoryProtocol,
        chainAsset: ChainAsset,
        completionClosure: @escaping DelegatedSignValidationCompletion,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.view = view
        self.interactor = interactor
        self.validationMode = validationMode
        self.wireframe = wireframe
        self.dataValidationFactory = dataValidationFactory
        self.chainAsset = chainAsset
        self.completionClosure = completionClosure
        self.localizationManager = localizationManager
        self.logger = logger
    }
}

// MARK: - Private

private extension MultisigValidationPresenter {
    func completeValidation() {}

    func createBalanceValidationParams() -> MultisigBalanceValidationModeParams? {
        guard
            let balances,
            let fee,
            let deposit,
            let balanceExistence,
            validationMode.matchesBalances(balances)
        else { return nil }

        switch validationMode {
        case let .rootSigner(signer):
            guard let reservable = balances[signer.chainAccount.accountId]?.regularReservableBalance(
                for: balanceExistence.minBalance
            ) else { return nil }

            let params = MultisigBalanceValidationParams(
                metaAccountResponse: signer,
                available: reservable,
                deposit: deposit,
                fee: fee,
                asset: chainAsset.assetDisplayInfo
            )

            return .rootSigner(params: params)
        case let .delegatedSigner(signer, delegate):
            guard
                let signerReservable = balances[signer.chainAccount.accountId]?.regularReservableBalance(
                    for: balanceExistence.minBalance
                ),
                let delegateReservable = balances[delegate.chainAccount.accountId]?.regularReservableBalance(
                    for: balanceExistence.minBalance
                )
            else { return nil }

            let signerParams = MultisigBalanceValidationParams(
                metaAccountResponse: signer,
                available: signerReservable,
                deposit: deposit,
                fee: fee,
                asset: chainAsset.assetDisplayInfo
            )
            let delegateParams = MultisigBalanceValidationParams(
                metaAccountResponse: delegate,
                available: delegateReservable,
                deposit: deposit,
                fee: fee,
                asset: chainAsset.assetDisplayInfo
            )

            return .delegatedSigner(rootSignerParams: signerParams, delegateSignerParams: delegateParams)
        }
    }
}

// MARK: - MultisigValidationPresenterProtocol

extension MultisigValidationPresenter: MultisigValidationPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

// MARK: - MultisigValidationInteractorOutputProtocol

extension MultisigValidationPresenter: MultisigValidationInteractorOutputProtocol {
    func didReceiveBalances(_ balances: [AccountId: AssetBalance]) {
        logger.debug("Did receive signer balances: \(balances)")

        self.balances = balances

        completeValidation()
    }

    func didReceiveDeposit(_ deposit: BigUInt) {
        logger.debug("Did receive deposit: \(deposit) for chain: \(chainAsset.chain.chainId)")

        self.deposit = deposit

        completeValidation()
    }

    func didReceiveBalanceExistense(_ balanceExistence: AssetBalanceExistence) {
        logger.debug("Did receive min balance: \(balanceExistence)")

        self.balanceExistence = balanceExistence

        completeValidation()
    }

    func didReceiveFee(_ fee: ExtrinsicFeeProtocol) {
        logger.debug("Did receive fee: \(fee)")

        self.fee = fee

        completeValidation()
    }

    func didReceiveError(_ error: Error) {
        logger.error("Did receive error: \(error)")

        let locale = localizationManager.selectedLocale

        if !wireframe.present(error: error, from: view, locale: locale) {
            _ = wireframe.present(error: CommonError.undefined, from: view, locale: locale)
        }

        completionClosure(false)
    }
}
