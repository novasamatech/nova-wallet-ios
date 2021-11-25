import UIKit
import SoraFoundation

final class AccountImportViewController1: UIViewController {
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

    private var viewType: ViewType?

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

    private func setupLocalization() {
        guard let viewType = viewType else {
            return
        }

        viewType.view.locale = selectedLocale
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
            viewType = .seed(view: view)
        case .keystore:
            let view = AccountImportKeystoreView()
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
}

extension AccountImportViewController1: AccountImportMnemonicViewDelegate {
    func accountImportMnemonicViewDidProceed(_: AccountImportMnemonicView) {
        presenter.proceed()
    }
}

extension AccountImportViewController1: AccountImportViewProtocol {
    func setTitle(_: String) {}

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
            break
        case let .keystore(view):
            break
        }
    }

    func setPassword(viewModel: InputViewModelProtocol) {
        if case let .keystore(sourceView) = viewType {
            sourceView.bindPassword(viewModel: viewModel)
        }
    }

    func setSelectedSubstrateCrypto(model _: SelectableViewModel<TitleWithSubtitleViewModel>) {}

    func setSelectedEthereumCrypto(model _: SelectableViewModel<TitleWithSubtitleViewModel>) {}

    func setSubstrateDerivationPath(viewModel _: InputViewModelProtocol) {}

    func setEthereumDerivationPath(viewModel _: InputViewModelProtocol) {}

    func setUploadWarning(message _: String) {}

    func didCompleteSourceTypeSelection() {}

    func didCompleteCryptoTypeSelection() {}

    func didValidateSubstrateDerivationPath(_: FieldStatus) {}

    func didValidateEthereumDerivationPath(_: FieldStatus) {}
}

extension AccountImportViewController1: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
