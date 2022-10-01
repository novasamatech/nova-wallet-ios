import UIKit
import SoraUI

final class CrowdloanTableViewCell: UITableViewCell {
    var skeletonView: SkrullableView?

    private let backgroundBlurView: TriangularedBlurView = {
        let view = TriangularedBlurView()
        view.isUserInteractionEnabled = false
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        return label
    }()

    let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    let detailsLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textColor = R.color.colorTransparentText()
        label.font = .p2Paragraph
        return label
    }()

    let progressLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p2Paragraph
        return label
    }()

    let progressBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.colorBlurSeparator()
        view.layer.cornerRadius = 2
        return view
    }()

    let progressView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 2
        view.backgroundColor = R.color.colorCoral()
        return view
    }()

    private var progressValue: Double?

    let percentsLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p2Paragraph
        return label
    }()

    let timeLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .p3Paragraph
        label.textAlignment = .right
        return label
    }()

    let navigationImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconSmallArrow()?.withRenderingMode(.alwaysTemplate)
        imageView.contentMode = .center
        imageView.tintColor = R.color.colorWhite48()
        return imageView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        separatorInset = .zero

        selectedBackgroundView = UIView()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var viewModel: CrowdloanCellViewModel?

    override func prepareForReuse() {
        super.prepareForReuse()

        viewModel?.iconViewModel.cancel(on: iconImageView)
        viewModel = nil
        progressValue = nil

        iconImageView.image = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard let value = progressValue else {
            progressView.frame = .zero
            return
        }

        progressView.frame = .init(
            origin: .zero,
            size: CGSize(
                width: progressBackgroundView.bounds.width * CGFloat(value),
                height: progressBackgroundView.bounds.height
            )
        )
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)

        backgroundBlurView.overlayView.fillColor = highlighted ?
            R.color.colorAccentSelected()!
            : .clear
    }

    private func setupLayout() {
        let content = UIView.vStack(
            spacing: Constants.verticalOffset,
            [
                .hStack(
                    alignment: .top,
                    spacing: Constants.imageTextHorizontalOffset,
                    [
                        iconImageView,
                        .vStack(
                            alignment: .leading,
                            [
                                titleLabel,
                                detailsLabel
                            ]
                        ),
                        navigationImageView
                    ]
                ),
                .hStack([progressLabel, UIView()]),
                progressBackgroundView,
                .hStack([percentsLabel, UIView(), timeLabel])
            ]
        )

        iconImageView.snp.makeConstraints { $0.size.equalTo(Constants.imageSize) }
        navigationImageView.snp.makeConstraints { make in
            make.size.equalTo(Constants.navigationImageSize)
        }
        progressBackgroundView.addSubview(progressView)
        progressBackgroundView.snp.makeConstraints { $0.height.equalTo(Constants.progressHeight) }

        contentView.addSubview(backgroundBlurView)
        backgroundBlurView.snp.makeConstraints { make in
            make.edges.equalTo(Constants.backgroundBlurViewOffsets)
        }

        backgroundBlurView.addSubview(content)
        content.snp.makeConstraints { make in
            make.edges.equalTo(Constants.contentOffsets)
        }
    }

    func bind(viewModel: LoadableViewModelState<CrowdloanCellViewModel>) {
        guard let viewModel = viewModel.value else {
            startLoadingIfNeeded()
            return
        }
        self.viewModel = viewModel

        viewModel.iconViewModel.loadImage(
            on: iconImageView,
            targetSize: Constants.imageSize,
            animated: true
        )

        titleLabel.text = viewModel.title

        switch viewModel.description {
        case let .address(address):
            detailsLabel.text = address
        case let .text(text):
            detailsLabel.text = text
        }

        progressLabel.text = viewModel.progress
        percentsLabel.text = viewModel.progressPercentsText
        progressValue = viewModel.progressValue
        setNeedsLayout()

        if viewModel.isCompleted {
            timeLabel.text = nil
            percentsLabel.textColor = R.color.colorTransparentText()
            navigationImageView.isHidden = true
            progressView.backgroundColor = R.color.colorTransparentText()
            progressLabel.textColor = R.color.colorTransparentText()
            titleLabel.textColor = R.color.colorTransparentText()
            iconImageView.tintColor = R.color.colorTransparentText()!
        } else {
            timeLabel.text = viewModel.timeleft
            percentsLabel.textColor = R.color.colorCoral()
            navigationImageView.isHidden = false
            progressView.backgroundColor = R.color.colorCoral()
            progressLabel.textColor = R.color.colorWhite()
            titleLabel.textColor = R.color.colorWhite()
            iconImageView.tintColor = R.color.colorWhite()!
        }
        stopLoadingIfNeeded()
    }
}

