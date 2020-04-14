//
//  Scraper.swift
//  LastStatementScraper
//
//  Created by Brad Root on 4/13/20.
//  Copyright © 2020 Brad Root. All rights reserved.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import SwiftSoup

struct Deceased: Codable {
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
}

class Scraper {
    let baseURL = "https://www.tdcj.texas.gov/death_row/"
    var executions: [Deceased] = []
    let json: String = ""

    let debugMode: Bool = false

    func scraperDebug() {
//        let document = getDocumentFromURL(URL(string: "https://www.tdcj.texas.gov/death_row/dr_info/whitakergeorgelast.html")!)!
//        print(document)

        // https://www.tdcj.texas.gov/death_row/dr_info/cardenasrubenlast.html
        // https://www.tdcj.texas.gov/death_row/dr_info/pruettrobertlast.html

        debugPrint(getLastStatementFromURL(URL(string: "https://www.tdcj.texas.gov/death_row/dr_info/cardenasrubenlast.html")!))
        debugPrint(getLastStatementFromURL(URL(string: "https://www.tdcj.texas.gov/death_row/dr_info/pruettrobertlast.html")!))
    }

    func scrape(completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .background).async {
            completion("Starting process...")

            guard let executionsURL = URL(string: "\(self.baseURL)dr_executed_offenders.html") else {
                return completion("URL not found.")
            }

            guard let tableContent = self.getExecutionRowsFromURL(executionsURL) else {
                return completion("Error: Could not parse URL")
            }

            let limit = 5
            var processed = 0

            for row in tableContent {
                if row.count < 10 { continue }

                if self.debugMode, processed >= limit { break }

                guard let deceased = self.convertRowToDeceased(row) else { continue }
                completion("Processing execution #\(deceased.executionNumber)")
                self.executions.append(deceased)

                processed += 1
            }

            completion("Finished!")

            let jsonEncoder = JSONEncoder()
            jsonEncoder.outputFormatting = .prettyPrinted
            jsonEncoder.keyEncodingStrategy = .convertToSnakeCase

            let jsonData = try! jsonEncoder.encode(self.executions)
            let jsonString = String(data: jsonData, encoding: .utf8)!

            print(jsonString)
        }
    }

    private func getDocumentFromURL(_ url: URL) -> Document? {
        do {
            // We add these BREAK and PARAGRAPHS to parse in formatting after turing into text.
            let html = try String(contentsOf: url)
            return try SwiftSoup.parse(html)
        } catch {
            print("Error: \(error.localizedDescription)")
            return nil
        }
    }

    private func getTextFromDocument(_ doc: Document) -> String? {
        do {
            doc.outputSettings(OutputSettings().prettyPrint(pretty: false))
            try doc.select("br").after("\n")
            try doc.select("p").before("\n")
            let text = try doc.html().replacingOccurrences(of: "\\\\n", with: "\n")
            let cleanText = try SwiftSoup.clean(text, "", Whitelist.none(), OutputSettings().prettyPrint(pretty: false))
            return cleanText
        } catch {
            print("Error: \(error.localizedDescription)")
            return nil
        }
    }

    private func getExecutionRowsFromURL(_ url: URL) -> [[Element]]? {
        do {
            guard let document = getDocumentFromURL(url) else {
                return nil
            }
            var tableContent = [[Element]]()
            for row in try document.select("table tr") {
                var rowContent = [Element]()
                for col in try row.select("td") {
                    rowContent.append(col)
                }
                tableContent.append(rowContent)
            }

            return tableContent
        } catch {
            print("Error: \(error.localizedDescription)")
            return nil
        }
    }

    private func convertRowToDeceased(_ row: [Element]) -> Deceased? {
        do {
            // Get basic info
            let executionNumber = Int(try row[0].text())!
            let firstName = try row[4].text()
            let lastName = try row[3].text()
            let age = Int(try row[6].text())!
            let race = try row[8].text()
            let tdcjNumber = Int(try row[5].text())!
            let county = try row[9].text()
            let state = "Texas"

            // Get date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "M/d/yyyy"
            let date = dateFormatter.date(from: try row[7].text())!

            // Get links
            let statementLink = URL(string: "\(baseURL)\(try row[2].select("a[href]").attr("href"))")!

            // Get info and last statement
            var lastStatement = getLastStatementFromURL(statementLink)
            if lastStatement == "This offender declined to make a last statement." {
                lastStatement = "\(firstName) \(lastName) declined to make a last statement."
            }

            return Deceased(
                executionNumber: executionNumber,
                firstName: firstName,
                lastName: lastName,
                statementLink: statementLink,
                age: age,
                date: date,
                race: race,
                tdcjNumber: tdcjNumber,
                county: county,
                state: state,
                lastStatement: lastStatement
            )
        } catch {
            print("Error: \(error.localizedDescription)")
            return nil
        }
    }

    private func getLastStatementFromURL(_ url: URL) -> String {
        if url.absoluteString == "https://www.tdcj.texas.gov/death_row/dr_info/no_last_statement.html" {
            return "This offender declined to make a last statement."
        }

        guard let document = getDocumentFromURL(url) else {
            return ""
        }

        guard let text = getTextFromDocument(document) else { return "" }
        guard let statement = text.slice(from: "Last Statement:", to: "Employee Resources") else { return "" }
        let trimmedText = statement.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitzedText = trimmedText
            .replacingOccurrences(of: "\\n\\s+", with: "\n", options: [.regularExpression])
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
        return sanitzedText
    }
}

extension String {
    func slice(from: String, to: String) -> String? {
        guard let rangeFrom = range(of: from)?.upperBound else { return nil }
        guard let rangeTo = self[rangeFrom...].range(of: to)?.lowerBound else { return nil }
        return String(self[rangeFrom ..< rangeTo])
    }
}
