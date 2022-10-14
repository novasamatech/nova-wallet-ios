import UIKit
import SoraUI

final class CrowdloanStatusSectionView: UITableViewHeaderFooterView {
    var skeletonView: SkrullableView?
    private var viewModel: LoadableViewModelState<Model>?

    let titleLabel: UILabel = .create {
        $0.textColor = R.color.colorWhite()
        $0.font = .h3Title
    }

    let countView: BorderedLabelView = .create {
        $0.titleLabel.textColor = R.color.colorWhite80()
        $0.titleLabel.font = .semiBoldFootnote
        $0.contentInsets = UIEdgeInsets(top: 2, left: 8, bottom: 3, right: 8)
    }

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        backgroundView = UIView()
        backgroundView?.backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(Constants.TitleLabelInsets.top)
            make.leading.equalToSuperview().inset(Constants.TitleLabelInsets.leading)
            make.bottom.equalToSuperview().inset(Constants.TitleLabelInsets.bottom)
        }

        contentView.addSubview(countView)
        countView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(Constants.CountView.leadingSpace)
            make.height.equalTo(Constants.CountView.height)
            make.centerY.equalTo(titleLabel.snp.centerY)
        }
    }
}

extension CrowdloanStatusSectionView {
    struct Model {
        let title: String
        let count: Int
    }

    func bind(viewModel: LoadableViewModelState<Model>) {
        self.viewModel = viewModel

        guard let value = viewModel.value else {
            return
        }

        titleLabel.text = value.title
        countView.titleLabel.text = value.count.description
    }
}

// swiftlint:disable nesting
extension CrowdloanStatusSectionView {
    private enum Constants {
        enum TitleLabelInsets {
            static let top: CGFloat = 24
            static let leading: CGFloat = 20
            static let bottom: CGFloat = 8
        }

        enum CountView {
            static let height: CGFloat = 21
            static let leadingSpace: CGFloat = 8
        }
    }
}

// swiftlint:enable nesting

extension CrowdloanStatusSectionView: SkeletonableView {
    var skeletonSuperview: UIView {
        self
    }

    var hidingViews: [UIView] {
        [titleLabel, countView]
    }

    func updateLoadingState() {
        guard let viewModel = self.viewModel else {
            return
        }
        switch viewModel {
        case .cached, .loaded:
            stopLoadingIfNeeded()
        case .loading:
            startLoadingIfNeeded()
        }
    }

    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let skeletonSize = CGSize(width: 88, height: 14)
        let offsetY = Constants.TitleLabelInsets.top + titleLabel.font.lineHeight / 2 - skeletonSize.height / 2
        let offset = CGPoint(
            x: Constants.TitleLabelInsets.leading,
            y: offsetY
        )

        return [
            SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: offset,
                size: skeletonSize
            )
        ]
    }
}
