import Foundation
import UIKit

protocol BannersViewDataSourceProtocol {
    func update(with viewModels: [BannerViewModel]?)
    func itemsCount() -> Int
    func getItem(at index: Int) -> BannerViewModel?
    func pageIndex(for itemIndex: Int) -> Int
}

class BannersViewDataSource {
    var viewModels: [BannerViewModel]?
    var loopedViewModels: [BannerViewModel]?
}

// MARK: BannersViewDataSourceProtocol

extension BannersViewDataSource: BannersViewDataSourceProtocol {
    func update(with viewModels: [BannerViewModel]?) {
        self.viewModels = viewModels

        guard
            let viewModels,
            viewModels.count > 1,
            let first = viewModels.first,
            let last = viewModels.last
        else {
            loopedViewModels = nil

            return
        }

        loopedViewModels = viewModels

        loopedViewModels?.insert(last, at: 0)
        loopedViewModels?.append(first)
    }
    
    func itemsCount() -> Int {
        loopedViewModels?.count ?? viewModels?.count ?? 0
    }
    
    func getItem(at index: Int) -> BannerViewModel? {
        let actualViewModels: [BannerViewModel] = if let loopedViewModels {
            loopedViewModels
        } else if let viewModels{
            viewModels
        } else {
            []
        }
        
        guard actualViewModels.count > index else { return nil }
        
        return actualViewModels[index]
    }
    
    func pageIndex(for itemIndex: Int) -> Int {
        guard let viewModels, let loopedViewModels else {
            return 0
        }
        
        return if itemIndex == 0 {
            viewModels.count - 1
        } else if itemIndex == loopedViewModels.count - 1 {
            0
        } else {
            itemIndex - 1
        }
    }
}
