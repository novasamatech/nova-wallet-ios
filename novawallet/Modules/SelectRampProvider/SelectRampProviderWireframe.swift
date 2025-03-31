import Foundation

final class SelectRampProviderWireframe {
    weak var delegate: RampDelegate?

    let chainAsset: ChainAsset

    init(
        delegate: RampDelegate,
        chainAsset: ChainAsset
    ) {
        self.delegate = delegate
        self.chainAsset = chainAsset
    }
}

extension SelectRampProviderWireframe: SelectRampProviderWireframeProtocol {
    func openRampProvider(
        from view: (any ControllerBackedProtocol)?,
        for action: RampAction
    ) {
        guard let rampView = RampViewFactory.createView(
            for: action,
            chainAsset: chainAsset,
            delegate: delegate
        ) else { return }

        view?.controller.navigationController?.pushViewController(
            rampView.controller,
            animated: true
        )
    }
}
