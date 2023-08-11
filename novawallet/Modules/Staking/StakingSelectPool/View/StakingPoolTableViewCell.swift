import UIKit
import SnapKit

final class StakingPoolTableViewCell: UITableViewCell {
    let view = StakingPoolView(frame: .zero)

    var infoAction: ((StakingPoolTableViewCell.Model) -> Void)?
    private var currentModel: StakingPoolTableViewCell.Model?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        setupLayout()
        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var contentInsets = UIEdgeInsets(top: 5, left: 16, bottom: 5, right: 16) {
        didSet {
            updateLayout()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        infoAction = nil
    }

    private func configure() {
        backgroundColor = .clear
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = .clear

        view.infoButton.addTarget(self, action: #selector(tapInfoButton), for: .touchUpInside)
    }

    @objc func tapInfoButton() {
        guard let viewModel = currentModel else {
            return
        }
        infoAction?(viewModel)
    }

    private func setupLayout() {
        contentView.addSubview(view)
        view.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(contentInsets)
        }
    }

    private func updateLayout() {
        view.snp.updateConstraints {
            $0.edges.equalToSuperview().inset(contentInsets)
        }
    }
}

extension StakingPoolTableViewCell {
    struct Model {
        let imageViewModel: ImageViewModelProtocol?
        let name: String
        let apy: RewardApyModel?
        let members: String
        let id: NominationPools.PoolId
    }

    struct RewardApyModel {
        let value: String
        let period: String
    }

    func bind(viewModel: Model) {
        currentModel?.imageViewModel?.cancel(on: view.iconView)
        currentModel = viewModel

        view.iconView.image = nil

        let imageSize = StakingPoolView.Constants.iconSize
        viewModel.imageViewModel?.loadImage(
            on: view.iconView,
            targetSize: imageSize,
            animated: true
        )

        view.poolName.text = viewModel.name
        view.rewardView.fView.text = viewModel.apy?.value
        view.rewardView.sView.text = viewModel.apy?.period
        view.membersCountLabel.text = viewModel.members
    }
}
