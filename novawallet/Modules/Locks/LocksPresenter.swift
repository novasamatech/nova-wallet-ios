import Foundation
import BigInt
import Foundation_iOS

final class LocksPresenter {
    weak var view: LocksViewProtocol?
    let wireframe: LocksWireframeProtocol
    let input: LocksViewInput
    let priceViewModelFactory: LocksBalanceViewModelFactoryProtocol
    lazy var formatter: NumberFormatter = {
        let formatter = NumberFormatter.percent
        formatter.roundingMode = .halfEven
        return formatter
    }()

    init(
        input: LocksViewInput,
        wireframe: LocksWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        priceViewModelFactory: LocksBalanceViewModelFactoryProtocol
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
            externalBalances: input.externalBalances,
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
        let displayPercent = formatter.stringFromDecimal(percent) ?? ""
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
        let displayPercent = formatter.stringFromDecimal(percent) ?? ""
        let locksCells = createLocksCells().sorted {
            $0.priceValue > $1.priceValue
        }

        return LocksViewSectionModel(
            header: .init(
                icon: R.image.iconLock(),
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
        let locksCells: [LocksViewSectionModel.CellViewModel] = input.locks.compactMap { lock in
            let optTitle = lock.lockType.map { $0.displayType.value(for: selectedLocale) } ??
                lock.displayModuleAndIdTitle

            return createCell(
                amountInPlank: lock.amount,
                chainAssetId: lock.chainAssetId,
                title: optTitle ?? "",
                identifier: lock.identifier
            )
        }

        let holdsCells = createHoldReserves()

        let reservedCells = createNonHoldReserves()

        let groupedExternalBalances = input.externalBalances
            .values.flatMap { $0.filter { $0.amount > 0 } }
            .groupByAssetType()

        let externalBalanceCells: [LocksViewSectionModel.CellViewModel] = groupedExternalBalances.compactMap {
            let group = $0.key
            let amount = $0.value

            return createCell(
                amountInPlank: amount,
                chainAssetId: group.chainAssetId,
                title: group.type.lockTitle.value(for: selectedLocale),
                identifier: group.stringValue
            )
        }

        return locksCells + holdsCells + reservedCells + externalBalanceCells
    }

    private func createNonHoldReserves() -> [LocksViewSectionModel.CellViewModel] {
        input.balances.compactMap { balance in
            let totalHolds = input.holds
                .filter { $0.chainAssetId == balance.chainAssetId }
                .reduce(BigUInt(0)) { $0 + $1.amount }

            let reservesNotInHolds = balance.reservedInPlank.subtractOrZero(totalHolds)

            return createCell(
                amountInPlank: reservesNotInHolds,
                chainAssetId: balance.chainAssetId,
                title: R.string.localizable.walletBalanceReserved(
                    preferredLanguages: selectedLocale.rLanguages
                ),
                identifier: balance.identifier
            )
        }
    }

    private func createHoldReserves() -> [LocksViewSectionModel.CellViewModel] {
        input.holds.compactMap { hold in
            createCell(
                amountInPlank: hold.amount,
                chainAssetId: hold.chainAssetId,
                title: hold.displayTitle(for: selectedLocale),
                identifier: hold.identifier
            )
        }
    }

    private func createCell(
        amountInPlank: BigUInt,
        chainAssetId: ChainAssetId,
        title: String,
        identifier: String
    ) -> LocksViewSectionModel.CellViewModel? {
        guard amountInPlank > 0 else {
            return nil
        }
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
            amount: value.amount,
            price: value.price,
            priceValue: value.priceValue
        )
    }

    var contentHeight: CGFloat {
        let reservedCellsCount = input.balances.filter {
            $0.reservedInPlank > 0
        }.count
        let locksCellsCount = input.locks.filter {
            $0.amount > 0
        }.count

        let externalBalancesCellsCount = input.externalBalances
            .values.flatMap { $0.filter { $0.amount > 0 } }
            .count

        return view?.calculateEstimatedHeight(
            sections: 2,
            items: locksCellsCount + reservedCellsCount + externalBalancesCellsCount
        ) ?? 0
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
