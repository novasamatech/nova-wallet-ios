import UIKit
import SoraFoundation

final class AssetDetailsContainerViewController: ContainerViewController {
    override var navigationItem: UINavigationItem {
        (content as? UIViewController)?.navigationItem ?? .init()
    }

    init(localizationManager: LocalizationManagerProtocol) {
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
    }

    private func setupLocalization() {}
}

extension AssetDetailsContainerViewController: AssetDetailsContainerViewProtocol {}

extension AssetDetailsContainerViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
