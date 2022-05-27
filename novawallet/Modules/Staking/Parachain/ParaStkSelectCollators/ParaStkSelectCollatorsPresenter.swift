import Foundation
import SoraFoundation
import SubstrateSdk
import BigInt

final class ParaStkSelectCollatorsPresenter {
    weak var view: ParaStkSelectCollatorsViewProtocol?
    let wireframe: ParaStkSelectCollatorsWireframeProtocol
    let interactor: ParaStkSelectCollatorsInteractorInputProtocol

    private var collatorsInfo: [CollatorSelectionInfo]?
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
        chainAsset: ChainAsset,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
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
            subtitle = R.string.localizable.parachainStakingMinimumStake(preferredLanguages: languages)
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
            let amount = createBalanceViewModel(for: collatorInfo.minStake).amount

            return TitleWithSubtitleViewModel(
                title: title,
                subtitle: amount
            )
        case .minStake, .ownStake, .totalStake:
            let title = R.string.localizable.commonRewardsColumn(preferredLanguages: languages)

            let rewards = percentFormatter.value(
                for: selectedLocale
            ).stringFromDecimal(collatorInfo.apr)

            return TitleWithSubtitleViewModel(title: title, subtitle: rewards ?? "")
        }
    }

    private func createSortedByViewModel(
        for collatorInfo: CollatorSelectionInfo
    ) -> TitleWithSubtitleViewModel {
        switch sorting {
        case .rewards:
            let rewardsString = percentFormatter.value(
                for: selectedLocale
            ).stringFromDecimal(collatorInfo.apr)

            return TitleWithSubtitleViewModel(title: rewardsString ?? "")
        case .minStake:
            return createDetailsViewModel(for: collatorInfo.minStake)
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
            sortedByDetails: sortedByViewModel.subtitle
        )
    }

    private func provideViewModel() {
        do {
            guard let collatorsInfo = collatorsInfo else {
                return
            }

            let collatorsViewModels = try collatorsInfo.sortedByType(sorting).map { collatorInfo in
                try createViewModel(for: collatorInfo)
            }

            let headerViewModel = createHeaderViewModel(for: collatorsViewModels.count)

            let viewModel = CollatorSelectionScreenViewModel(
                collators: collatorsViewModels,
                sorting: sorting,
                header: headerViewModel
            )

            view?.didReceive(viewModel: viewModel)
        } catch {
            _ = wireframe.present(error: error, from: view, locale: selectedLocale)
            logger.error("Unexpected error: \(error)")
        }
    }
}

extension ParaStkSelectCollatorsPresenter: ParaStkSelectCollatorsPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func presentCollatorInfo(at _: Int) {}

    func presentSearch() {}

    func presenterFilters() {}

    func clearFilters() {
        sorting = CollatorsSortType.defaultType
        provideViewModel()
    }
}

extension ParaStkSelectCollatorsPresenter: ParaStkSelectCollatorsInteractorOutputProtocol {
    func didReceiveCollators(result: Result<[CollatorSelectionInfo], Error>) {
        switch result {
        case let .success(info):
            collatorsInfo = info

            provideViewModel()
        case let .failure(error):
            _ = wireframe.present(error: error, from: view, locale: selectedLocale)

            logger.error("Did receive error: \(error)")
        }
    }
}

extension ParaStkSelectCollatorsPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModel()
        }
    }
}
