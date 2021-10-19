import UIKit
import SoraUI

protocol NodeConnectionCellDelegate: AnyObject {
    func didSelectInfo(_ cell: NodeConnectionCell)
}

final class NodeConnectionCell: UITableViewCell {
    private let nodeNameLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    @IBOutlet private var detailsLabel: UILabel!
    @IBOutlet private var infoButton: RoundedButton!
    @IBOutlet private var selectionImageView: UIImageView!

    weak var delegate: NodeConnectionCellDelegate?

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

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

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

    private func setupLayout() {}

    func bind(viewModel: ManagedNodeConnectionViewModel) {
        nodeNameLabel.text = viewModel.name
        detailsLabel.text = viewModel.identifier
        selectionImageView.isHidden = !viewModel.isSelected
    }

    @objc
    private func actionInfo() {
        delegate?.didSelectInfo(self)
    }
}
