import Foundation
import BigInt

final class LocksPresenter {
    weak var view: LocksViewProtocol?
    let wireframe: LocksWireframeProtocol
    let input: LocksViewInput

    init(
        input: LocksViewInput,
        wireframe: LocksWireframeProtocol
    ) {
        self.input = input
        self.wireframe = wireframe
    }

    private func updateView() {
        view?.update(header: "Total balance")
        view?.update(viewModel: [
            createTransferrableSection(),
            createLocksSection()
        ])
    }

    func createTransferrableSection() -> LocksViewSectionModel {
        var transferrableValue: BigUInt = 0
        var lockValue: BigUInt = 0

        for balance in input.balances {
            transferrableValue += balance.transferable
            lockValue += balance.frozenInPlank
        }

        return .init(
            header: .init(
                icon: R.image.iconActionChange(),
                title: "Transferrable",
                details: "%",
                value: "\(transferrableValue)"
            ),
            cells: []
        )
    }

    func createLocksSection() -> LocksViewSectionModel {
        var transferrableValue: BigUInt = 0
        var lockValue: BigUInt = 0

        for balance in input.balances {
            transferrableValue += balance.transferable
            lockValue += balance.frozenInPlank
        }

        let cells: [LocksViewSectionModel.CellViewModel] = input.locks.compactMap {
            guard let chain = input.chains[$0.chainAssetId.chainId] else {
                return nil
            }
            guard let asset = chain.asset(for: $0.chainAssetId.assetId) else {
                return nil
            }
            let lockType = String(data: $0.type, encoding: .utf8) ?? ""
            let title = [asset.symbol, lockType].joined(separator: " ")
            return LocksViewSectionModel.CellViewModel(
                title: title,
                value: "\($0.amount)"
            )
        }

        return .init(
            header: .init(
                icon: R.image.iconLock(),
                title: "Locks",
                details: "%",
                value: "\(lockValue)"
            ),
            cells: cells
        )
    }

    var contentHeight: CGFloat {
        view?.calculateEstimatedHeight(sections: 1, items: input.locks.count) ?? 0
    }
}

extension LocksPresenter: LocksPresenterProtocol {
    func setup() {
        updateView()
    }
}
