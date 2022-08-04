//
//  UIView+create.swift
//  novawallet
//
//  Created by Holyberry on 04.08.2022.
//  Copyright © 2022 Nova Foundation. All rights reserved.
//

import UIKit

public extension UIView {
    static func create<View: UIView>(with mutation: (View) -> Void) -> View {
        let view = View()
        mutation(view)
        return view
    }
}
