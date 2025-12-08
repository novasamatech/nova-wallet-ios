import UIKit
import UIKit_iOS
import Foundation_iOS

protocol AccountImportSeedViewDelegate: AnyObject {
    func accountImportSeedViewDidProceed(_ view: AccountImportSeedView)
    func accountImportSeedViewDidTapScan(_ view: AccountImportSeedView)
}

final class AccountImportSeedView: AccountImportBaseView {
    weak var delegate: AccountImportSeedViewDelegate?

    private let seedHeaderStackView: UIStackView = .create { view in
        view.axis = .horizontal
        view.distribution = .equalSpacing
        view.alignment = .center
    }

    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(
            top: 12.0,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let titleLabel: UILabel = .create { view in
        view.textColor = R.color.colorTextPrimary()
        view.font = .boldTitle3
        view.numberOfLines = 0
    }

    let seedTitleLabel = AccountImportSeedView.createSectionTitleLabel()

    let seedHintLabel: UILabel = .create { view in
        view.textColor = R.color.colorTextSecondary()
        view.font = .regularFootnote
    }

    let seedInputView: ScanInputView = .create { view in
        view.localizablePlaceholder = LocalizableResource { _ in
            "0xAB"
        }

        view.textField.keyboardType = .default
        view.textField.returnKeyType = .done
        view.textField.textContentType = .none
        view.textField.autocapitalizationType = .none
        view.textField.autocorrectionType = .no
        view.textField.spellCheckingType = .no
    }

    let walletNameTitleLabel = createSectionTitleLabel()

    let walletNameInputView: TextInputView = .create { view in
        view.textField.returnKeyType = .done
    }

    let proceedButton: TriangularedButton = .create { view in
        view.applyDefaultStyle()
    }

    private(set) var sourceViewModel: InputViewModelProtocol?
    private(set) var usernameViewModel: InputViewModelProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
        setupHandlers()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bindSource(viewModel: InputViewModelProtocol) {
        sourceViewModel = viewModel
        seedInputView.bind(inputViewModel: viewModel)

        updateProceedButton()
    }

    func bindUsername(viewModel: InputViewModelProtocol?) {
        usernameViewModel = viewModel

        if let viewModel = viewModel {
            walletNameInputView.bind(inputViewModel: viewModel)
        }

        let isHidden = viewModel == nil
        walletNameTitleLabel.isHidden = isHidden
        walletNameInputView.isHidden = isHidden

        updateProceedButton()
    }

    override func setupLocalization() {
        titleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.walletImportSeedTitle()
        seedTitleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.importRawSeed()
        seedHintLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.accountImportSubstrateSeedPlaceholder_v2_2_0()

        walletNameTitleLabel.text = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.walletUsernameSetupChooseTitle_v2_2_0()

        updateProceedButton()
    }

    override func updateOnAppear() {
        seedInputView.textField.becomeFirstResponder()
    }

    override func updateOnKeyboardBottomInsetChange(_ newInset: CGFloat) {
        let scrollViewOffset = bounds.height - containerView.frame.maxY

        var contentInsets = containerView.scrollView.contentInset
        contentInsets.bottom = max(0.0, newInset - scrollViewOffset)
        containerView.scrollView.contentInset = contentInsets

        if contentInsets.bottom > 0.0 {
            let targetView: UIView?

            if seedInputView.textField.isFirstResponder {
                targetView = seedInputView
            } else if walletNameInputView.textField.isFirstResponder {
                targetView = walletNameInputView
            } else {
                targetView = nil
            }

            if let firstResponderView = targetView {
                let fieldFrame = containerView.scrollView.convert(
                    firstResponderView.frame,
                    from: firstResponderView.superview
                )

                containerView.scrollView.scrollRectToVisible(fieldFrame, animated: true)
            }
        }
    }
}

// MARK: - Private

private extension AccountImportSeedView {
    static func createSectionTitleLabel() -> UILabel {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorTextSecondary()
        return label
    }

    static func createHintLabel() -> UILabel {
        let label = UILabel()
        label.font = .caption1
        label.textColor = R.color.colorTextSecondary()
        label.numberOfLines = 0
        return label
    }

