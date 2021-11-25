import UIKit
import SoraUI
import SoraFoundation

final class AccountImportMnemonicView: AccountImportBaseView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h2Title
        label.numberOfLines = 0
        return label
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = .p1Paragraph
        label.numberOfLines = 0
        return label
    }()

    let mnemonicBackgroundView: RoundedView = UIFactory.default.createRoundedBackgroundView()

    let mnemonicTitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = .p2Paragraph
        return label
    }()

    let mnemonicTextView: UITextView = {
        let view = UITextView()
        view.font = .p1Paragraph
        view.textColor = R.color.colorWhite()
        view.tintColor = R.color.colorWhite()
        return view
    }()

    let hintLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = .p2Paragraph
        label.numberOfLines = 0
        return label
    }()

    let proceedButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    private(set) var sourceViewModel: InputViewModelProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bindSource(viewModel: InputViewModelProtocol) {
        sourceViewModel = viewModel
        mnemonicTextView.text = viewModel.inputHandler.value
    }

    override func setupLocalization() {
        titleLabel.text = "Enter the words in the right order"
        subtitleLabel.text = "Write words separately with one space, no commas or other signs."
        mnemonicTitleLabel.text = "Mnemonic Passphrase"
        hintLabel.text = "Typically 12-word phrase (but may be 15, 18, 21 or 24)"
    }

    private func setupLayout() {
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(safeAreaLayoutGuide).inset(UIConstants.verticalTitleInset)
        }

        addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(titleLabel.snp.bottom).offset(12.0)
        }

        addSubview(mnemonicBackgroundView)
        mnemonicBackgroundView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(subtitleLabel.snp.bottom).offset(24.0)
        }

        mnemonicBackgroundView.addSubview(mnemonicTitleLabel)
        mnemonicTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(8.0)
            make.leading.trailing.equalToSuperview().inset(16.0)
        }

        mnemonicBackgroundView.addSubview(mnemonicTextView)
        mnemonicTextView.snp.makeConstraints { make in
            make.top.equalTo(mnemonicTitleLabel.snp.bottom).offset(4.0)
            make.leading.trailing.equalToSuperview().inset(16.0)
            make.bottom.equalToSuperview().inset(16.0)
            make.height.greaterThanOrEqualTo(72.0)
        }

        addSubview(hintLabel)
        hintLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(mnemonicBackgroundView.snp.bottom).offset(12.0)
        }

        addSubview(proceedButton)
        proceedButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}
