//
//  CurrencyRow.swift
//  novawallet
//
//  Created by Holyberry on 04.08.2022.
//  Copyright © 2022 Nova Foundation. All rights reserved.
//

import UIKit

final class CurrencyRow: UICollectionViewCell {
    typealias Colors = R.color
    typealias Fonts = R.font

    lazy var symbolLabel: BorderedLabelView = .create {
        $0.titleLabel.textAlignment = .center
    }

    lazy var titleLabel: UILabel = .create {
        $0.textColor = Colors.colorWhite100()
        $0.font = Fonts.publicSansRegular(size: 15)
        $0.numberOfLines = 0
    }

    lazy var subtitleLabel: UILabel = .create {
        $0.textColor = Colors.colorWhite64()
        $0.font = Fonts.publicSansRegular(size: 13)
        $0.numberOfLines = 0
    }

    lazy var radioSelectorView = RadioSelectorView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    //TODO: Simplify
    private func setupLayout() {
        let textStackView = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStackView.axis = .vertical
        textStackView.alignment = .leading

        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        subtitleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textStackView.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let mainStackView = UIStackView(arrangedSubviews: [
            symbolLabel,
            textStackView,
            radioSelectorView
        ])
        symbolLabel.setContentHuggingPriority(.required, for: .horizontal)
        symbolLabel.setContentHuggingPriority(.required, for: .vertical)
        symbolLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        symbolLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        radioSelectorView.setContentHuggingPriority(.required, for: .horizontal)
        radioSelectorView.setContentHuggingPriority(.required, for: .vertical)
        radioSelectorView.setContentCompressionResistancePriority(.required, for: .horizontal)
        radioSelectorView.setContentCompressionResistancePriority(.required, for: .vertical)

        mainStackView.spacing = 16
        contentView.addSubview(mainStackView)
        mainStackView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension CurrencyRow {
    struct Model: Hashable {
        let id: Int
        let title: String
        let subtitle: String
        let symbol: String
        let isSelected: Bool
    }

    func render(model: Model) {
        symbolLabel.titleLabel.text = model.symbol
        titleLabel.text = model.title
        subtitleLabel.text = model.subtitle
        radioSelectorView.selected = model.isSelected
    }
}

extension BorderedLabelView {
    override var intrinsicContentSize: CGSize {
        .init(width: 40, height: 28)
    }
}

extension RadioSelectorView {
    override var intrinsicContentSize: CGSize {
        .init(width: 20, height: 20)
    }
}
