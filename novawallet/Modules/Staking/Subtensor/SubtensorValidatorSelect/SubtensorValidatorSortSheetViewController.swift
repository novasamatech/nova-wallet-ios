import UIKit
import UIKit_iOS

final class ValidatorSortSheetViewController: UIViewController {
    private let selected: SubtensorValidatorSort
    private let locale: Locale
    private let allowsApy: Bool
    private let onSelect: (SubtensorValidatorSort) -> Void

    init(
        selected: SubtensorValidatorSort,
        locale: Locale,
        allowsApy: Bool = true,
        onSelect: @escaping (SubtensorValidatorSort) -> Void
    ) {
        self.selected = selected
        self.locale = locale
        self.allowsApy = allowsApy
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = R.color.colorSecondaryScreenBackground()
        sheetPresentationController?.detents = [.medium()]
        sheetPresentationController?.prefersGrabberVisible = true
        sheetPresentationController?.preferredCornerRadius = 20
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let title = UILabel()
        title.text = strings.stakingSubtensorUiPickerSortTitle()
        title.font = .boldTitle3
        title.textColor = R.color.colorTextPrimary()
        let card = UIStackView()
        card.axis = .vertical
        card.layer.cornerRadius = 12
        card.backgroundColor = R.color.colorBlockBackground()
        card.clipsToBounds = true
        let options: [(SubtensorValidatorSort, String)] = (allowsApy ? [
            (.apy, strings.stakingSubtensorUiValidatorSortApy())
        ] : []) + [
            (.totalStaked, strings.stakingSubtensorUiValidatorSortStaked()),
            (.name, strings.stakingSubtensorUiPickerName())
        ]
        for (option, label) in options { card.addArrangedSubview(makeRow(option: option, title: label)) }
        view.addSubview(title)
        view.addSubview(card)
        title.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        card.snp.makeConstraints { make in
            make.top.equalTo(title.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(16)
        }
    }

    private func makeRow(option: SubtensorValidatorSort, title: String) -> UIControl {
        let row = UIControl()
        row.snp.makeConstraints { make in make.height.equalTo(52) }
        let label = UILabel()
        label.text = title
        label.font = .regularBody
        label.textColor = R.color.colorTextPrimary()
        let radio = UIImageView(image: UIImage(systemName: selected == option ? "largecircle.fill.circle" : "circle"))
        radio.tintColor = selected == option ? R.color.colorButtonBackgroundPrimary() : R.color.colorIconSecondary()
        row.addSubview(label)
        row.addSubview(radio)
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
        }
        radio.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(22)
        }
        row.addAction(UIAction { [weak self] _ in
            self?.onSelect(option)
            self?.dismiss(animated: true)
        }, for: .touchUpInside)
        return row
    }
}