    func setupHandlers() {
        proceedButton.addTarget(self, action: #selector(actionProceed), for: .touchUpInside)

        seedInputView.scanButton.addTarget(self, action: #selector(actionScan), for: .touchUpInside)
        seedInputView.addTarget(self, action: #selector(actionSeedInputChanged), for: .editingChanged)
        seedInputView.delegate = self

        walletNameInputView.addTarget(self, action: #selector(actionWalletNameChanged), for: .editingChanged)
        walletNameInputView.delegate = self
    }

    func setupLayout() {
        addSubview(proceedButton)
        proceedButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(proceedButton.snp.top).offset(-8.0)
        }

        containerView.stackView.addArrangedSubview(titleLabel)
        containerView.stackView.setCustomSpacing(Constants.groupSpacing, after: titleLabel)

        seedHeaderStackView.addArrangedSubview(seedTitleLabel)
        seedHeaderStackView.addArrangedSubview(seedHintLabel)

        containerView.stackView.addArrangedSubview(seedHeaderStackView)
        containerView.stackView.setCustomSpacing(Constants.sectionSpacing, after: seedHeaderStackView)

        containerView.stackView.addArrangedSubview(seedInputView)
        containerView.stackView.setCustomSpacing(Constants.groupSpacing, after: seedInputView)

        containerView.stackView.addArrangedSubview(walletNameTitleLabel)
        containerView.stackView.setCustomSpacing(Constants.sectionSpacing, after: walletNameTitleLabel)

        containerView.stackView.addArrangedSubview(walletNameInputView)
        containerView.stackView.setCustomSpacing(Constants.sectionSpacing, after: walletNameInputView)
    }

    func updateProceedButton() {
        if let viewModel = sourceViewModel, viewModel.inputHandler.required,
           (seedInputView.textField.text ?? "").isEmpty {
            proceedButton.applyDisabledStyle()
            proceedButton.isUserInteractionEnabled = false
            proceedButton.imageWithTitleView?.title = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.walletImportNoSeedTitle()
        } else if let viewModel = usernameViewModel, viewModel.inputHandler.required,
                  (walletNameInputView.textField.text ?? "").isEmpty {
            proceedButton.applyDisabledStyle()
            proceedButton.isUserInteractionEnabled = false
            proceedButton.imageWithTitleView?.title = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonEnterWalletNameDisabled()
        } else {
            proceedButton.applyEnabledStyle()
            proceedButton.isUserInteractionEnabled = true
            proceedButton.imageWithTitleView?.title = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonContinue()
        }
    }

    @objc func actionProceed() {
        delegate?.accountImportSeedViewDidProceed(self)
    }

    @objc func actionScan() {
        delegate?.accountImportSeedViewDidTapScan(self)
    }

    @objc func actionSeedInputChanged() {
        updateProceedButton()
    }

    @objc func actionWalletNameChanged() {
        updateProceedButton()
    }
}

// MARK: - ScanInputViewDelegate

extension AccountImportSeedView: ScanInputViewDelegate {
    func accountInputViewWillStartEditing(_: ScanInputView) {}

    func accountInputViewShouldReturn(_ inputView: ScanInputView) -> Bool {
        if inputView === seedInputView {
            if !walletNameInputView.isHidden {
                walletNameInputView.textField.becomeFirstResponder()
            } else {
                inputView.textField.resignFirstResponder()
            }
        }
        return false
    }

    func accountInputViewDidEndEditing(_: ScanInputView) {}
}

// MARK: - TextInputViewDelegate

extension AccountImportSeedView: TextInputViewDelegate {
    func textInputViewWillStartEditing(_: TextInputView) {}

    func textInputViewShouldReturn(_ inputView: TextInputView) -> Bool {
        inputView.textField.resignFirstResponder()
        return false
    }
}

// MARK: - Constants

private extension AccountImportSeedView {
    enum Constants {
        static let sectionSpacing: CGFloat = 8.0
        static let groupSpacing: CGFloat = 16.0
    }
}
