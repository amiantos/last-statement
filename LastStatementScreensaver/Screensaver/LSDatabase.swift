//
//  LSDatabase.swift
//  LastStatementScreensaver
//
//  Created by Brad Root on 4/25/20.
//  Copyright © 2020 Brad Root. All rights reserved.
//

import SpriteKit

extension SKColor {
    static let defaultBackgroundColor = SKColor(red: 53 / 255.0, green: 164 / 255.0, blue: 212 / 255.0, alpha: 1.00)
    static let lightTextColor = SKColor.white
    static let darkTextColor = SKColor.black
}

struct LSDatabase {
    fileprivate enum Key {
        static let backgroundColor = "lastStatementBackgroundColor"
        static let textColor = "lastStatementTextColor"
        static let lastSyncTime = "lastStatementLastSyncTime"
        static let executionJSON = "lastStatementExecutionJSON"
    }

    static var standard: UserDefaults {
        var database = UserDefaults.standard
        if let customDatabase = UserDefaults(suiteName: "net.amiantos.LastStatementScreensaverSettings") {
            database = customDatabase
        }
        database.register(defaults:
            [Key.backgroundColor: archiveData(SKColor.defaultBackgroundColor),
             Key.textColor: archiveData(SKColor.lightTextColor),
             Key.lastSyncTime: Date(timeIntervalSince1970: 0),
             Key.executionJSON: ""]
        )
        return database
    }
}

extension UserDefaults {
    var textColor: SKColor {
        return unarchiveColor(data(forKey: LSDatabase.Key.textColor)!)
    }

    func set(textColor: SKColor) {
        set(archiveData(textColor), for: LSDatabase.Key.textColor)
    }

    var backgroundColor: SKColor {
        return unarchiveColor(data(forKey: LSDatabase.Key.backgroundColor)!)
    }

    func set(backgroundColor: SKColor) {
        set(archiveData(backgroundColor), for: LSDatabase.Key.backgroundColor)
    }

    var lastSyncTime: Date {
        return object(forKey: LSDatabase.Key.lastSyncTime) as! Date
    }

    func set(lastSyncTime: Date) {
        set(lastSyncTime, for: LSDatabase.Key.lastSyncTime)
    }

    var executionJSON: String {
        return string(forKey: LSDatabase.Key.executionJSON) ?? ""
    }

    func set(executionsJSON: String) {
        set(executionsJSON, for: LSDatabase.Key.executionJSON)
    }
}

private extension UserDefaults {
    func set(_ object: Any?, for key: String) {
        set(object, forKey: key)
        synchronize()
    }
}

private func archiveData(_ data: Any) -> Data {
    do {
        let data = try NSKeyedArchiver.archivedData(withRootObject: data, requiringSecureCoding: false)
        return data
    } catch {
        fatalError("Failed to archive data")
    }
}

private func unarchiveColor(_ data: Data) -> SKColor {
    do {
        let color = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? SKColor
        return color!
    } catch {
        fatalError("Failed to unarchive data")
    }
}
