import UIKit
import SoraFoundation

final class AccountImportViewController: UIViewController {
    enum ViewType {
        case mnemonic(view: AccountImportMnemonicView)
        case seed(view: AccountImportSeedView)
        case keystore(view: AccountImportKeystoreView)

        var view: AccountImportBaseView {
            switch self {
            case let .keystore(view):
                return view
            case let .seed(view):
                return view
            case let .mnemonic(view):
                return view
            }
        }
    }

    let presenter: AccountImportPresenterProtocol

    var keyboardHandler: KeyboardHandler?

    private var viewType: ViewType?

    private var isFirstAppear: Bool = true

    init(presenter: AccountImportPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = R.color.colorBlack()

        setupLocalization()

        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if keyboardHandler == nil {
            setupKeyboardHandler()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if isFirstAppear {
            isFirstAppear = false

            viewType?.view.updateOnAppear()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        clearKeyboardHandler()
    }

    private func setupLocalization() {
        guard let viewType = viewType else {
            return
        }

        viewType.view.locale = selectedLocale
    }

    private func setupAdvancedButton() {
        guard navigationItem.rightBarButtonItem == nil else {
            return
        }

        let buttonItem = UIBarButtonItem(
            image: R.image.iconOptions(),
            style: .plain,
            target: self,
            action: #selector(actionAdvancedSettings)
        )

        navigationItem.rightBarButtonItem = buttonItem
    }

    private func clearAdvancedButton() {
        navigationItem.rightBarButtonItem = nil
    }

    private func clearView() {
        viewType?.view.removeFromSuperview()
        viewType = nil
    }

    private func setupView(for source: SecretSource) {
        clearView()

        let viewType: ViewType

        switch source {
        case .mnemonic:
            let view = AccountImportMnemonicView()
            view.delegate = self
            viewType = .mnemonic(view: view)
        case .seed:
            let view = AccountImportSeedView()
            view.delegate = self
            viewType = .seed(view: view)
        case .keystore:
            let view = AccountImportKeystoreView()
            view.delegate = self
            viewType = .keystore(view: view)
        }

        let importView = viewType.view
        view.addSubview(importView)

        importView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        importView.locale = selectedLocale

        self.viewType = viewType
    }

    @objc private func actionAdvancedSettings() {
        presenter.activateAdvancedSettings()
    }
}

extension AccountImportViewController: AccountImportMnemonicViewDelegate {
    func accountImportMnemonicViewDidProceed(_: AccountImportMnemonicView) {
        presenter.proceed()
    }
}

extension AccountImportViewController: AccountImportSeedViewDelegate {
    func accountImportSeedViewDidProceed(_: AccountImportSeedView) {
        presenter.proceed()
    }
}

extension AccountImportViewController: AccountImportKeystoreViewDelegate {
    func accountImportKeystoreViewDidProceed(_: AccountImportKeystoreView) {
        presenter.proceed()
    }

    func accountImportKeystoreViewDidUpload(_: AccountImportKeystoreView) {
        presenter.activateUpload()
    }
}

extension AccountImportViewController: AccountImportViewProtocol {
    func setSource(type: SecretSource) {
        setupView(for: type)
    }

    func setSource(viewModel: InputViewModelProtocol) {
        guard let viewType = viewType else {
            return
        }

        switch viewType {
        case let .mnemonic(view):
            view.bindSource(viewModel: viewModel)
        case let .seed(view):
            view.bindSource(viewModel: viewModel)
        case let .keystore(view):
            view.bindSource(viewModel: viewModel)
        }
    }

    func setName(viewModel: InputViewModelProtocol?) {
        guard let viewType = viewType else {
            return
        }

        switch viewType {
        case let .mnemonic(view):
            view.bindUsername(viewModel: viewModel)
        case let .seed(view):
            view.bindUsername(viewModel: viewModel)
        case let .keystore(view):
            view.bindUsername(viewModel: viewModel)
        }
    }

    func setPassword(viewModel: InputViewModelProtocol) {
        if case let .keystore(sourceView) = viewType {
            sourceView.bindPassword(viewModel: viewModel)
        }
    }

    func setUploadWarning(message: String) {
        if case let .keystore(sourceView) = viewType {
            sourceView.setUploadWarning(message: message)
        }
    }

    func setShouldShowAdvancedSettings(_ shouldShow: Bool) {
        if shouldShow {
            setupAdvancedButton()
        } else {
            clearAdvancedButton()
        }
    }
}

extension AccountImportViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension AccountImportViewController: KeyboardAdoptable {
    func updateWhileKeyboardFrameChanging(_ frame: CGRect) {
        let localKeyboardFrame = view.convert(frame, from: nil)
        let bottomInset = view.bounds.height - localKeyboardFrame.minY

        viewType?.view.updateOnKeyboardBottomInsetChange(bottomInset)
    }
}
