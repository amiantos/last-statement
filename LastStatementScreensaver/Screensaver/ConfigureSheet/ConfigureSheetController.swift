//
//  ConfigureSheetController.swift
//  Life Saver Screensaver
//
//  Created by Brad Root on 5/21/19.
//  Copyright © 2019 Brad Root. All rights reserved.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Cocoa
import SpriteKit

final class ConfigureSheetController: NSObject {
    private let manager = LSManager()

    // MARK: - Config Actions and Outlets

    @IBOutlet var window: NSWindow?

    @IBOutlet var textColorControl: NSSegmentedControl!
    @IBAction func textColorAction(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 1:
            manager.setTextColor(SKColor.lightTextColor)
        default:
            manager.setTextColor(SKColor.darkTextColor)
        }
    }

    @IBOutlet var lastSyncTimeLabel: NSTextField!

    @IBOutlet var backgroundColorWell: NSColorWell!

    @IBAction func backgroundColorAction(_ sender: NSColorWell) {
        let color = sender.color as NSColor
        // Ensure color is in the right colorspace
        if let normalizedCGColor = color.cgColor.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil),
            let normalizedSKColor = SKColor(cgColor: normalizedCGColor) {
            manager.setBackgroundColor(normalizedSKColor)
        }
    }

    @IBAction func syncNowAction(_ sender: NSButton) {
        syncProgressIndicator.startAnimation(sender)
        manager.updateLocalExecutionStorage {
            self.syncProgressIndicator.stopAnimation(sender)
            self.updateSyncLabel()
        }
    }

    @IBOutlet var syncProgressIndicator: NSProgressIndicator!

    @IBAction func twitterAction(_: NSButton) {
        LSURLType.twitter.open()
    }

    @IBAction func gitHubAction(_: NSButton) {
        LSURLType.github.open()
    }

    @IBAction func bradAction(_: NSButton) {
        LSURLType.brad.open()
    }

    @IBAction func websiteAction(_: NSButton) {
        LSURLType.website.open()
    }

    @IBAction func closeConfigureSheet(sender _: AnyObject) {
        guard let window = window else { return }
        window.sheetParent?.endSheet(window)
    }

    // MARK: - View Setup

    override init() {
        super.init()
        let myBundle = Bundle(for: ConfigureSheetController.self)
        myBundle.loadNibNamed("ConfigureSheet", owner: self, topLevelObjects: nil)

        loadSettings()
    }

    fileprivate func loadSettings() {
        backgroundColorWell.color = manager.backgroundColor

        let textColor = manager.textColor
        if textColor == SKColor.lightTextColor {
            textColorControl.selectedSegment = 1
        } else {
            textColorControl.selectedSegment = 0
        }

        updateSyncLabel()
    }

    fileprivate func updateSyncLabel() {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        lastSyncTimeLabel.stringValue = "Last Update: \(df.string(from: manager.lastSyncTime))"
    }
}
