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
        for action: RampAction,
        locale: Locale
    ) {
        guard let delegate else { return }

        startRampFlow(
            from: view,
            actions: [action],
            rampType: action.type,
            wireframe: self,
            chainAsset: chainAsset,
            delegate: delegate,
            locale: locale
        )
    }
}
