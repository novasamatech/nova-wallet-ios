import Foundation
import SoraFoundation
import SubstrateSdk
import BigInt

final class ParaStkSelectCollatorsPresenter {
    weak var view: ParaStkSelectCollatorsViewProtocol?
    weak var delegate: ParaStkSelectCollatorsDelegate?
    let wireframe: ParaStkSelectCollatorsWireframeProtocol
    let interactor: ParaStkSelectCollatorsInteractorInputProtocol

    private var allCollators: [CollatorSelectionInfo]?
    private var collatorsPref: PreferredValidatorsProviderModel?
    private var price: PriceData?

    private var sorting: CollatorsSortType = .rewards

    private lazy var iconGenerator = PolkadotIconGenerator()
    private lazy var percentFormatter = NumberFormatter.percentSingle.localizableResource()
    private lazy var quantityFormatter = NumberFormatter.quantity.localizableResource()

    let chainAsset: ChainAsset
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let logger: LoggerProtocol

    init(
        interactor: ParaStkSelectCollatorsInteractorInputProtocol,
        wireframe: ParaStkSelectCollatorsWireframeProtocol,
        delegate: ParaStkSelectCollatorsDelegate,
        chainAsset: ChainAsset,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.delegate = delegate
        self.chainAsset = chainAsset
        self.balanceViewModelFactory = balanceViewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func createHeaderViewModel(for collatorsCount: Int) -> TitleWithSubtitleViewModel {
        let countString = quantityFormatter.value(for: selectedLocale).string(
            from: NSNumber(value: collatorsCount)
        )

        let languages = selectedLocale.rLanguages

        let title = R.string.localizable.commonParastkCollatorsCount(
            countString ?? "",
            preferredLanguages: languages
        )

        let subtitle: String

        switch sorting {
        case .rewards:
            subtitle = R.string.localizable.stakingRewardsTitle(preferredLanguages: languages)
        case .minStake:
            subtitle = R.string.localizable.stakingMainMinimumStakeTitle(preferredLanguages: languages)
        case .totalStake:
            subtitle = R.string.localizable.stakingValidatorTotalStake(preferredLanguages: languages)
        case .ownStake:
            subtitle = R.string.localizable.commonStakingOwnStake(preferredLanguages: languages)
        }

        return TitleWithSubtitleViewModel(title: title, subtitle: subtitle)
    }

    private func createBalanceViewModel(
        for amount: BigUInt
    ) -> BalanceViewModelProtocol {
        let decimalAmount = Decimal.fromSubstrateAmount(
            amount,
            precision: chainAsset.assetDisplayInfo.assetPrecision
        ) ?? 0

        return balanceViewModelFactory.balanceFromPrice(
            decimalAmount,
            priceData: price
        ).value(for: selectedLocale)
    }

    private func createDetailsViewModel(
        for amount: BigUInt
    ) -> TitleWithSubtitleViewModel {
        let decimalAmount = Decimal.fromSubstrateAmount(
            amount,
            precision: chainAsset.assetDisplayInfo.assetPrecision
        ) ?? 0

        let balanceViewModel = balanceViewModelFactory.balanceFromPrice(
            decimalAmount,
            priceData: price
        ).value(for: selectedLocale)

        return TitleWithSubtitleViewModel(
            title: balanceViewModel.amount,
            subtitle: balanceViewModel.price ?? ""
        )
    }

    private func createDetailsViewModel(
        for collatorInfo: CollatorSelectionInfo
    ) -> TitleWithSubtitleViewModel {
        let languages = selectedLocale.rLanguages

        switch sorting {
        case .rewards:
            let title = R.string.localizable.commonMinStakeColumn(preferredLanguages: languages)
            let amount = createBalanceViewModel(for: collatorInfo.minRewardableStake).amount

            return TitleWithSubtitleViewModel(
                title: title,
                subtitle: amount
            )
        case .minStake, .ownStake, .totalStake:
            let title = R.string.localizable.commonRewardsColumn(preferredLanguages: languages)

            let rewards = collatorInfo.apr.flatMap {
                percentFormatter.value(for: selectedLocale).stringFromDecimal($0)
            } ?? ""

            return TitleWithSubtitleViewModel(title: title, subtitle: rewards)
        }
    }

    private func createSortedByViewModel(
        for collatorInfo: CollatorSelectionInfo
    ) -> TitleWithSubtitleViewModel {
        switch sorting {
        case .rewards:
            let rewards = collatorInfo.apr.flatMap {
                percentFormatter.value(for: selectedLocale).stringFromDecimal($0)
            } ?? ""

            return TitleWithSubtitleViewModel(title: rewards)
        case .minStake:
            return createDetailsViewModel(for: collatorInfo.minRewardableStake)
        case .totalStake:
            return createDetailsViewModel(for: collatorInfo.totalStake)
        case .ownStake:
            return createDetailsViewModel(for: collatorInfo.ownStake)
        }
    }

    private func createViewModel(
        for collatorInfo: CollatorSelectionInfo
    ) throws -> CollatorSelectionViewModel {
        let address = try collatorInfo.accountId.toAddress(using: chainAsset.chain.chainFormat)
        let iconViewModel = try iconGenerator.generateFromAccountId(collatorInfo.accountId)
        let titleViewModel = DisplayAddressViewModel(
            address: address,
            name: collatorInfo.identity?.displayName,
            imageViewModel: nil
        )

        let detailsViewModel = createDetailsViewModel(for: collatorInfo)
        let sortedByViewModel = createSortedByViewModel(for: collatorInfo)

        return CollatorSelectionViewModel(
            iconViewModel: iconViewModel,
            collator: titleViewModel,
            detailsName: detailsViewModel.title,
            details: detailsViewModel.subtitle,
            sortedByTitle: sortedByViewModel.title,
            sortedByDetails: sortedByViewModel.subtitle,
            hasWarning: false
        )
    }

    private func provideState() {
        do {
            guard let allCollators else {
                view?.didReceive(state: .loading)
                return
            }

            let collatorsViewModels = try allCollators.map { try createViewModel(for: $0) }

            let headerViewModel = createHeaderViewModel(for: collatorsViewModels.count)

            let filtersApplied = sorting != CollatorsSortType.defaultType

            let viewModel = CollatorSelectionScreenViewModel(
                collators: collatorsViewModels,
                sorting: sorting,
                header: headerViewModel,
                filtersApplied: filtersApplied
            )

            view?.didReceive(state: .loaded(viewModel: viewModel))
        } catch {
            let errorDescription = R.string.localizable.commonErrorNoDataRetrieved(
                preferredLanguages: selectedLocale.rLanguages
            )

            view?.didReceive(state: .error(errorDescription))

            logger.error("Unexpected error: \(error)")
        }
    }

    private func applySortingAndSaveResult(_ result: [CollatorSelectionInfo]) {
        let preferredCollators = collatorsPref?.preferred ?? []
        allCollators = result.sortedByType(sorting, preferredCollators: Set(preferredCollators))
    }
}

extension ParaStkSelectCollatorsPresenter: ParaStkSelectCollatorsPresenterProtocol {
    func setup() {
        provideState()

        interactor.setup()
    }

