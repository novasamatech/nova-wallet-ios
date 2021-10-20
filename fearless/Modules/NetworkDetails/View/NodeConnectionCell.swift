import UIKit
import SoraUI

protocol NodeConnectionCellDelegate: AnyObject {
    func didSelectInfo(_ cell: NodeConnectionCell)
}

final class NodeConnectionCell: UITableViewCell {
    private let selectionImageView = UIImageView(image: R.image.listCheckmarkIcon())

    private let nodeNameLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    private let nodeUrlLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorStrokeGray()
        return label
    }()

    private let infoButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconInfo(), for: .normal)
        return button
    }()

    weak var delegate: NodeConnectionCellDelegate?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = R.color.colorAccent()!.withAlphaComponent(0.3)
        infoButton.addTarget(self, action: #selector(actionInfo), for: .touchUpInside)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        showsReorderControl = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        separatorInset = .init(
            top: 0,
            left: UIConstants.horizontalInset,
            bottom: 0,
            right: UIConstants.horizontalInset
        )
    }

    private func setupLayout() {
        let content: UIView = .hStack(
            alignment: .center,
            spacing: 12,
            [
                selectionImageView,
                .vStack([nodeNameLabel, nodeUrlLabel]),
                UIView(),
                infoButton
            ]
        )
        selectionImageView.snp.makeConstraints { $0.size.equalTo(24) }

        contentView.addSubview(content)
        content.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(8)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }
    }

    func bind(viewModel: ManagedNodeConnectionViewModel) {
        nodeNameLabel.text = viewModel.name
        nodeUrlLabel.text = viewModel.identifier
        selectionImageView.alpha = viewModel.isSelected ? 1.0 : 0.0
    }

    func setReordering(_ reordering: Bool, animated: Bool) {
        let closure = {
            self.infoButton.alpha = reordering ? 0.0 : 1.0
        }

        if animated {
            BlockViewAnimator().animate(block: closure, completionBlock: nil)
        } else {
            closure()
        }

        if reordering {
            recolorReorderControl(R.color.colorWhite()!)
        }
    }

    @objc
    private func actionInfo() {
        delegate?.didSelectInfo(self)
    }
}
