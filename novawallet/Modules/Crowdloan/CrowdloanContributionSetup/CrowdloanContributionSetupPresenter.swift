import Foundation
import BigInt
import SoraFoundation
import SubstrateSdk

class CrowdloanContributionSetupPresenter {
    weak var view: CrowdloanContributionSetupViewProtocol?
    let wireframe: CrowdloanContributionSetupWireframeProtocol
    let interactor: CrowdloanContributionSetupInteractorInputProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let contributionViewModelFactory: CrowdloanContributionViewModelFactoryProtocol
    let dataValidatingFactory: CrowdloanDataValidatorFactoryProtocol
    let assetInfo: AssetBalanceDisplayInfo
    let explorers: [ChainModel.Explorer]?
    let logger: LoggerProtocol?

    private var crowdloan: Crowdloan?
    var displayInfo: CrowdloanDisplayInfo?
    private var totalBalanceValue: BigUInt?
    private var balance: Decimal?
    private var priceData: PriceData?
    private var fee: Decimal?
    private var blockNumber: BlockNumber?
    private var blockDuration: BlockTime?
    private var leasingPeriod: LeasingPeriod?
    private var minimumBalance: BigUInt?
    var minimumContribution: BigUInt?

    var bonusService: CrowdloanBonusServiceProtocol?

    var balanceMinusFee: Decimal { (balance ?? 0) - (fee ?? 0) }

    private var crowdloanMetadata: CrowdloanMetadata? {
        if
            let blockNumber = blockNumber,
            let blockDuration = blockDuration,
            let leasingPeriod = leasingPeriod {
            return CrowdloanMetadata(
                blockNumber: blockNumber,
                blockDuration: blockDuration,
                leasingPeriod: leasingPeriod
            )
        } else {
            return nil
        }
    }

    var inputResult: AmountInputResult?

    init(
        interactor: CrowdloanContributionSetupInteractorInputProtocol,
        wireframe: CrowdloanContributionSetupWireframeProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        contributionViewModelFactory: CrowdloanContributionViewModelFactoryProtocol,
        dataValidatingFactory: CrowdloanDataValidatorFactoryProtocol,
        assetInfo: AssetBalanceDisplayInfo,
        localizationManager: LocalizationManagerProtocol,
        bonusService: CrowdloanBonusServiceProtocol?,
        explorers: [ChainModel.Explorer]?,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.balanceViewModelFactory = balanceViewModelFactory
        self.contributionViewModelFactory = contributionViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.assetInfo = assetInfo
        self.bonusService = bonusService
        self.explorers = explorers
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func provideAssetVewModel() {
        guard minimumBalance != nil, minimumContribution != nil else {
            return
        }

        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee) ?? 0.0

        let assetViewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount,
            balance: balance,
            priceData: priceData
        ).value(for: selectedLocale)

