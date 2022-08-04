//
//  JsonFileRepository.swift
//  novawallet
//
//  Created by Holyberry on 04.08.2022.
//  Copyright © 2022 Nova Foundation. All rights reserved.
//

import Foundation
import RobinHood

class JsonFileRepository<Model> where Model: Decodable {
    func fetch(by url: URL?, defaultValue: Model) -> CompoundOperationWrapper<Model> {
        let fetchOperation = ClosureOperation<Model> {
            guard let jsonUrl = url else {
                return defaultValue
            }

            let data = try Data(contentsOf: jsonUrl)

            return try JSONDecoder().decode(Model.self, from: data)
        }

        return CompoundOperationWrapper(targetOperation: fetchOperation)
    }
}
