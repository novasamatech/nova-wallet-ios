import UIKit
import Operation_iOS

final class DiffableDataStore<Section, Row> where Section: Identifiable & Equatable, Row: Identifiable & Equatable {
    typealias SectionId = String
    typealias RowId = String
    typealias Snapshot = NSDiffableDataSourceSnapshot<SectionId, RowId>

    private(set) var rows: [SectionId: [RowId: Row]] = [:]
    private(set) var sections: [SectionId: Section] = [:]

    func row(rowId: RowId, indexPath: IndexPath, snapshot: Snapshot?) -> Row? {
        guard let sectionId = snapshot?.sectionIdentifiers[safe: indexPath.section],
              let sectionRows = rows[sectionId],
              let row = sectionRows[rowId] else {
            return nil
        }

        return row
    }

    func section(sectionNumber: Int, snapshot: Snapshot?) -> Section? {
        guard let sectionId = snapshot?.sectionIdentifiers[sectionNumber],
              let section = sections[sectionId] else {
            return nil
        }

        return section
    }

    func removing(sections removingSections: [SectionId], from snapshot: Snapshot) -> Snapshot {
        var snapshot = snapshot
        snapshot.deleteSections(removingSections)
        removingSections.forEach { sections.removeValue(forKey: $0) }
        return snapshot
    }

    func updating(section updatingSection: Section, rows updatingRows: [Row], in snapshot: Snapshot?) -> Snapshot {
        var snapshot = snapshot ?? Snapshot()
        if let section = sections[updatingSection.identifier] {
            let snapshotUpdates = updatingRows.reduce(into: (
                inserted: [RowId](),
                reloaded: [RowId](),
                model: [RowId: Row]()
            )) {
                if let existingRow = rows[section.identifier]?[$1.identifier] {
                    if existingRow != $1 {
                        $0.reloaded.append(existingRow.identifier)
                    }
                } else {
                    $0.inserted.append($1.identifier)
                }

                $0.model[$1.identifier] = $1
            }

            let removedItems = snapshot
                .itemIdentifiers(inSection: section.identifier)
                .filter { snapshotUpdates.model[$0] == nil }

            if !removedItems.isEmpty {
                snapshot.deleteItems(removedItems)
            }
            if !snapshotUpdates.inserted.isEmpty {
                snapshot.appendItems(snapshotUpdates.inserted, toSection: updatingSection.identifier)
            }
            if !snapshotUpdates.reloaded.isEmpty {
                snapshot.reloadItems(snapshotUpdates.reloaded)
            }
            if section != updatingSection {
                snapshot.reloadSections([section.identifier])
            }
            sections[updatingSection.identifier] = updatingSection
            rows[updatingSection.identifier] = snapshotUpdates.model
        } else {
            sections[updatingSection.identifier] = updatingSection
            rows[updatingSection.identifier] = updatingRows.reduce(into: [RowId: Row]()) {
                $0[$1.identifier] = $1
            }
            snapshot.appendSections([updatingSection.identifier])
            snapshot.appendItems(updatingRows.map(\.identifier), toSection: updatingSection.identifier)
        }

        return snapshot
    }
}