        view?.didReceiveAsset(viewModel: assetViewModel)
    }

    private func provideFeeViewModel() {
        let feeViewModel = fee
            .map { balanceViewModelFactory.balanceFromPrice($0, priceData: priceData) }?
            .value(for: selectedLocale)

        view?.didReceiveFee(viewModel: feeViewModel)
    }

    private func provideInputViewModel() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee)

        let inputViewModel = balanceViewModelFactory.createBalanceInputViewModel(inputAmount)
            .value(for: selectedLocale)
        view?.didReceiveInput(viewModel: inputViewModel)
    }

    private func provideInputViewModelIfRate() {
        guard case .rate = inputResult else {
            return
        }

        provideInputViewModel()
    }

    private func provideCrowdloanContributionViewModel() {
        guard let crowdloan = crowdloan, let metadata = crowdloanMetadata else {
            return
        }

        let viewModel = contributionViewModelFactory.createContributionSetupViewModel(
            from: crowdloan,
            displayInfo: displayInfo,
            metadata: metadata,
            locale: selectedLocale
        )

        view?.didReceiveCrowdloan(viewModel: viewModel)
    }

    private func provideEstimatedRewardViewModel() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee) ?? 0
        let viewModel = displayInfo.map {
            contributionViewModelFactory.createEstimatedRewardViewModel(
                inputAmount: inputAmount,
                displayInfo: $0,
                locale: selectedLocale
            )
        } ?? nil

        view?.didReceiveEstimatedReward(viewModel: viewModel)
    }

    func provideBonusViewModel() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee) ?? 0
        let viewModel: String? = {
            if
                let displayInfo = displayInfo,
                let flowString = displayInfo.customFlow,
                let flow = CrowdloanFlow(rawValue: flowString),
                flow.supportsAdditionalBonus {
                return contributionViewModelFactory.createAdditionalBonusViewModel(
                    inputAmount: inputAmount,
                    displayInfo: displayInfo,
                    bonusRate: bonusService?.bonusRate,
                    locale: selectedLocale
                )
            } else {
                return nil
            }
        }()

        view?.didReceiveBonus(viewModel: viewModel)
    }

    private func provideRewardDestinationViewModel() {
        guard
            let bonusService = bonusService,
            let address = bonusService.rewardDestinationAddress,
            let displayInfo = displayInfo
        else { return }

        let viewModel = contributionViewModelFactory.createRewardDestinationViewModel(
            from: displayInfo,
            address: address,
            locale: selectedLocale
        )

        view?.didReceiveRewardDestination(viewModel: viewModel)
    }

    private func provideViewModels() {
        provideAssetVewModel()
        provideFeeViewModel()
        provideInputViewModel()
        provideCrowdloanContributionViewModel()
        provideEstimatedRewardViewModel()
        provideBonusViewModel()
        provideRewardDestinationViewModel()
    }

    private func refreshFee() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee) ?? 0
        guard let amount = inputAmount.toSubstrateAmount(precision: assetInfo.assetPrecision) else {
            return
        }

        interactor.estimateFee(for: amount, bonusService: bonusService)
    }

    private func applyDefaultReferralCode() {
        guard
            let bonusService = bonusService,
            let defaultReferralCode = bonusService.defaultReferralCode
        else { return }
        view?.didStartLoading()

        bonusService.save(referralCode: defaultReferralCode) { [weak self] result in
            guard let self = self else { return }
            self.view?.didStopLoading()

            switch result {
            case .success:
                self.proceed()
            case let .failure(error):
                _ = self.wireframe.present(error: error, from: self.view, locale: self.selectedLocale)
            }
        }
    }
}

extension CrowdloanContributionSetupPresenter: CrowdloanContributionSetupPresenterProtocol {
    func setup() {
        provideViewModels()

        interactor.setup()

        refreshFee()
    }

    func selectAmountPercentage(_ percentage: Float) {
        inputResult = .rate(Decimal(Double(percentage)))

        provideInputViewModel()

        refreshFee()
        provideAssetVewModel()
        provideEstimatedRewardViewModel()
        provideBonusViewModel()
    }

    func updateAmount(_ newValue: Decimal) {
        inputResult = .absolute(newValue)

        refreshFee()
        provideAssetVewModel()
        provideEstimatedRewardViewModel()
        provideBonusViewModel()
    }

    func proceed() {
        let contributionDecimal = inputResult?.absoluteValue(from: balanceMinusFee)
        let controbutionValue = contributionDecimal?.toSubstrateAmount(precision: assetInfo.assetPrecision)
        let spendingValue = (controbutionValue ?? 0) +
            (fee?.toSubstrateAmount(precision: assetInfo.assetPrecision) ?? 0)

        DataValidationRunner(validators: [
            dataValidatingFactory.crowdloanIsNotPrivate(
                crowdloan: crowdloan,
                displayInfo: displayInfo,
                locale: selectedLocale
            ),

            dataValidatingFactory.has(fee: fee, locale: selectedLocale, onError: { [weak self] in
                self?.refreshFee()
            }),

            dataValidatingFactory.canPayFeeAndAmount(
                balance: balance,
                fee: fee,
                spendingAmount: contributionDecimal,
                locale: selectedLocale
            ),

            dataValidatingFactory.contributesAtLeastMinContribution(
                contribution: controbutionValue,
                minimumBalance: minimumContribution,
                locale: selectedLocale
            ),

            dataValidatingFactory.capNotExceeding(
                contribution: controbutionValue,
                raised: crowdloan?.fundInfo.raised,
                cap: crowdloan?.fundInfo.cap,
                locale: selectedLocale
            ),

            dataValidatingFactory.crowdloanIsNotCompleted(
                crowdloan: crowdloan,
                metadata: crowdloanMetadata,
                locale: selectedLocale
            ),

            dataValidatingFactory.exsitentialDepositIsNotViolated(
                spendingAmount: spendingValue,
                totalAmount: totalBalanceValue,
                minimumBalance: minimumBalance,
                locale: selectedLocale
            ),

            dataValidatingFactory.hasAppliedReferralCode(
                bonusService: bonusService,
                locale: selectedLocale
            ) { [weak self] apply in
                if apply {
                    self?.applyDefaultReferralCode()
                }
            }
        ]).runValidation { [weak self] in
            guard let strongSelf = self, let contribution = contributionDecimal,
                  let paraId = strongSelf.crowdloan?.paraId else { return }
            strongSelf.wireframe.showConfirmation(
                from: strongSelf.view,
                paraId: paraId,
                inputAmount: contribution,
                bonusService: strongSelf.bonusService
            )
        }
    }

