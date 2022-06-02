import UIKit
import SoraUI
import SoraFoundation

protocol ModalPickerViewControllerDelegate: AnyObject {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?)
    func modalPickerDidCancel(context: AnyObject?)
    func modalPickerDidSelectAction(context: AnyObject?)
}

extension ModalPickerViewControllerDelegate {
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

    var hasCloseItem: Bool = false
    var allowsSelection: Bool = true

    var headerBorderType: BorderType = [.bottom]

    var viewModels: [LocalizableResource<T>] = []
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

    private func configure() {
        if let cellNib = cellNib {
            tableView.register(cellNib, forCellReuseIdentifier: cellIdentifier)
        } else {
            tableView.register(C.self, forCellReuseIdentifier: cellIdentifier)
        }

        tableView.registerClassForCell(ModalPickerActionTableViewCell.self)

        tableView.allowsSelection = allowsSelection
        tableView.separatorStyle = separatorStyle

        if let separatorColor = separatorColor {
            tableView.separatorColor = separatorColor
        }

        if let separatorInset = separatorInset {
            tableView.separatorInset = separatorInset
        }

        headerHeightConstraint.constant = headerHeight

        if let icon = icon {
            headerView.iconImage = icon
        } else {
            headerView.spacingBetweenLabelAndIcon = 0
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

        if indexPath.row == 0, actionType.hasAction {
            delegate?.modalPickerDidSelectAction(context: context)
            presenter?.hide(view: self, animated: true)
        } else {
            let itemIndex = actionType.hasAction ? indexPath.row - 1 : indexPath.row

            if itemIndex != selectedIndex {
                if var oldCell = tableView.cellForRow(at: IndexPath(row: selectedIndex, section: 0)) as? C {
                    oldCell.checkmarked = false
                }

                if var newCell = tableView.cellForRow(at: indexPath) as? C {
                    newCell.checkmarked = true
                }

                selectedIndex = itemIndex

                presenter?.hide(view: self, animated: true)
                delegate?.modalPickerDidSelectModelAtIndex(itemIndex, context: context)
            }
        }
    }

    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == 0, actionType.hasAction {
            return actionCellHeight
        } else {
            return cellHeight
        }
    }

    // MARK: Table View Data Source

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        actionType.hasAction ? viewModels.count + 1 : viewModels.count
    }

    // swiftlint:disable force_cast
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0, actionType.hasAction {
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

            let itemIndex = actionType.hasAction ? indexPath.row - 1 : indexPath.row
            cell.bind(model: viewModels[itemIndex].value(for: locale))
            cell.checkmarked = (selectedIndex == itemIndex)

            return cell
        }
    }

    // swiftlint:enable force_cast

    @objc private func handleClose() {
        presenter?.hide(view: self, animated: true)
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
