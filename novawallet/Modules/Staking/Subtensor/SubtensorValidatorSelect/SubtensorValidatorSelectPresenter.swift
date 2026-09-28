import Foundation
import Foundation_iOS
import SubstrateSdk

final class SubtensorValidatorSelectPresenter {
    weak var view: SubtensorValidatorSelectViewProtocol?
    weak var delegate: SubtensorSubnetSelectDelegate?

    let target: SubtensorStakeTarget
    let chainAsset: ChainAsset
    let interactor: ValidatorSelectInteractorInputProtocol
    let wireframe: ValidatorSelectWireframeProtocol
    let localizationManager: LocalizationManagerProtocol
    let logger: LoggerProtocol

    private var directory: SubtensorValidatorDirectory?
    private var yields: SubtensorAlphaYields?
    private var rows: [SubtensorValidatorRowViewModel] = []
    private var selectedHotkey: AccountId?
    private var query = ""
    private var sort: SubtensorValidatorSort

    init(
        target: SubtensorStakeTarget,
        chainAsset: ChainAsset,
        interactor: ValidatorSelectInteractorInputProtocol,
        wireframe: ValidatorSelectWireframeProtocol,
        delegate: SubtensorSubnetSelectDelegate,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.target = target
        self.chainAsset = chainAsset
        self.interactor = interactor
        self.wireframe = wireframe
        self.delegate = delegate
        self.localizationManager = localizationManager
        self.logger = logger
        sort = target.isRoot ? .totalStaked : .apy
    }
}

private extension SubtensorValidatorSelectPresenter {
    var subnet: SubtensorSubnetRef? {
        SubtensorSubnetRef(netuid: target.netuid, registeredAt: target.subnetInfo?.networkRegisteredAt ?? 0)
    }

    func format(_ value: Decimal, digits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.locale = localizationManager.selectedLocale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = digits
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? value.description
    }

    func apy(for item: SubtensorValidatorDirectoryItem) -> String? {
        guard let raw = yields?.yields[item.hotkey]?.reportedRate,
              let value = Decimal(string: raw.replacingOccurrences(of: "%", with: "")) else { return nil }
        return "\(format(value))%"
    }

    func title(for item: SubtensorValidatorDirectoryItem) -> String {
        if let name = item.name, !name.isEmpty { return name }
        guard let address = try? item.hotkey.toAddress(using: chainAsset.chain.chainFormat) else { return "—" }
        return String(address.prefix(6)) + "…" + String(address.suffix(6))
    }

    func subtitle(for item: SubtensorValidatorDirectoryItem) -> String {
        let strings = R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages).localizable
        let alpha = item.hotkeyAlpha ?? 0
        let tao: Balance? = target.isRoot
            ? alpha
            : target.listedPrice.map { alpha * $0 / SubtensorStakingPallet.alphaPriceScale }
        let staked = tao.flatMap {
            Decimal.fromSubstrateAmount($0, precision: chainAsset.assetDisplayInfo.assetPrecision)
        }
        let take = item.take.map { format($0 * 100, digits: 1) }
        return strings.stakingSubtensorUiValidatorRowSubtitle(
            staked.map { format($0, digits: 0) } ?? "—",
            take ?? "—"
        )
    }

    func isOrderedBefore(_ left: SubtensorValidatorDirectoryItem, _ right: SubtensorValidatorDirectoryItem) -> Bool {
        if left.isNovaPreferred != right.isNovaPreferred { return left.isNovaPreferred }
        switch sort {
        case .apy:
            let leftApy = (yields?.yields[left.hotkey]).flatMap { Decimal(string: $0.reportedRate) } ?? 0
            let rightApy = (yields?.yields[right.hotkey]).flatMap { Decimal(string: $0.reportedRate) } ?? 0
            if leftApy != rightApy { return leftApy > rightApy }
        case .totalStaked:
            let leftStake = left.hotkeyAlpha ?? 0
            let rightStake = right.hotkeyAlpha ?? 0
            if leftStake != rightStake { return leftStake > rightStake }
        case .name: break
        }
        return title(for: left).localizedStandardCompare(title(for: right)) == .orderedAscending
    }

    func provideRows() {
        guard let directory else {
            view?.didReceive(rows: [], isLoading: true)
            view?.didReceive(selectionTitle: nil, isEnabled: false)
            return
        }
        let eligibleItems = directory.items.filter { !target.isRoot || $0.status != nil }
        let items = eligibleItems
            .filter { query.isEmpty || title(for: $0).localizedCaseInsensitiveContains(query) }
            .sorted(by: isOrderedBefore)
        rows = items.map { item in
            SubtensorValidatorRowViewModel(
                item: item,
                title: title(for: item),
                subtitle: subtitle(for: item),
                apy: apy(for: item),
                isSelected: item.hotkey == selectedHotkey
            )
        }
        view?.didReceive(rows: rows, isLoading: false)
        let selected = eligibleItems.first { $0.hotkey == selectedHotkey }
        let strings = R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages).localizable
        view?.didReceive(
            selectionTitle: selected.map { strings.stakingSubtensorUiValidatorSelectFormat(title(for: $0)) },
            isEnabled: selected != nil
        )
    }
}