extension CrowdloanTableViewCell {
    enum Constants {
        static let imageSize = CGSize(width: 40, height: 40)
        static let navigationImageSize = CGSize(width: 24, height: 24)
        static let progressHeight: CGFloat = 5
        static let backgroundBlurViewOffsets = UIEdgeInsets(top: 8, left: 16, bottom: 0, right: 16)
        static let contentOffsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        static let imageTextHorizontalOffset: CGFloat = 12
        static let verticalOffset: CGFloat = 8
    }
}

extension CrowdloanTableViewCell: SkeletonableView {
    var skeletonSuperview: UIView {
        backgroundBlurView
    }

    var hidingViews: [UIView] {
        let views = [
            titleLabel,
            iconImageView,
            detailsLabel,
            progressLabel,
            progressView,
            progressBackgroundView,
            percentsLabel,
            timeLabel
        ]
        return viewModel.map {
            $0.isCompleted ? views : views + [navigationImageView]
        } ?? views + [navigationImageView]
    }

    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let titleLabelSkeletonSize = CGSize(width: 77, height: 12)
        let detailsLabelSkeletonSize = CGSize(width: 127, height: 12)
        let progressLabelSkeletonSize = CGSize(width: 138, height: 12)
        let percentsLabelSkeletonSize = CGSize(width: 40, height: 12)
        let timeLabelSkeletonSize = CGSize(width: 67, height: 12)

        let imageSkeletonOffset = CGPoint(
            x: Constants.contentOffsets.left,
            y: Constants.contentOffsets.top
        )

        let titleSkeletonOffsetY = Constants.contentOffsets.top + titleLabel.font.lineHeight / 2 - titleLabelSkeletonSize.height / 2
        let titleSkeletonOffsetX = imageSkeletonOffset.x + Constants.imageSize.width + Constants.imageTextHorizontalOffset

        let titleSkeletonOffset = CGPoint(
            x: titleSkeletonOffsetX,
            y: titleSkeletonOffsetY
        )

        let detailsLabelSkeletonOffsetY = imageSkeletonOffset.y + Constants.imageSize.height - detailsLabelSkeletonSize.height

        let detailsLabelSkeletonOffset = CGPoint(
            x: titleSkeletonOffsetX,
            y: detailsLabelSkeletonOffsetY
        )

        let percentsLabelSkeletonOffsetY = spaceSize.height - Constants.contentOffsets.bottom - percentsLabelSkeletonSize.height

        let percentsLabelSkeletonOffset = CGPoint(
            x: Constants.contentOffsets.left,
            y: percentsLabelSkeletonOffsetY
        )

        let timeLabelSkeletonOffsetY = spaceSize.height - Constants.contentOffsets.bottom - timeLabelSkeletonSize.height
        let timeLabelSkeletonOffsetX = spaceSize.width - Constants.contentOffsets.right - timeLabelSkeletonSize.width
        let timeLabelSkeletonOffset = CGPoint(
            x: timeLabelSkeletonOffsetX,
            y: timeLabelSkeletonOffsetY
        )

        let progressViewSkeletonOffsetY = spaceSize.height - Constants.contentOffsets.bottom - percentsLabel.font.lineHeight - Constants.verticalOffset - Constants.progressHeight
        let progressViewSkeletonSize = CGSize(width: spaceSize.width - Constants.contentOffsets.left - Constants.contentOffsets.right, height: Constants.progressHeight)
        let progressViewSkeletonOffset = CGPoint(
            x: Constants.contentOffsets.left,
            y: progressViewSkeletonOffsetY
        )

        let progressLabelSkeletonOffsetY = progressViewSkeletonOffsetY - Constants.verticalOffset - progressLabel.font.lineHeight + progressLabelSkeletonSize.height / 2
        let progressLabelSkeletonOffset = CGPoint(
            x: Constants.contentOffsets.left,
            y: progressLabelSkeletonOffsetY
        )

        return [
            SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: imageSkeletonOffset,
                size: Constants.imageSize,
                cornerRadii: .init(width: 0.25, height: 0.25)
            ),
            SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: titleSkeletonOffset,
                size: titleLabelSkeletonSize
            ),
            SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: detailsLabelSkeletonOffset,
                size: detailsLabelSkeletonSize
            ),
            SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: progressLabelSkeletonOffset,
                size: progressLabelSkeletonSize
            ),
            SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: progressViewSkeletonOffset,
                size: progressViewSkeletonSize
            ),
            SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: percentsLabelSkeletonOffset,
                size: percentsLabelSkeletonSize
            ),
            SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: timeLabelSkeletonOffset,
                size: timeLabelSkeletonSize
            )
        ]
    }
}
