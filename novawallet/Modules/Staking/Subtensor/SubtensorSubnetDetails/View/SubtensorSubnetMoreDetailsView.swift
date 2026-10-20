import UIKit
import UIKit_iOS

final class SubtensorSubnetMoreDetailsView: UIView {
    let titleControl: ActionTitleControl = .create {
        $0.indicator = ResizableImageActionIndicator(size: .init(width: 24, height: 24))
        $0.imageView.image = R.image.iconSmallArrowDown()?.tinted(with: R.color.colorIconSecondary()!)
        $0.titleLabel.apply(style: .regularSubhedlineSecondary)
        $0.layoutType = .flexible
    }

    let stackView = UIStackView()
    private let rowsView = UIStackView()
    private var rowViews: [SubtensorParameterRowView] = []
    weak var delegate: CollapsableContainerViewDelegate?
    var linkHandler: ((URL) -> Void)?
    private(set) var expanded = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        stackView.axis = .vertical
        rowsView.axis = .vertical
        stackView.addArrangedSubview(titleControl)
        stackView.addArrangedSubview(rowsView)
        addSubview(stackView)
        stackView.snp.makeConstraints { $0.edges.equalToSuperview() }
        titleControl.snp.makeConstraints { $0.height.equalTo(44) }
        rowsView.isHidden = true
        titleControl.addTarget(self, action: #selector(toggle), for: .valueChanged)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(_ rows: [SubtensorParameterRowViewModel]) {
        while rowViews.count < rows.count {
            let row = SubtensorParameterRowView(style: .detail)
            rowViews.append(row)
            rowsView.addArrangedSubview(row)
        }
        for (index, row) in rowViews.enumerated() {
            row.isHidden = index >= rows.count
            guard index < rows.count else { continue }
            row.bind(rows[index])
            row.onTap = rows[index].link.map { url in { [weak self] in self?.linkHandler?(url) } }
        }
    }

    @objc private func toggle() {
        expanded.toggle()
        rowsView.isHidden = !expanded
        delegate?.animateAlongsideWithInfo(sender: self)
        delegate?.didChangeExpansion(isExpanded: expanded, sender: self)
    }
}
