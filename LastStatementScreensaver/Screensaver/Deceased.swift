//
//  Deceased.swift
//  LastStatementScreensaver
//
//  Created by Brad Root on 4/25/20.
//  Copyright © 2020 Brad Root. All rights reserved.
//

import Foundation

struct Deceased: Codable, Equatable {
    let executionNumber: Int
    let firstName: String
    let lastName: String
    let statementLink: URL
    let age: Int
    let date: Date
    let race: String
    let tdcjNumber: Int
    let county: String
    let state: String

    let lastStatement: String

    func getName() -> String {
        return "\(firstName) \(lastName)"
    }

    func getExecutionDateAsString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy"
        return dateFormatter.string(from: date)
    }
}
