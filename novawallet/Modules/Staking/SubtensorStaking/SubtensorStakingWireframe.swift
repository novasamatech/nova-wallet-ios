import UIKit
import Foundation_iOS

final class SubtensorStakingWireframe: SubtensorStakingWireframeProtocol {
    private let chainAsset: ChainAsset
    private let localizationManager: LocalizationManagerProtocol

    init(chainAsset: ChainAsset, localizationManager: LocalizationManagerProtocol) {
        self.chainAsset = chainAsset
        self.localizationManager = localizationManager
    }

    // MARK: - SubtensorStakingWireframeProtocol

    /// Routes to the Root / Subnet type-selection screen, then to Setup → Confirm.
    func showStakingFlow(from view: UIViewController) {
        let typeVC = SubtensorStakingTypeViewController(
            chainAsset: chainAsset,
            localizationManager: localizationManager
        ) { [weak self, weak view] selection in
            guard let self, let view else { return }
            switch selection {
            case .root:
                self.showRootSetup(from: view)
            case .subnet:
                self.showSubnetPicker(from: view)
            }
        }
        view.navigationController?.pushViewController(typeVC, animated: true)
    }

    func showUnstake(from view: UIViewController, positions: [SubtensorStakePosition]) {
        guard !positions.isEmpty else { return }

        if positions.count == 1 {
            pushUnstakeSetup(from: view, position: positions[0])
            return
        }

        let languages = localizationManager.selectedLocale.rLanguages
        let picker = UIAlertController(
            title: R.string(preferredLanguages: languages).localizable.stakingSubtensorUnstakeFrom(),
            message: nil,
            preferredStyle: .actionSheet
        )
        for position in positions {
            let address = (try? position.hotkey.toAddress(using: chainAsset.chain.chainFormat))
                ?? position.hotkey.toHex()
            let title = position.validatorIdentity ?? SubtensorValidatorCellViewModelFactory.shorten(address: address)
            picker.addAction(UIAlertAction(title: title, style: .default) { [weak self, weak view] _ in
                guard let self, let view else { return }
                self.pushUnstakeSetup(from: view, position: position)
            })
        }
        picker.addAction(UIAlertAction(
            title: R.string(preferredLanguages: languages).localizable.commonCancel(),
            style: .cancel
        ))
        // Action sheets crash on iPad without a popover anchor — point at
        // the presenting view's center so the sheet renders as a popover.
        if let popover = picker.popoverPresentationController {
            popover.sourceView = view.view
            popover.sourceRect = CGRect(
                x: view.view.bounds.midX,
                y: view.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        view.present(picker, animated: true)
    }

    private func pushUnstakeSetup(from view: UIViewController, position: SubtensorStakePosition) {
        // For subnet positions, look up the subnet alpha asset so amount units
        // render as alpha; for root, use the TAO chainAsset directly.
        let unstakeAsset: ChainAsset
        if position.netuid != SubtensorStakingConstants.rootNetuid {
            let subnetAssetId = SubtensorStakingConstants.subnetAssetIdBase
                + AssetModel.Id(position.netuid)
            if let alphaAsset = chainAsset.chain.assets.first(where: { $0.assetId == subnetAssetId }) {
                unstakeAsset = ChainAsset(chain: chainAsset.chain, asset: alphaAsset)
            } else {
                unstakeAsset = chainAsset
            }
        } else {
            unstakeAsset = chainAsset
        }

        guard let setupVC = SubtensorUnstakeSetupViewFactory.createView(
            chainAsset: unstakeAsset,
            position: position
        ) else { return }
        view.navigationController?.pushViewController(setupVC, animated: true)
    }

    func showError(from view: UIViewController, message: String) {
        let languages = localizationManager.selectedLocale.rLanguages
        let alert = UIAlertController(
            title: R.string(preferredLanguages: languages).localizable.commonErrorGeneralTitle(),
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: R.string(preferredLanguages: languages).localizable.commonOk(),
            style: .default
        ))
        view.present(alert, animated: true)
    }

    // MARK: - Private routing helpers

    private func showRootSetup(from view: UIViewController) {
        guard let setupVC = SubtensorStakeSetupViewFactory.createView(chainAsset: chainAsset) else { return }
        view.navigationController?.pushViewController(setupVC, animated: true)
    }

    private func showSubnetPicker(from view: UIViewController) {
        let pickerVC = SubtensorSubnetPickerViewController(
            chainAsset: chainAsset,
            localizationManager: localizationManager
        ) { [weak self, weak view] subnet in
            guard let self, let view else { return }
            self.showSubnetSetup(from: view, netuid: subnet.netuid, subnetName: subnet.name)
        }
        view.navigationController?.pushViewController(pickerVC, animated: true)
    }

    private func showSubnetSetup(from view: UIViewController, netuid: UInt16, subnetName: String?) {
        guard let setupVC = SubtensorStakeSetupViewFactory.createView(
            chainAsset: chainAsset,
            netuid: netuid,
            subnetName: subnetName
        ) else { return }
        view.navigationController?.pushViewController(setupVC, animated: true)
    }
}