extension SubtensorValidatorSelectPresenter: ValidatorSelectPresenterProtocol {
    func setup() {
        retry()
    }

    func retry() {
        guard let subnet else { return }
        directory = nil
        rows = []
        view?.didReceive(rows: [], isLoading: true)
        view?.didReceive(selectionTitle: nil, isEnabled: false)
        interactor.loadDirectory(for: subnet)
        if !target.isRoot {
            interactor.loadYields(for: subnet.netuid)
        }
    }

    func search(_ query: String) {
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        provideRows()
    }

    func selectSort(_ sort: SubtensorValidatorSort) {
        self.sort = sort
        provideRows()
    }

    func select(at index: Int) {
        guard rows.indices.contains(index) else { return }
        selectedHotkey = rows[index].item.hotkey
        provideRows()
    }

    func showInfo(at index: Int) {
        guard rows.indices.contains(index), let subnet else { return }
        interactor.loadDetail(for: rows[index].item, subnet: subnet)
    }

    func confirm() {
        guard let item = directory?.items.first(where: { $0.hotkey == selectedHotkey && (!target.isRoot || $0.status != nil) }) else {
            return
        }
        delegate?.didSelectValidator(item, for: target)
        wireframe.complete(from: view)
    }
}

extension SubtensorValidatorSelectPresenter: ValidatorSelectInteractorOutputProtocol {
    func didReceive(directory: SubtensorValidatorDirectory) {
        self.directory = directory
        if selectedHotkey == nil {
            selectedHotkey = directory.items.first(where: { $0.isNovaPreferred && (!target.isRoot || $0.status != nil) })?.hotkey
        }
        provideRows()
    }

    func didReceive(yields: SubtensorAlphaYields) {
        self.yields = yields
        if directory != nil { provideRows() }
    }

    func didReceive(detail: SubtensorValidatorDetail) {
        wireframe.showInfo(
            from: view,
            context: SubtensorValidatorInfoContext(
                detail: detail,
                apy: apy(for: detail.item),
                locale: localizationManager.selectedLocale,
                chainAsset: chainAsset,
                price: target.isRoot ? SubtensorStakingPallet.alphaPriceScale : target.listedPrice
            )
        )
    }

    func didFailDirectory(_ error: Error) {
        logger.warning("Subnet validators unavailable: \(error)")
        directory = nil
        rows = []
        view?.didReceive(rows: [], isLoading: false)
        view?.didFailDirectory()
        view?.didReceive(selectionTitle: nil, isEnabled: false)
    }
}

extension SubtensorValidatorSelectPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true { provideRows() }
    }
}
