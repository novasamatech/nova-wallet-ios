import Foundation
import Foundation_iOS
import NovaAnalytics

final class UsernameSetupPresenter: BaseUsernameSetupPresenter, AnalyticsTracking {
    var wireframe: UsernameSetupWireframeProtocol

    private let abandonTracker = AnalyticsAbandonTracker {
        AnalyticsEvent.walletCreationAbandoned(lastStep: .other)
    }

    init(wireframe: UsernameSetupWireframeProtocol) {
        self.wireframe = wireframe
    }

    override func setup() {
        super.setup()

        trackAnalytics(.walletCreationStarted())
    }
}

extension UsernameSetupPresenter: UsernameSetupPresenterProtocol {
    func proceed() {
        let walletName = viewModel.inputHandler.value

        abandonTracker.markProceeded()

        wireframe.proceed(from: view, walletName: walletName)
    }
}
