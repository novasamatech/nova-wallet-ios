import Foundation

extension Array where Element: SectionProtocol {
    mutating func updateCells(mutation: (inout Element.CellModel) -> Void) {
        for (sectionIndex, var section) in enumerated() {
            for (cellIndex, var cell) in section.cells.enumerated() {
                mutation(&cell)
                section.cells[cellIndex] = cell
            }
            self[sectionIndex] = section
        }
    }
}
