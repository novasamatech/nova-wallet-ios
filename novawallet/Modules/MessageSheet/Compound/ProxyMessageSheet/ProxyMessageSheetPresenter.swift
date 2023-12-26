import SoraFoundation
import SoraKeystore

final class ProxyMessageSheetPresenter: MessageSheetPresenter, ProxyMessageSheetPresenterProtocol {
    private let settings: SettingsManagerProtocol

    init(settings: SettingsManagerProtocol, wireframe: MessageSheetWireframeProtocol) {
        self.settings = settings
        super.init(wireframe: wireframe)
    }

    func proceed(skipInfoNextTime: Bool, action: MessageSheetAction?) {
        settings.skipProxyFeeInformation = skipInfoNextTime
        wireframe.complete(on: view, with: action)
    }
}
