//
//  ContentView.swift
//  LastStatementScraper
//
//  Created by Brad Root on 4/13/20.
//  Copyright © 2020 Brad Root. All rights reserved.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.

import SwiftUI

struct ContentView: View {
    let scraper = Scraper()
    @State private var labelText = ""
    @State private var executions: [Deceased] = []

    @State private var deceasedName: String = ""
    @State private var lastStatement: String = ""

    @State private var nextIndex: Int?

    var body: some View {
        VStack {
            Text("Last Statement Scraper")
                .font(.title)
            Button("Scrape") {
                self.scraper.scrape { status in
                    self.labelText = status
                    if status == "Finished!" {
                        self.executions = self.scraper.executions
                    }
                }
//                self.scraper.scraperDebug()
            }
            Text(labelText)
            Text("Total executions: \(executions.count)")
        }
        .padding(50)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
