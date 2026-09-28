import Foundation_iOS
import UIKit

final class SubnetOptionsSheetViewController: UIViewController {
    enum Mode {
        case sort(SubtensorSubnetSort, (SubtensorSubnetSort) -> Void)
        case filters(SubtensorSubnetFilters, (SubtensorSubnetFilters) -> Void)
    }

    private let mode: Mode
    private var draftFilters = SubtensorSubnetFilters()
    private var didInitializeFilters = false
    private let content = UIStackView()

    init(mode: Mode, localizationManager: LocalizationManagerProtocol) {
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
        modalPresentationStyle = .pageSheet
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = R.color.colorSecondaryScreenBackground()
        sheetPresentationController?.detents = [.medium(), .large()]
        sheetPresentationController?.prefersGrabberVisible = true
        sheetPresentationController?.preferredCornerRadius = 20

        content.axis = .vertical
        content.spacing = 16
        view.addSubview(content)
        content.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(18)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        rebuildContent()
    }

    private func rebuildContent() {
        content.arrangedSubviews.forEach { view in
            content.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        switch mode {
        case let .sort(selected, _):
            configureSort(selected: selected)
        case let .filters(initial, _):
            if !didInitializeFilters {
                draftFilters = initial
                didInitializeFilters = true
            }
            configureFilters(initial: draftFilters)
        }
    }

    private func configureSort(selected: SubtensorSubnetSort) {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable
        addTitle(strings.stakingSubtensorUiPickerSortTitle())
        let options: [(SubtensorSubnetSort, String, String)] = [
            (
                .sevenDayChange,
                strings.stakingSubtensorUiPickerSevenDay(),
                strings.stakingSubtensorUiPickerSevenDayDetail()
            ),
            (
                .thirtyDayChange,
                strings.stakingSubtensorUiPickerThirtyDay(),
                strings.stakingSubtensorUiPickerThirtyDayDetail()
            ),
            (.poolDepth, strings.stakingSubtensorUiPickerPoolDepth(), strings.stakingSubtensorUiPickerPoolDetail()),
            (.volume, strings.stakingSubtensorUiPickerVolume(), strings.stakingSubtensorUiPickerVolumeDetail()),
            (.age, strings.stakingSubtensorUiPickerAge(), strings.stakingSubtensorUiPickerAgeDetail()),
            (.name, strings.stakingSubtensorUiPickerName(), strings.stakingSubtensorUiPickerNameDetail())
        ]
        let card = makeCard()
        for (option, title, subtitle) in options {
            let row = makeSortRow(
                title: title,
                subtitle: subtitle,
                selected: option == selected || (selected == .favorites && option == .sevenDayChange)
            )
            row.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                if case let .sort(_, onSelect) = mode { onSelect(option) }
                dismiss(animated: true)
            }, for: .touchUpInside)
            card.addArrangedSubview(row)
        }
    }

    private func configureFilters(initial: SubtensorSubnetFilters) {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable
        draftFilters = initial
        addTitle(strings.stakingSubtensorUiPickerFilters())
        let card = makeCard()
        card.addArrangedSubview(makeFilterRow(
            title: strings.stakingSubtensorUiPickerHideThin(),
            subtitle: strings.stakingSubtensorUiPickerHideThinDetail(),
            isOn: initial.hideThinPools,
            tag: 0
        ))
        card.addArrangedSubview(makeFilterRow(
            title: strings.stakingSubtensorUiPickerAboveAverage(),
            subtitle: strings.stakingSubtensorUiPickerAboveAverageDetail(),
            isOn: initial.onlyAboveThirtyDayAverage,
            tag: 1
        ))
        let apply = TriangularedButton()
        apply.applyEnabledStyle()
        apply.imageWithTitleView?.title = strings.stakingSubtensorUiPickerShow()
        apply.invalidateLayout()
        apply.snp.makeConstraints { $0.height.equalTo(UIConstants.actionHeight) }
        apply.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            if case let .filters(_, onApply) = mode { onApply(draftFilters) }
            dismiss(animated: true)
        }, for: .touchUpInside)
        content.addArrangedSubview(apply)
    }

    private func addTitle(_ title: String) {
        let label = UILabel()
        label.text = title
        label.textColor = R.color.colorTextPrimary()
        label.font = .boldTitle3
        content.addArrangedSubview(label)
    }

    private func makeCard() -> UIStackView {
        let card = UIStackView()
        card.axis = .vertical
        card.backgroundColor = R.color.colorBlockBackground()
        card.layer.cornerRadius = 12
        card.clipsToBounds = true
        content.addArrangedSubview(card)
        return card
    }

    private func makeSortRow(title: String, subtitle: String, selected: Bool) -> UIControl {
        let row = UIControl()
        row.snp.makeConstraints { $0.height.equalTo(55) }
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .regularBody
        titleLabel.textColor = R.color.colorTextPrimary()
        let detailLabel = UILabel()
        detailLabel.text = subtitle
        detailLabel.font = .caption1
        detailLabel.textColor = R.color.colorTextSecondary()
        let radioImage = selected ? UIImage(systemName: "largecircle.fill.circle") : UIImage(systemName: "circle")
        let radio = UIImageView(image: radioImage)
        radio.tintColor = selected ? R.color.colorButtonBackgroundPrimary() : R.color.colorIconSecondary()
        row.addSubview(titleLabel)
        row.addSubview(detailLabel)
        row.addSubview(radio)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.leading.equalToSuperview().offset(16)
            make.trailing.lessThanOrEqualTo(radio.snp.leading).offset(-8)
        }
        detailLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom)
            make.leading.equalTo(titleLabel)
        }
        radio.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(16)
            make.width.height.equalTo(22)
        }
        return row
    }

    private func makeFilterRow(title: String, subtitle: String, isOn: Bool, tag: Int) -> UIView {
        let row = UIView()
        row.snp.makeConstraints { $0.height.equalTo(63) }
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .regularBody
        titleLabel.textColor = R.color.colorTextPrimary()
        let detailLabel = UILabel()
        detailLabel.text = subtitle
        detailLabel.font = .caption1
        detailLabel.textColor = R.color.colorTextSecondary()
        let toggle = UISwitch()
        toggle.isOn = isOn
        toggle.tag = tag
        toggle.onTintColor = R.color.colorButtonBackgroundPrimary()
        toggle.addTarget(self, action: #selector(filterChanged(_:)), for: .valueChanged)
        row.addSubview(titleLabel)
        row.addSubview(detailLabel)
        row.addSubview(toggle)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.leading.equalToSuperview().offset(16)
            make.trailing.lessThanOrEqualTo(toggle.snp.leading).offset(-8)
        }
        detailLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.leading.equalTo(titleLabel)
        }
        toggle.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(16)
        }
        return row
    }

    @objc private func filterChanged(_ sender: UISwitch) {
        if sender.tag == 0 {
            draftFilters.hideThinPools = sender.isOn
        } else {
            draftFilters.onlyAboveThirtyDayAverage = sender.isOn
        }
    }
}

extension SubnetOptionsSheetViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded { rebuildContent() }
    }
}
