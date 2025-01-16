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

    let chainSelectionView: DetailsTriangularedView = {
        let view = UIFactory.default.createChainAssetSelectionView()
        view.borderWidth = 0.0
        view.actionImage = R.image.iconMore()?.withRenderingMode(.alwaysTemplate)
        view.actionView.tintColor = R.color.colorIconSecondary()!
        return view
    }()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                setupLocalization()
            }
        }
    }

    private var viewModel: ChainBalanceViewModel?

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

    private func setupLayout() {
        addSubview(walletSwitch)
        walletSwitch.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(10.0)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.size.equalTo(UIConstants.walletSwitchSize)
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.equalTo(walletSwitch.snp.leading).inset(-8.0)
            make.centerY.equalTo(walletSwitch)
        }

        addSubview(votingTypeSwitch)
        votingTypeSwitch.snp.makeConstraints { make in
            make.top.equalTo(walletSwitch.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(40.0)
        }

        let chainBlur = BlockBackgroundView()
        addSubview(chainBlur)
        chainBlur.snp.makeConstraints { make in
            make.top.equalTo(votingTypeSwitch.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(8)
        }

        chainBlur.addSubview(chainSelectionView)
        chainSelectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(52.0)
        }
    }

    private func setupLocalization() {
        let languages = locale.rLanguages

        titleLabel.text = R.string.localizable.tabbarVoteTitle(preferredLanguages: languages)

        votingTypeSwitch.titles = [
            R.string.localizable.tabbarGovernanceTitle(preferredLanguages: languages),
            R.string.localizable.tabbarCrowdloanTitle_v190(preferredLanguages: languages)
        ]
    }
}

extension VoteTableHeaderView: VoteChainViewProtocol {
    func bind(viewModel: ChainBalanceViewModel) {
        self.viewModel?.icon.cancel(on: chainSelectionView.iconView)
        chainSelectionView.iconView.image = nil

        self.viewModel = viewModel

        chainSelectionView.title = viewModel.name
        chainSelectionView.subtitle = viewModel.balance

        let iconSize = 2 * chainSelectionView.iconRadius
        viewModel.icon.loadImage(
            on: chainSelectionView.iconView,
            targetSize: CGSize(width: iconSize, height: iconSize),
            animated: true
        )

        setNeedsLayout()
    }
}
