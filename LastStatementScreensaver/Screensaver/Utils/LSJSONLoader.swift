//
//  LSJSONLoader.swift
//  LastStatementScreensaver
//
//  Created by Brad Root on 4/17/20.
//  Copyright © 2020 Brad Root. All rights reserved.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation

class LSJSONLoader {
    let executionsURL = URL(string: "https://last-statement.s3.amazonaws.com/executions.json")!

    func getExecutionsStringFromRemote(completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            do {
                let executions = try String(contentsOf: self.executionsURL)
                completion(executions)
            } catch {
                completion(nil)
            }
        }
    }

    func getExecutionsStringFromLocal() -> String? {
        return LSFileGrabber().getExecutionsFile()
    }
}
