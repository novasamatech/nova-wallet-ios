import Foundation
import UIKit

protocol BannersViewDataSourceProtocol {
    func update(with viewModels: [BannerViewModel]?)
    func itemsCount() -> Int
    func getItem(at index: Int) -> BannerViewModel?
    func pageIndex(for itemIndex: Int) -> Int
    func nextShowingItemIndex(after currentItemIndex: Int) -> Int?
    func lastShowingItemIndex() -> Int?
    func firstShowingItemIndex() -> Int?
}

class BannersViewDataSource {
    var viewModels: [BannerViewModel]?

    var looped: Bool {
        viewModels?.count ?? 0 > 1
    }

    var lastIndex: Int? {
        guard let viewModels else { return nil }

        return viewModels.count - 1
    }
}

// MARK: BannersViewDataSourceProtocol

extension BannersViewDataSource: BannersViewDataSourceProtocol {
    func update(with viewModels: [BannerViewModel]?) {
        self.viewModels = viewModels

        guard
            let viewModels,
            looped,
            let first = viewModels.first,
            let last = viewModels.last
        else {
            return
        }

        self.viewModels?.insert(last, at: 0)
        self.viewModels?.append(first)
    }

    func itemsCount() -> Int {
        viewModels?.count ?? 0
    }

    func getItem(at index: Int) -> BannerViewModel? {
        guard let viewModels, viewModels.count > index else {
            return nil
        }

        return viewModels[index]
    }

    func pageIndex(for itemIndex: Int) -> Int {
        guard let viewModels else {
            return 0
        }

        return if looped, itemIndex == 0 {
            viewModels.count - 3
        } else if !looped, itemIndex == 0 || looped, itemIndex == lastIndex {
            0
        } else {
            itemIndex - 1
        }
    }

    func nextShowingItemIndex(after currentItemIndex: Int) -> Int? {
        if looped, currentItemIndex == lastShowingItemIndex() {
            firstShowingItemIndex()
        } else {
            currentItemIndex + 1
        }
    }

    func lastShowingItemIndex() -> Int? {
        guard let viewModels else { return nil }

        return looped ? viewModels.count - 2 : 0
    }

    func firstShowingItemIndex() -> Int? {
        guard let viewModels else { return nil }

        return looped ? 1 : 0
    }
}
