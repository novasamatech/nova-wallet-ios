import UIKit

final class NetworkTableViewCell: UITableViewCell, ModalPickerCellProtocol {
    typealias Model = NetworkViewModel

    let networkView = AssetListChainView()

    var checkmarked: Bool = false

    func bind(model: NetworkViewModel) {
        networkView.bind(viewModel: model)
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        selectionStyle = .none

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        contentView.addSubview(networkView)
        networkView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview().offset(-UIConstants.horizontalInset)
        }
    }
}
