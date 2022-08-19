import UIKit

final class CrowdloanTableHeaderView: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h1Title
        return label
    }()

    let walletSwitch = WalletSwitchControl()

    let chainSelectionView: DetailsTriangularedView = {
        let view = UIFactory.default.createChainAssetSelectionView()
        return view
    }()

    private var viewModel: CrowdloansChainViewModel?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: CrowdloansChainViewModel) {
        self.viewModel?.imageViewModel?.cancel(on: chainSelectionView.iconView)
        chainSelectionView.iconView.image = nil

        self.viewModel = viewModel

        chainSelectionView.title = viewModel.networkName
        chainSelectionView.subtitle = viewModel.balance

        let iconSize = 2 * chainSelectionView.iconRadius
        viewModel.imageViewModel?.loadImage(
            on: chainSelectionView.iconView,
            targetSize: CGSize(width: iconSize, height: iconSize),
            animated: true
        )
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

        let chainBlur = TriangularedBlurView()
        addSubview(chainBlur)
        chainBlur.snp.makeConstraints { make in
            make.top.equalTo(walletSwitch.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(8)
        }

        chainBlur.addSubview(chainSelectionView)
        chainSelectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(52.0)
        }
    }
}
