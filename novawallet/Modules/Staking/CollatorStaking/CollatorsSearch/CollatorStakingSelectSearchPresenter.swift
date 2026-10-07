import Foundation
import BigInt
import SubstrateSdk
import Foundation_iOS

final class CollatorStakingSelectSearchPresenter {
    weak var view: CollatorStakingSelectSearchViewProtocol?
    let wireframe: CollatorStakingSelectSearchWireframeProtocol
    let interactor: CollatorStakingSelectSearchInteractorInputProtocol

    private lazy var iconGenerator = PolkadotIconGenerator()
    private lazy var percentFormatter = NumberFormatter.percentSingle.localizableResource()

    let chainAsset: ChainAsset
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let collatorsInfo: [CollatorStakingSelectionInfoProtocol]
    let logger: LoggerProtocol

    private var filteredCollatorsInfo: [CollatorStakingSelectionInfoProtocol]?

    weak var delegate: CollatorStakingSelectDelegate?

    init(
        interactor: CollatorStakingSelectSearchInteractorInputProtocol,
        wireframe: CollatorStakingSelectSearchWireframeProtocol,
        chainAsset: ChainAsset,
        collatorsInfo: [CollatorStakingSelectionInfoProtocol],
        delegate: CollatorStakingSelectDelegate,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.chainAsset = chainAsset
        self.interactor = interactor
        self.wireframe = wireframe
        self.delegate = delegate
        self.balanceViewModelFactory = balanceViewModelFactory
        self.collatorsInfo = collatorsInfo

        self.logger = logger

        self.localizationManager = localizationManager
    }

    private func createHeaderViewModel(for collatorsCount: Int) -> TitleWithSubtitleViewModel {
        let languages = selectedLocale.rLanguages

        let title = R.string(preferredLanguages: languages).localizable.commonSearchResultsNumber(collatorsCount)

        let subtitle = R.string(preferredLanguages: languages).localizable.stakingRewardsTitle()

        return TitleWithSubtitleViewModel(title: title, subtitle: subtitle)
    }

    private func createDetailsViewModel(
        for collatorInfo: CollatorStakingSelectionInfoProtocol
    ) -> TitleWithSubtitleViewModel {
        let languages = selectedLocale.rLanguages

        let title = R.string(preferredLanguages: languages).localizable.commonMinStakeColumn()

        let decimalAmount = Decimal.fromSubstrateAmount(
            collatorInfo.minRewardableStake,
            precision: chainAsset.assetDisplayInfo.assetPrecision
        ) ?? 0

        let amount = balanceViewModelFactory.amountFromValue(decimalAmount).value(for: selectedLocale)

        return TitleWithSubtitleViewModel(title: title, subtitle: amount)
    }

    private func createSortedByViewModel(
        for collatorInfo: CollatorStakingSelectionInfoProtocol
    ) -> TitleWithSubtitleViewModel {
        let rewards = collatorInfo.apr.flatMap {
            percentFormatter.value(for: selectedLocale).stringFromDecimal($0)
        } ?? ""

        return TitleWithSubtitleViewModel(title: rewards)
    }

    private func createCollatorViewModel(
        for collatorInfo: CollatorStakingSelectionInfoProtocol
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
            identifier: collatorInfo.accountId,
            iconViewModel: iconViewModel,
            collator: titleViewModel,
            detailsName: detailsViewModel.title,
            details: detailsViewModel.subtitle,
            sortedByTitle: sortedByViewModel.title,
            sortedByDetails: sortedByViewModel.subtitle,
            hasWarning: false
        )
    }

    private func provideViewModel() {
        do {
            guard let filteredCollatorsInfo = filteredCollatorsInfo else {
                view?.didReceive(viewModel: nil)
                return
            }

            let collatorViewModels = try filteredCollatorsInfo.map {
                try createCollatorViewModel(for: $0)
            }

            let headerViewModel = createHeaderViewModel(for: collatorViewModels.count)

            let viewModel = CollatorStakingSelectSearchViewModel(
                headerViewModel: headerViewModel,
                cellViewModels: collatorViewModels
            )

            view?.didReceive(viewModel: viewModel)
        } catch {
            logger.error("Unexpected error: \(error)")
        }
    }
}

extension CollatorStakingSelectSearchPresenter: CollatorStakingSelectSearchPresenterProtocol {
    func setup() {
        provideViewModel()
    }

    func selectCollator(at index: Int) {
        guard let filteredCollatorsInfo = filteredCollatorsInfo else {
            return
        }

        let collatorInfo = filteredCollatorsInfo[index]

        delegate?.didSelect(collator: collatorInfo)

        wireframe.complete(on: view)
    }

    func search(text: String) {
        if !text.isEmpty {
            let optAccountId = try? text.toAccountId()

            let filteredInfoList = collatorsInfo.filter { info in
                if
                    let displayName = info.identity?.displayName,
                    displayName.localizedCaseInsensitiveContains(text) {
                    return true
                }

                if optAccountId != nil {
                    return info.accountId == optAccountId
                } else {
                    return false
                }
            }
            .sorted { ($0.apr ?? 0) > ($1.apr ?? 0) }

            filteredCollatorsInfo = Array(filteredInfoList)
        } else {
            filteredCollatorsInfo = nil
        }

        provideViewModel()
    }

    func presentCollatorInfo(at index: Int) {
        guard let filteredCollatorsInfo = filteredCollatorsInfo else {
            return
        }

        let collatorInfo = filteredCollatorsInfo[index]

        wireframe.showCollatorInfo(from: view, collatorInfo: collatorInfo)
    }
}

extension CollatorStakingSelectSearchPresenter: CollatorStakingSelectSearchInteractorOutputProtocol {}

extension CollatorStakingSelectSearchPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModel()
        }
    }
}
