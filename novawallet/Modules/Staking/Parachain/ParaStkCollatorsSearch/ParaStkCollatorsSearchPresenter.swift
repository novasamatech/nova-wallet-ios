import Foundation
import BigInt
import SubstrateSdk
import SoraFoundation

final class ParaStkCollatorsSearchPresenter {
    weak var view: ParaStkCollatorsSearchViewProtocol?
    let wireframe: ParaStkCollatorsSearchWireframeProtocol
    let interactor: ParaStkCollatorsSearchInteractorInputProtocol

    private lazy var iconGenerator = PolkadotIconGenerator()
    private lazy var percentFormatter = NumberFormatter.percentSingle.localizableResource()

    let chainAsset: ChainAsset
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let collatorsInfo: [CollatorSelectionInfo]
    let logger: LoggerProtocol

    private var filteredCollatorsInfo: [CollatorSelectionInfo]?

    weak var delegate: ParaStkSelectCollatorsDelegate?

    init(
        interactor: ParaStkCollatorsSearchInteractorInputProtocol,
        wireframe: ParaStkCollatorsSearchWireframeProtocol,
        chainAsset: ChainAsset,
        collatorsInfo: [CollatorSelectionInfo],
        delegate: ParaStkSelectCollatorsDelegate,
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

        let title = R.string.localizable.commonSearchResultsNumber(
            collatorsCount,
            preferredLanguages: languages
        )

        let subtitle = R.string.localizable.stakingRewardsTitle(preferredLanguages: languages)

        return TitleWithSubtitleViewModel(title: title, subtitle: subtitle)
    }

    private func createDetailsViewModel(
        for collatorInfo: CollatorSelectionInfo
    ) -> TitleWithSubtitleViewModel {
        let languages = selectedLocale.rLanguages

        let title = R.string.localizable.commonMinStakeColumn(preferredLanguages: languages)

        let decimalAmount = Decimal.fromSubstrateAmount(
            collatorInfo.minRewardableStake,
            precision: chainAsset.assetDisplayInfo.assetPrecision
        ) ?? 0

        let amount = balanceViewModelFactory.amountFromValue(decimalAmount).value(for: selectedLocale)

        return TitleWithSubtitleViewModel(title: title, subtitle: amount)
    }

    private func createSortedByViewModel(
        for collatorInfo: CollatorSelectionInfo
    ) -> TitleWithSubtitleViewModel {
        let rewards = collatorInfo.apr.flatMap {
            percentFormatter.value(for: selectedLocale).stringFromDecimal($0)
        } ?? ""

        return TitleWithSubtitleViewModel(title: rewards)
    }

    private func createCollatorViewModel(
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
            guard let filteredCollatorsInfo = filteredCollatorsInfo else {
                view?.didReceive(viewModel: nil)
                return
            }

            let collatorViewModels = try filteredCollatorsInfo.map {
                try createCollatorViewModel(for: $0)
            }

            let headerViewModel = createHeaderViewModel(for: collatorViewModels.count)

            let viewModel = ParaStkCollatorsSearchViewModel(
                headerViewModel: headerViewModel,
                cellViewModels: collatorViewModels
            )

            view?.didReceive(viewModel: viewModel)
        } catch {
            logger.error("Unexpected error: \(error)")
        }
    }
}

extension ParaStkCollatorsSearchPresenter: ParaStkCollatorsSearchPresenterProtocol {
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

extension ParaStkCollatorsSearchPresenter: ParaStkCollatorsSearchInteractorOutputProtocol {}

extension ParaStkCollatorsSearchPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModel()
        }
    }
}
