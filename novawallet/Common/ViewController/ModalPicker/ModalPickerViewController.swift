import UIKit
import UIKit_iOS
import Foundation_iOS

protocol ModalPickerViewControllerDelegate: AnyObject {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?)
    func modalPickerDidSelectModel(at index: Int, section: Int, context: AnyObject?)
    func modalPickerDidCancel(context: AnyObject?)
    func modalPickerDidSelectAction(context: AnyObject?)
}

extension ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_: Int, context _: AnyObject?) {}
    func modalPickerDidSelectModel(at _: Int, section _: Int, context _: AnyObject?) {}
    func modalPickerDidCancel(context _: AnyObject?) {}
    func modalPickerDidSelectAction(context _: AnyObject?) {}
}

enum ModalPickerViewAction {
    case none
    case iconTitle(viewModel: LocalizableResource<IconWithTitleViewModel>)

    var hasAction: Bool {
        if case .none = self {
            return false
        } else {
            return true
        }
    }
}

class ModalPickerViewController<C: UITableViewCell & ModalPickerCellProtocol, T>: UIViewController,
    ModalViewProtocol,
    UITableViewDelegate,
    UITableViewDataSource where T == C.Model {
    @IBOutlet private var headerView: ImageWithTitleView!
    @IBOutlet private var headerBackgroundView: BorderedContainerView!
    @IBOutlet private var headerHeightConstraint: NSLayoutConstraint!
    @IBOutlet private var tableView: UITableView!

    var localizedTitle: LocalizableResource<String>?
    var icon: UIImage?
    var actionType: ModalPickerViewAction = .none

    var cellNib: UINib?
    var cellHeight: CGFloat = 55.0
    var actionCellHeight: CGFloat = 40.0
    var footerHeight: CGFloat = 24.0
    var headerHeight: CGFloat = 40.0
    var cellIdentifier: String = "modalPickerCellId"
    var selectedIndex: Int = 0
    var selectedSection: Int = 0
    var sectionHeaderHeight: CGFloat = 26.0
    var sectionFooterHeight: CGFloat = 26.0
    var isScrollEnabled: Bool = false

    var hasCloseItem: Bool = false
    var allowsSelection: Bool = true

    var headerBorderType: BorderType = [.bottom]

    private var sections: [[LocalizableResource<T>]] = []
    private var sectionTitles: [Int: LocalizableResource<String>] = [:]
    private var sectionFooters: [Int: LocalizableResource<String>] = [:]

    var viewModels: [LocalizableResource<T>] {
        get {
            sections.first ?? []
        }

        set {
            sections = [newValue]
        }
    }

    var separatorStyle: UITableViewCell.SeparatorStyle = .none
    var separatorColor: UIColor?
    var separatorInset: UIEdgeInsets?

    weak var delegate: ModalPickerViewControllerDelegate?
    weak var presenter: ModalPresenterProtocol?

    var context: AnyObject?

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        setupLocalization()
    }

    func addSection(viewModels: [LocalizableResource<T>], title: LocalizableResource<String>?) {
        addSection(viewModels: viewModels, title: title, footer: nil)
    }

    func addSection(
        viewModels: [LocalizableResource<T>],
        title: LocalizableResource<String>?,
        footer: LocalizableResource<String>?
    ) {
        sections.append(viewModels)

        let lastSectionIndex = sections.count - 1

        sectionTitles[lastSectionIndex] = title
        sectionFooters[lastSectionIndex] = footer
    }

    func reload() {
        tableView.reloadData()
    }

    private func configure() {
        if let cellNib = cellNib {
            tableView.register(cellNib, forCellReuseIdentifier: cellIdentifier)
        } else {
            tableView.register(C.self, forCellReuseIdentifier: cellIdentifier)
        }

        tableView.registerClassForCell(ModalPickerActionTableViewCell.self)
        tableView.registerHeaderFooterView(withClass: IconTitleHeaderView.self)

        tableView.allowsSelection = allowsSelection
        tableView.separatorStyle = separatorStyle
        tableView.isScrollEnabled = isScrollEnabled

        if let separatorColor = separatorColor {
            tableView.separatorColor = separatorColor
        }

        if let separatorInset = separatorInset {
            tableView.separatorInset = separatorInset
        }

        if let icon = icon {
            headerView.iconImage = icon
        } else {
            headerView.spacingBetweenLabelAndIcon = 0
        }

        if icon != nil || localizedTitle != nil {
            headerHeightConstraint.constant = headerHeight
        } else {
            headerHeightConstraint.constant = .zero
            headerHeight = 0
        }

        headerBackgroundView.borderType = headerBorderType

        if hasCloseItem {
            centerHeader()
            configureCloseItem()
        }
    }

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        headerView.title = localizedTitle?.value(for: locale)
    }

    private func centerHeader() {
        headerView.trailingAnchor.constraint(
            equalTo: headerBackgroundView.trailingAnchor,
            constant: -16.0
        ).isActive = true
    }

    private func configureCloseItem() {
        let closeButton = RoundedButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.roundedBackgroundView?.shadowOpacity = 0.0
        closeButton.roundedBackgroundView?.fillColor = .clear
        closeButton.roundedBackgroundView?.highlightedFillColor = .clear
        closeButton.changesContentOpacityWhenHighlighted = true
        closeButton.imageWithTitleView?.spacingBetweenLabelAndIcon = 0.0
        closeButton.contentInsets = UIEdgeInsets(top: 20.0, left: 20.0, bottom: 20.0, right: 20.0)
        closeButton.imageWithTitleView?.iconImage = R.image.iconClose()

        headerBackgroundView.addSubview(closeButton)

        closeButton.leadingAnchor.constraint(equalTo: headerBackgroundView.leadingAnchor).isActive = true
        closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor).isActive = true

        closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
    }

    // MARK: Table View Delegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 0, actionType.hasAction {
            presenter?.hide(view: self, animated: true) {
                self.delegate?.modalPickerDidSelectAction(context: self.context)
            }
        } else {
            let itemSectionIndex = actionType.hasAction ? indexPath.section - 1 : indexPath.section

            if itemSectionIndex != selectedSection || indexPath.row != selectedIndex {
                if var oldCell = tableView.cellForRow(at: IndexPath(row: selectedIndex, section: 0)) as? C {
                    oldCell.checkmarked = false
                }

                if var newCell = tableView.cellForRow(at: indexPath) as? C {
                    newCell.checkmarked = true
                }

                selectedIndex = indexPath.row
                selectedSection = itemSectionIndex

                presenter?.hide(view: self, animated: true) {
                    if self.sections.count > 1 {
                        self.delegate?.modalPickerDidSelectModel(
                            at: self.selectedIndex,
                            section: self.selectedSection,
                            context: self.context
                        )
                    } else {
                        self.delegate?.modalPickerDidSelectModelAtIndex(
                            self.selectedIndex,
                            context: self.context
                        )
                    }
                }
            }
        }
    }

    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0, actionType.hasAction {
            return actionCellHeight
        } else {
            return cellHeight
        }
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let itemSectionIndex = actionType.hasAction ? section - 1 : section

        if sectionTitles[itemSectionIndex] != nil {
            return sectionHeaderHeight
        } else {
            return 0.0
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let itemSectionIndex = actionType.hasAction ? section - 1 : section

        if let title = sectionTitles[itemSectionIndex] {
            let headerView: IconTitleHeaderView = tableView.dequeueReusableHeaderFooterView()
            headerView.titleView.detailsLabel.apply(style: .footnoteSecondary)

            headerView.bind(title: title.value(for: selectedLocale), icon: nil)

            return headerView
        } else {
            return nil
        }
    }

    func tableView(_: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let itemSectionIndex = actionType.hasAction ? section - 1 : section

        if sectionFooters[itemSectionIndex] != nil {
            return sectionFooterHeight
        } else {
            return 0.0
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let itemSectionIndex = actionType.hasAction ? section - 1 : section

        if let footer = sectionFooters[itemSectionIndex] {
            let footerView: IconTitleHeaderView = tableView.dequeueReusableHeaderFooterView()
            footerView.titleView.detailsLabel.apply(style: .footnoteSecondary)

            footerView.bind(title: footer.value(for: selectedLocale), icon: nil)

            return footerView
        } else {
            return nil
        }
    }

    // MARK: Table View Data Source

    func numberOfSections(in _: UITableView) -> Int {
        actionType.hasAction ? sections.count + 1 : sections.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if actionType.hasAction, section == 0 {
            return 1
        } else {
            let itemSectionIndex = actionType.hasAction ? section - 1 : section

            return sections[itemSectionIndex].count
        }
    }

    // swiftlint:disable force_cast
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0, actionType.hasAction {
            let cell = tableView.dequeueReusableCellWithType(ModalPickerActionTableViewCell.self)!

            switch actionType {
            case .none:
                break
            case let .iconTitle(localizedViewModel):
                let locale = localizationManager?.selectedLocale ?? Locale.current
                let viewModel = localizedViewModel.value(for: locale)
                cell.bind(viewModel: viewModel)
            }

            return cell
        } else {
            var cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! C

            let locale = localizationManager?.selectedLocale ?? Locale.current

            let itemSectionIndex = actionType.hasAction ? indexPath.section - 1 : indexPath.section
            let viewModels = sections[itemSectionIndex]

            cell.bind(model: viewModels[indexPath.row].value(for: locale))
            cell.checkmarked = (selectedSection == itemSectionIndex && selectedIndex == indexPath.row)

            return cell
        }
    }

    // swiftlint:enable force_cast

    @objc private func handleClose() {
        presenter?.hide(view: self, animated: true)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard isScrollEnabled else {
            return
        }
        scrollView.bounces = scrollView.contentOffset.y > UIConstants.bouncesOffset
    }
}

extension ModalPickerViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            headerView.setNeedsLayout()
            tableView.reloadData()
        }
    }
}

extension ModalPickerViewController: ModalPresenterDelegate {
    func presenterDidHide(_: ModalPresenterProtocol) {
        delegate?.modalPickerDidCancel(context: context)
    }
}

extension ModalPickerViewController: ModalSheetPresenterDelegate {
    func presenterCanDrag(_: ModalPresenterProtocol) -> Bool {
        if isScrollEnabled {
            let offset = tableView.contentOffset.y + tableView.contentInset.top
            return offset == 0
        }

        return true
    }
}
