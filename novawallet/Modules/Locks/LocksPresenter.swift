import Foundation
import BigInt
import SoraFoundation

final class LocksPresenter {
    weak var view: LocksViewProtocol?
    let wireframe: LocksWireframeProtocol
    let input: LocksViewInput
    let priceViewModelFactory: PriceViewModelFactoryProtocol
    lazy var transferrableFormatter: NumberFormatter = {
        let formatter = NumberFormatter.percent
        formatter.roundingMode = .up
        return formatter
    }()

    lazy var locksFormatter = NumberFormatter.percent

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

        let header = R.string.localizable.walletSendBalanceTotal(
            preferredLanguages: selectedLocale.rLanguages
        )

        view?.updateHeader(title: header, value: balanceModel.total)
        view?.update(viewModel: [
            createTranferrableSection(balanceModel: balanceModel),
            createLocksSection(balanceModel: balanceModel)
        ])
    }

    private func createTranferrableSection(balanceModel: FormattedBalance) -> LocksViewSectionModel {
        let percent = balanceModel.totalPrice > 0 ?
            balanceModel.transferrablePrice / balanceModel.totalPrice : 0
        let displayPercent = transferrableFormatter.stringFromDecimal(percent) ?? ""
        return LocksViewSectionModel(
            header: .init(
                icon: R.image.iconTransferable(),
                title: R.string.localizable.walletBalanceAvailable(
                    preferredLanguages: selectedLocale.rLanguages
                ),
                details: displayPercent,
                value: balanceModel.transferrable
            ),
            cells: []
        )
    }

    private func createLocksSection(balanceModel: FormattedBalance) -> LocksViewSectionModel {
        let percent = balanceModel.totalPrice > 0 ?
            balanceModel.locksPrice / balanceModel.totalPrice : 0
        let displayPercent = locksFormatter.stringFromDecimal(percent) ?? ""
        let locksCells = createLocksCells().sorted {
            $0.value.compare($1.value, options: .numeric) == .orderedDescending
        }

        return LocksViewSectionModel(
            header: .init(
                icon: R.image.iconBrowserSecurity(),
                title: R.string.localizable.walletBalanceLocked(
                    preferredLanguages: selectedLocale.rLanguages
                ),
                details: displayPercent,
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
                title: $0.lockType.map { $0.displayType.value(for: selectedLocale) } ??
                    String(data: $0.type, encoding: .utf8)?.capitalized ?? "",
                identifier: $0.identifier
            )
        }

        let reservedCells: [LocksViewSectionModel.CellViewModel] = input.balances.compactMap {
            createCell(
                amountInPlank: $0.reservedInPlank,
                chainAssetId: $0.chainAssetId,
                title: R.string.localizable.walletBalanceReserved(
                    preferredLanguages: selectedLocale.rLanguages
                ),
                identifier: $0.identifier
            )
        }

        return locksCells + reservedCells
    }

    private func createCell(
        amountInPlank: BigUInt,
        chainAssetId: ChainAssetId,
        title: String,
        identifier: String
    ) -> LocksViewSectionModel.CellViewModel? {
        guard let chain = input.chains[chainAssetId.chainId] else {
            return nil
        }
        guard let asset = chain.asset(for: chainAssetId.assetId) else {
            return nil
        }
        let title = [asset.symbol, title].joined(separator: " ")

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
            value: value.amount
        )
    }

    var contentHeight: CGFloat {
        let reservedCellsCount = input.balances.filter {
            $0.reservedInPlank > 0 && input.prices[$0.chainAssetId] != nil
        }.count
        let locksCount = input.locks.filter {
            $0.amount > 0 && input.prices[$0.chainAssetId] != nil
        }.count
        return view?.calculateEstimatedHeight(sections: 2, items: locksCount + reservedCellsCount) ?? 0
    }
}

extension LocksPresenter: LocksPresenterProtocol {
    func setup() {
        updateView()
    }

    func didTapOnCell() {
        wireframe.close(view: view)
    }
}

extension LocksPresenter: Localizable {
    func applyLocalization() {
        guard view?.isSetup == true else {
            return
        }
        updateView()
    }
}
