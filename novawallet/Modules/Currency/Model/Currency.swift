//
//  Currency.swift
//  novawallet
//
//  Created by Holyberry on 04.08.2022.
//  Copyright © 2022 Nova Foundation. All rights reserved.
//

import Foundation

struct Currency: Codable {
    let id: Int
    let code: String
    let name: String
    let symbol: String?
    let category: Category
    let isPopular: Bool
    let coingeckoId: String

    enum CodingKeys: String, CodingKey {
        case id
        case code
        case name
        case symbol
        case category
        case isPopular = "popular"
        case coingeckoId
    }
}

extension Currency {
    enum Category: String, Codable {
        case fiat
        case crypto
    }
}
