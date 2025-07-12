import Foundation
import BigInt
import Foundation_iOS

final class MultisigOpValidationPresenter {
    let view: ControllerBackedProtocol

    private let wireframe: MOValidationWireframeProtocol
    private let interactor: MOValidationInteractorInputProtocol

    private let dataValidationFactory: MultisigDataValidatorFactoryProtocol
    private let chainAsset: ChainAsset
    private let localizationManager: LocalizationManagerProtocol
    private let logger: LoggerProtocol
    private let completionClosure: DelegatedSignValidationCompletion
    private let signatoryName: String
    private let multisigName: String

    private var depositStorage: UncertainStorage<BigUInt> = .undefined
    private var signatoryBalanceStorage: UncertainStorage<AssetBalance?> = .undefined
    private var feeStorage: UncertainStorage<Balance?> = .undefined
    private var multisigOperationStorage: UncertainStorage<MultisigPallet.MultisigDefinition?> = .undefined
    private var minBalanceStorage: UncertainStorage<Balance> = .undefined

    init(
        view: ControllerBackedProtocol,
        interactor: MOValidationInteractorInputProtocol,
        wireframe: MOValidationWireframeProtocol,
        dataValidationFactory: MultisigDataValidatorFactoryProtocol,
        chainAsset: ChainAsset,
        signatoryName: String,
        multisigName: String,
        completionClosure: @escaping DelegatedSignValidationCompletion,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.view = view
        self.interactor = interactor
        self.wireframe = wireframe
        self.dataValidationFactory = dataValidationFactory
        self.signatoryName = signatoryName
        self.multisigName = multisigName
        self.chainAsset = chainAsset
        self.completionClosure = completionClosure
        self.localizationManager = localizationManager
        self.logger = logger
    }
}

// MARK: - Private

private extension MultisigOpValidationPresenter {
    func completeValidation() {
        guard
            case let .defined(deposit) = depositStorage,
            case let .defined(signatoryBalance) = signatoryBalanceStorage,
            case let .defined(fee) = feeStorage,
            case let .defined(multisigOperation) = multisigOperationStorage,
            case let .defined(minBalance) = minBalanceStorage else {
            return
        }

        let locale = localizationManager.selectedLocale

        DataValidationRunner(validators: [
            dataValidationFactory.canReserveDeposit(
                params: MultisigDepositValidationParams(
                    deposit: deposit,
                    balance: signatoryBalance?.regularReservableBalance(for: minBalance),
                    payedFee: fee,
                    signatoryName: signatoryName,
                    assetInfo: chainAsset.assetDisplayInfo
                ),
                locale: locale
            ),
            dataValidationFactory.operationNotExists(
                multisigOperation == nil,
                multisigName: multisigName,
                locale: locale
            )
        ]).runValidation(
            notifyingOnSuccess: { [weak self] in
                guard let self else { return }

                if let signatoryBalance {
                    interactor.reserve(deposit: deposit, balance: signatoryBalance)
                }

                completionClosure(true)
            },
            notifyingOnStop: { [weak self] problem in
                switch problem {
                case .error, .warning:
                    self?.completionClosure(false)
                case .asyncProcess:
                    break
                }
            },
            notifyingOnResume: nil
        )
    }
}

// MARK: - MultisigValidationPresenterProtocol

extension MultisigOpValidationPresenter: MultisigOpValidationPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

// MARK: - MultisigValidationInteractorOutputProtocol

extension MultisigOpValidationPresenter: MOValidationInteractorOutputProtocol {
    func didReceiveSignatoryBalance(_ balance: AssetBalance?) {
        logger.debug("Balance: \(String(describing: balance))")

        signatoryBalanceStorage = .defined(balance)

        completeValidation()
    }

    func didReceivePaidFee(_ fee: Balance?) {
        logger.debug("Fee: \(String(describing: fee))")

        feeStorage = .defined(fee)

        completeValidation()
    }

    func didReceiveDeposit(_ deposit: Balance) {
        logger.debug("Deposit: \(deposit) for chain: \(chainAsset.chain.name)")

        depositStorage = .defined(deposit)

        completeValidation()
    }

    func didReceiveMultisigDefinition(_ definition: MultisigPallet.MultisigDefinition?) {
        logger.debug("Multisig operation: \(String(describing: definition))")

        multisigOperationStorage = .defined(definition)

        completeValidation()
    }

    func didReceiveBalanceExistense(_ balanceExistence: AssetBalanceExistence) {
        logger.debug("Did receive balance existense: \(balanceExistence)")

        minBalanceStorage = .defined(balanceExistence.minBalance)

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
