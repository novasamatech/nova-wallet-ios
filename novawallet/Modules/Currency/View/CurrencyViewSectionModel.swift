//
//  CurrencyViewSectionModel.swift
//  novawallet
//
//  Created by Holyberry on 05.08.2022.
//  Copyright © 2022 Nova Foundation. All rights reserved.
//

import Foundation

struct CurrencyViewSectionModel: Hashable, SectionProtocol {
    typealias CellModel = CurrencyCollectionViewCell.Model

    var title: String
    var cells: [CellModel]
}
