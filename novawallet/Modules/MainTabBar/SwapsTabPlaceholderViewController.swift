import UIKit
import Foundation_iOS

final class SwapsTabPlaceholderViewController: UIViewController, ViewHolder {
    typealias RootViewType = SwapsTabPlaceholderViewLayout

    init(localizationManager: LocalizationManagerProtocol) {
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SwapsTabPlaceholderViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
    }
}

// MARK: Private

private extension SwapsTabPlaceholderViewController {
    func setupLocalization() {
        rootView.titleLabel.text = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.tabbarSwapsTitle()
    }
}

// MARK: Localizable

extension SwapsTabPlaceholderViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

// MARK: HiddableBarWhenPushed

extension SwapsTabPlaceholderViewController: HiddableBarWhenPushed {}
