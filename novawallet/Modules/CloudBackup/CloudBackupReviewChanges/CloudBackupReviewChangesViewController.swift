import UIKit
import Foundation_iOS
import UIKit_iOS

final class CloudBackupReviewChangesViewController: UIViewController, ViewHolder {
    typealias RootViewType = CloudBackupReviewChangesViewLayout

    typealias DataSource =
        UICollectionViewDiffableDataSource<CloudBackupReviewSectionViewModel, CloudBackupReviewItemViewModel>

    let presenter: CloudBackupReviewChangesPresenterProtocol

    private lazy var dataSource = createDataSource()

    init(presenter: CloudBackupReviewChangesPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = CloudBackupReviewChangesViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupCollectionView()
        setupHandlers()
        setupLocalization()

        presenter.setup()
    }

    private func setupHandlers() {
        rootView.applyButton.addTarget(
            self,
            action: #selector(actionApply),
            for: .touchUpInside
        )

        rootView.notNowButton.addTarget(
            self,
            action: #selector(actionNotNow),
            for: .touchUpInside
        )
    }

    private func setupCollectionView() {
        rootView.collectionView.dataSource = dataSource

        rootView.collectionView.registerCellClass(CloudBackupReviewChangesCell.self)
        rootView.collectionView.registerClass(
            RoundedIconTitleCollectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )
    }

    private func createDataSource() -> DataSource {
        let dataSource = DataSource(
            collectionView: rootView.collectionView,
            cellProvider: { [weak self] collectionView, indexPath, model -> UICollectionViewCell? in
                guard let self else {
                    return nil
                }

                let cell: CloudBackupReviewChangesCell? = collectionView.dequeueReusableCell(for: indexPath)

                cell?.bind(viewModel: model, locale: selectedLocale)

                return cell
            }
        )

        dataSource.supplementaryViewProvider = { [weak self] collectionView, _, indexPath in
            guard let headerModel = self?
                .dataSource
                .snapshot()
                .sectionIdentifiers[indexPath.section]
                .header else {
                return nil
            }

            let header: RoundedIconTitleCollectionHeaderView? = collectionView.dequeueReusableSupplementaryView(
                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                for: indexPath
            )
            header?.bind(viewModel: .init(title: headerModel.title, icon: headerModel.icon))
            header?.contentInsets = .init(top: 16, left: 0, bottom: 8, right: 0)
            return header
        }

        return dataSource
    }

    private func setupLocalization() {
        rootView.notNowButton.imageWithTitleView?.title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonNotNow()

        rootView.applyButton.imageWithTitleView?.title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonApply()

        rootView.header.valueTop.text = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.cloudBackupReviewTitle()

        rootView.header.valueBottom.attributedText = NSAttributedString.coloredItems(
            [
                R.string(preferredLanguages: selectedLocale.rLanguages).localizable.cloudBackupReviewEnsurePassphrase()
            ],
            formattingClosure: { items in
                R.string(preferredLanguages: selectedLocale.rLanguages).localizable.cloudBackupReviewSubtitle(
                    items[0]
                )
            },
            color: R.color.colorTextPrimary()!
        )
    }

    @objc func actionNotNow() {
        presenter.activateNotNow()
    }

    @objc func actionApply() {
        presenter.activateApply()
    }
}

extension CloudBackupReviewChangesViewController: CloudBackupReviewChangesViewProtocol {
    func didReceive(viewModels: [CloudBackupReviewSectionViewModel]) {
        rootView.showHeader = { section in
            viewModels[section].header != nil
        }

        dataSource.apply(viewModels)
    }
}

extension CloudBackupReviewChangesViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension CloudBackupReviewChangesViewController {
    static func estimateHeight(for sections: Int, items: Int) -> CGFloat {
        CloudBackupReviewChangesViewLayout.estimateHeight(for: sections, items: items)
    }
}

extension CloudBackupReviewChangesViewController: ModalPresenterDelegate {
    func presenterShouldHide(_: ModalPresenterProtocol) -> Bool {
        false
    }

    func presenterDidHide(_: ModalPresenterProtocol) {}
}
