//
//  Array+SectionProtocol.swift
//  novawallet
//
//  Created by Holyberry on 05.08.2022.
//  Copyright © 2022 Nova Foundation. All rights reserved.
//

import Foundation

extension Array where Element: SectionProtocol {
    mutating func updateCells(mutation: (inout Element.CellModel) -> Void) {
        for (sectionIndex, var section) in enumerated() {
            for (cellIndex, var cellModel) in section.cells.enumerated() {
                mutation(&cellModel)
                section.cells[cellIndex] = cellModel
            }
            self[sectionIndex] = section
        }
    }
}
