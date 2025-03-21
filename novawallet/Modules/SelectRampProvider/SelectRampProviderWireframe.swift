import Foundation

final class SelectRampProviderWireframe {
    weak var delegate: RampDelegate?

    init(delegate: RampDelegate) {
        self.delegate = delegate
    }
}

extension SelectRampProviderWireframe: SelectRampProviderWireframeProtocol {
    func openRampProvider(
        from view: (any ControllerBackedProtocol)?,
        for action: RampAction
    ) {
        guard let rampView = RampViewFactory.createView(
            for: action,
            delegate: delegate
        ) else { return }

        view?.controller.navigationController?.pushViewController(
            rampView.controller,
            animated: true
        )
    }
}
