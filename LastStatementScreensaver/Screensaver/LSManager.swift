//
//  LSManager.swift
//  LastStatementScreensaver
//
//  Created by Brad Root on 4/25/20.
//  Copyright © 2020 Brad Root. All rights reserved.
//

import Foundation
import SpriteKit

protocol LSManagerDelegate: AnyObject {
    func updatedSettings()
}

final class LSManager {
    let loader = LSJSONLoader()

    weak var delegate: LSManagerDelegate?

    private(set) var textColor: SKColor
    private(set) var backgroundColor: SKColor
    private(set) var executionsJSON: String
    private(set) var lastSyncTime: Date

    init() {
        textColor = LSDatabase.standard.textColor
        backgroundColor = LSDatabase.standard.backgroundColor
        executionsJSON = LSDatabase.standard.executionJSON
        lastSyncTime = LSDatabase.standard.lastSyncTime
    }

    // MARK: Setters

    func setTextColor(_ color: SKColor) {
        LSDatabase.standard.set(textColor: color)
        delegate?.updatedSettings()
    }

    func setBackgroundColor(_ color: SKColor) {
        LSDatabase.standard.set(backgroundColor: color)
        delegate?.updatedSettings()
    }

    func setExecutionsJSON(_ string: String) {
        LSDatabase.standard.set(executionsJSON: string)
        delegate?.updatedSettings()
    }

    // MARK: Getters

    func getExecutions() -> [Deceased] {
        guard let json = getExecutionsJSONString() else { return [] }
        let executions = parseExecutions(json)
        return executions
    }

    // MARK: Helpers

    func updateLocalExecutionStorage(completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .background).async {
            self.loader.getExecutionsStringFromRemote { executionsString in
                guard let executionsString = executionsString else {
                    print("Error: Executions string could not be fetched.")
                    return
                }
                self.setExecutionsJSON(executionsString)
                self.updateLastSyncTime()
                completion?()
            }
        }
    }

    // MARK: Private functions

    private func parseExecutions(_ string: String) -> [Deceased] {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        let jsonData = string.data(using: .utf8)
        guard let data = jsonData else { return [] }
        let executions = try! jsonDecoder.decode([Deceased].self, from: data)
        return executions
    }

    private func getExecutionsJSONString() -> String? {
        if executionsJSON != "" {
            return executionsJSON
        } else if let embeddedExecutions = loader.getExecutionsStringFromLocal() {
            return embeddedExecutions
        } else {
            return nil
        }
    }

    private func updateLastSyncTime() {
        LSDatabase.standard.set(lastSyncTime: Date())
        lastSyncTime = Date()
    }
}
