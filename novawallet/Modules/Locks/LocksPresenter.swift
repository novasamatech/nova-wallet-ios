import Foundation
import BigInt
import SoraFoundation

final class LocksPresenter {
    weak var view: LocksViewProtocol?
    let wireframe: LocksWireframeProtocol
    let input: LocksViewInput
    let priceViewModelFactory: PriceViewModelFactoryProtocol

    init(
        input: LocksViewInput,
        wireframe: LocksWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        priceViewModelFactory: PriceViewModelFactoryProtocol
    ) {
        self.input = input
        self.wireframe = wireframe
        self.priceViewModelFactory = priceViewModelFactory
        self.localizationManager = localizationManager
    }

    private func updateView() {
        let balanceModel = priceViewModelFactory.formatBalance(
            balances: input.balances,
            chains: input.chains,
            prices: input.prices,
            locale: selectedLocale
        )

        view?.update(header: "Total balance: \(balanceModel.total)")
        view?.update(viewModel: [
            createTranferrableSection(balanceModel: balanceModel),
            createLocksSection(balanceModel: balanceModel)
        ])
    }

    private func createTranferrableSection(balanceModel: FormattedBalance) -> LocksViewSectionModel {
        LocksViewSectionModel(
            header: .init(
                icon: R.image.iconActionChange(),
                title: "Transferrable",
                details: "%",
                value: "\(balanceModel.transferrable)"
            ),
            cells: []
        )
    }

    private func createLocksSection(balanceModel: FormattedBalance) -> LocksViewSectionModel {
        let locksCells = createLocksCells().sorted {
            $0.value.compare($1.value, options: .numeric) == .orderedDescending
        }

        return LocksViewSectionModel(
            header: .init(
                icon: R.image.iconLock(),
                title: "Locks",
                details: "%",
                value: balanceModel.locks
            ),
            cells: locksCells
        )
    }

    private func createLocksCells() -> [LocksViewSectionModel.CellViewModel] {
        let locksCells: [LocksViewSectionModel.CellViewModel] = input.locks.compactMap {
            createCell(
                amountInPlank: $0.amount,
                chainAssetId: $0.chainAssetId,
                type: String(data: $0.type, encoding: .utf8) ?? "",
                identifier: $0.identifier
            )
        }

        let reservedCells: [LocksViewSectionModel.CellViewModel] = input.balances.compactMap {
            createCell(
                amountInPlank: $0.reservedInPlank,
                chainAssetId: $0.chainAssetId,
                type: "reserved",
                identifier: $0.identifier
            )
        }

        return locksCells + reservedCells
    }

    private func createCell(
        amountInPlank: BigUInt,
        chainAssetId: ChainAssetId,
        type: String,
        identifier: String
    ) -> LocksViewSectionModel.CellViewModel? {
        guard let chain = input.chains[chainAssetId.chainId] else {
            return nil
        }
        guard let asset = chain.asset(for: chainAssetId.assetId) else {
            return nil
        }
        let title = [asset.symbol, type].joined(separator: " ")

        guard let value = priceViewModelFactory.formatPlankValue(
            plank: amountInPlank,
            chainAssetId: chainAssetId,
            chains: input.chains,
            prices: input.prices,
            locale: selectedLocale
        ) else {
            return nil
        }

        return LocksViewSectionModel.CellViewModel(
            id: identifier,
            title: title,
            value: value
        )
    }

    var contentHeight: CGFloat {
        let reservedCellsCount = input.balances.filter { $0.reservedInPlank > 0 }.count
        return view?.calculateEstimatedHeight(sections: 2, items: input.locks.count + reservedCellsCount) ?? 0
    }
}

extension LocksPresenter: LocksPresenterProtocol {
    func setup() {
        updateView()
    }
}

extension LocksPresenter: Localizable {
    func applyLocalization() {
        updateView()
    }
}