    func refresh() {
        allCollators = nil
        collatorsPref = nil

        provideState()

        interactor.refresh()
    }

    func selectCollator(at index: Int) {
        guard let collator = allCollators?[index] else {
            return
        }

        delegate?.didSelect(collator: collator)

        wireframe.close(view: view)
    }

    func presentCollator(at index: Int) {
        guard let collator = allCollators?[index] else {
            return
        }

        wireframe.showCollatorInfo(from: view, collatorInfo: collator)
    }

    func presentSearch() {
        guard let allCollators, let delegate else {
            return
        }

        wireframe.showSearch(from: view, for: allCollators, delegate: delegate)
    }

    func presenterFilters() {
        wireframe.showFilters(from: view, for: sorting, delegate: self)
    }

    func clearFilters() {
        sorting = CollatorsSortType.defaultType

        if let allCollators {
            applySortingAndSaveResult(allCollators)
        }

        provideState()
    }
}

extension ParaStkSelectCollatorsPresenter: ParaStkSelectCollatorsInteractorOutputProtocol {
    func didReceiveAllCollators(_ collators: [CollatorSelectionInfo]) {
        logger.debug("All collators: \(collators)")

        applySortingAndSaveResult(collators)

        provideState()
    }

    func didReceiveCollatorsPref(_ collatorsPref: PreferredValidatorsProviderModel?) {
        logger.debug("Preferred collators: \(String(describing: collatorsPref))")

        self.collatorsPref = collatorsPref

        if let allCollators {
            applySortingAndSaveResult(allCollators)
        }

        provideState()
    }

    func didReceivePrice(_ priceData: PriceData?) {
        logger.debug("Price: \(String(describing: priceData))")

        price = priceData

        provideState()
    }

    func didReceiveError(_ error: ParaStkSelectCollatorsInteractorError) {
        logger.error("Error: \(error)")

        switch error {
        case .allCollatorsFailed, .preferredCollatorsFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refresh()
            }
        case .priceFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.retrySubscription()
            }
        }
    }
}

extension ParaStkSelectCollatorsPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideState()
        }
    }
}

extension ParaStkSelectCollatorsPresenter: ParaStkCollatorFiltersDelegate {
    func didReceiveCollator(sorting: CollatorsSortType) {
        self.sorting = sorting

        if let allCollators {
            applySortingAndSaveResult(allCollators)
        }

        provideState()
    }
}
