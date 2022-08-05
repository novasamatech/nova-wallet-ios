//
//  SectionProtocol.swift
//  novawallet
//
//  Created by Holyberry on 05.08.2022.
//  Copyright © 2022 Nova Foundation. All rights reserved.
//

import Foundation

protocol SectionProtocol {
    associatedtype CellModel
    var cells: [CellModel] { get set }
}
