import Foundation
import UIKit

protocol BannersViewDataSourceProtocol {
    var lastIndex: Int? { get }
    var firstIndex: Int? { get }
    var lastShowingItemIndex: Int? { get }
    var firstShowingItemIndex: Int? { get }
    var multipleBanners: Bool { get }

    func numberOfItems() -> Int
    func numberOfPages() -> Int

    func update(with viewModels: [BannerViewModel]?)
    func getItem(at index: Int) -> BannerViewModel?
    func pageIndex(for itemIndex: Int) -> Int
}

final class BannersViewDataSource {
    private var viewModels: [BannerViewModel]?

    private var looped: Bool {
        viewModels?.count ?? 0 > 1
    }

    var multipleBanners: Bool {
        looped
    }

    var lastIndex: Int? {
        guard let viewModels else { return nil }

        return viewModels.count - 1
    }

    var firstIndex: Int? {
        guard viewModels != nil else { return nil }

        return 0
    }

    var lastShowingItemIndex: Int? {
        guard let viewModels else { return nil }

        return looped ? viewModels.count - 2 : 0
    }

    var firstShowingItemIndex: Int? {
        guard let viewModels else { return nil }

        return looped ? 1 : 0
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

    func numberOfItems() -> Int {
        viewModels?.count ?? 0
    }

    func numberOfPages() -> Int {
        guard let viewModels else { return 0 }

        return looped ? viewModels.count - 2 : viewModels.count
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
}
