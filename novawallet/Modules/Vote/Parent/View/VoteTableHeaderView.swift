import UIKit
import UIKit_iOS

final class VoteTableHeaderView: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextPrimary()
        label.font = .boldLargeTitle
        return label
    }()

    let walletSwitch = WalletSwitchControl()

    let votingTypeSwitch: RoundedSegmentedControl = .create { view in
        view.backgroundView.fillColor = R.color.colorSegmentedBackground()!
        view.selectionColor = R.color.colorSegmentedTabActive()!
        view.titleFont = .regularFootnote
        view.selectedTitleColor = R.color.colorTextPrimary()!
        view.titleColor = R.color.colorTextSecondary()!
    }

    let chainSelectionView: VoteTableChainSelectionControl = .create {
        $0.preferredHeight = Constants.chainSelectionHeight
    }

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                setupLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
        setupLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Private

private extension VoteTableHeaderView {
    func setupLayout() {
        addSubview(walletSwitch)
        walletSwitch.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(Constants.walletSwitchTopInset)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.size.equalTo(UIConstants.walletSwitchSize)
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.equalTo(walletSwitch.snp.leading).inset(-Constants.titleTrailingOffset)
            make.centerY.equalTo(walletSwitch)
        }

        addSubview(votingTypeSwitch)
        votingTypeSwitch.snp.makeConstraints { make in
            make.top.equalTo(walletSwitch.snp.bottom).offset(Constants.votingTypeSwitchTopOffset)
            make.leading.trailing.equalToSuperview().inset(Constants.standardHorizontalInset)
            make.height.equalTo(Constants.votingTypeSwitchHeight)
        }

        addSubview(chainSelectionView)
        chainSelectionView.snp.makeConstraints { make in
            make.top.equalTo(votingTypeSwitch.snp.bottom).offset(Constants.chainSelectionTopOffset)
            make.leading.trailing.equalToSuperview().inset(Constants.standardHorizontalInset)
            make.bottom.equalToSuperview().inset(Constants.chainSelectionBottomInset)
            make.height.equalTo(Constants.chainSelectionHeight)
        }
    }

    func setupLocalization() {
        let languages = locale.rLanguages

        titleLabel.text = R.string.localizable.tabbarVoteTitle(preferredLanguages: languages)

        votingTypeSwitch.titles = [
            R.string.localizable.tabbarGovernanceTitle(preferredLanguages: languages),
            R.string.localizable.tabbarCrowdloanTitle_v190(preferredLanguages: languages)
        ]
    }
}

// MARK: - VoteChainViewProtocol

extension VoteTableHeaderView: VoteChainViewProtocol {
    func bind(viewModel: SecuredViewModel<ChainBalanceViewModel>) {
        chainSelectionView.bind(
            title: viewModel.originalContent.name,
            subtitle: viewModel.originalContent.balance,
            privacyMode: viewModel.privacyMode
        )

        chainSelectionView.bind(imageViewModel: viewModel.originalContent.icon)

        setNeedsLayout()
    }
}

// MARK: - Constants

private extension VoteTableHeaderView {
    enum Constants {
        static let walletSwitchTopInset: CGFloat = 10.0
        static let titleTrailingOffset: CGFloat = 8.0
        static let votingTypeSwitchTopOffset: CGFloat = 16.0
        static let standardHorizontalInset: CGFloat = 16.0
        static let votingTypeSwitchHeight: CGFloat = 40.0
        static let chainSelectionTopOffset: CGFloat = 8.0
        static let chainSelectionBottomInset: CGFloat = 8.0
        static let chainSelectionHeight: CGFloat = 56.0
    }
}