    func presentLearnMore() {
        guard let displayInfo = displayInfo, let url = URL(string: displayInfo.website), let view = view else {
            return
        }

        wireframe.showWeb(url: url, from: view, style: .automatic)
    }

    func presentAdditionalBonuses() {
        guard
            let displayInfo = displayInfo else {
            return
        }

        let contributionDecimal = inputResult?.absoluteValue(from: balanceMinusFee) ?? 0

        wireframe.showAdditionalBonus(
            from: view,
            for: displayInfo,
            inputAmount: contributionDecimal,
            delegate: self,
            existingService: bonusService
        )
    }

    func presentRewardDestination() {
        guard
            let view = view,
            let bonusService = bonusService,
            let address = bonusService.rewardDestinationAddress
        else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            explorers: explorers,
            locale: selectedLocale
        )
    }
}

extension CrowdloanContributionSetupPresenter: CrowdloanContributionSetupInteractorOutputProtocol {
    func didReceiveCrowdloan(result: Result<Crowdloan, Error>) {
        switch result {
        case let .success(crowdloan):
            self.crowdloan = crowdloan

            provideCrowdloanContributionViewModel()
        case let .failure(error):
            logger?.error("Did receive crowdloan error: \(error)")
        }
    }

    func didReceiveDisplayInfo(result: Result<CrowdloanDisplayInfo?, Error>) {
        switch result {
        case let .success(displayInfo):
            self.displayInfo = displayInfo

            provideCrowdloanContributionViewModel()
            provideEstimatedRewardViewModel()
            provideBonusViewModel()
            provideRewardDestinationViewModel()
        case let .failure(error):
            logger?.error("Did receive display info error: \(error)")
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            totalBalanceValue = accountInfo?.data.total ?? 0

            balance = accountInfo.map {
                Decimal.fromSubstrateAmount($0.data.available, precision: assetInfo.assetPrecision)
            } ?? 0.0

            provideAssetVewModel()
            provideCrowdloanContributionViewModel()
        case let .failure(error):
            logger?.error("Did receive account info error: \(error)")
        }
    }

    func didReceiveBlockNumber(result: Result<BlockNumber?, Error>) {
        switch result {
        case let .success(blockNumber):
            self.blockNumber = blockNumber

            provideCrowdloanContributionViewModel()
        case let .failure(error):
            logger?.error("Did receive block number error: \(error)")
        }
    }

    func didReceiveBlockDuration(result: Result<BlockTime, Error>) {
        switch result {
        case let .success(blockDuration):
            self.blockDuration = blockDuration

            provideCrowdloanContributionViewModel()
        case let .failure(error):
            logger?.error("Did receive block duration error: \(error)")
        }
    }

    func didReceiveLeasingPeriod(result: Result<LeasingPeriod, Error>) {
        switch result {
        case let .success(leasingPeriod):
            self.leasingPeriod = leasingPeriod

            provideCrowdloanContributionViewModel()
        case let .failure(error):
            logger?.error("Did receive leasing period error: \(error)")
        }
    }

    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData

            provideAssetVewModel()
            provideFeeViewModel()
        case let .failure(error):
            logger?.error("Did receive price error: \(error)")
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            fee = BigUInt(dispatchInfo.fee).map {
                Decimal.fromSubstrateAmount($0, precision: assetInfo.assetPrecision)
            } ?? nil

            provideFeeViewModel()
            provideInputViewModelIfRate()
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    func didReceiveMinimumBalance(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(minimumBalance):
            self.minimumBalance = minimumBalance

            provideAssetVewModel()
        case let .failure(error):
            logger?.error("Did receive minimum balance error: \(error)")
        }
    }

    func didReceiveMinimumContribution(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(minimumContribution):
            self.minimumContribution = minimumContribution

            provideAssetVewModel()
        case let .failure(error):
            logger?.error("Did receive minimum contribution error: \(error)")
        }
    }
}

extension CrowdloanContributionSetupPresenter: CustomCrowdloanDelegate {
    func didReceive(bonusService: CrowdloanBonusServiceProtocol) {
        self.bonusService = bonusService
        provideBonusViewModel()
        refreshFee()
    }
}

extension CrowdloanContributionSetupPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModels()
        }
    }
}
