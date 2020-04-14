//
//  LSScreensaverView.swift
//  LastStatementScreensaver
//
//  Created by Brad Root on 4/14/20.
//  Copyright © 2020 Brad Root. All rights reserved.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.

import ScreenSaver
import SpriteKit

class LSScreensaverView: ScreenSaverView {
    var spriteView: SKView?
    var lastStatementScene: LSScene?

    lazy var sheetController: ConfigureSheetController = ConfigureSheetController()

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var frame: NSRect {
        didSet {
            self.spriteView?.frame = frame
        }
    }

    override var hasConfigureSheet: Bool {
        return true
    }

    override var configureSheet: NSWindow? {
        return sheetController.window
    }

    override func startAnimation() {
        let manager = LSManager()

        // Create background gradient
        wantsLayer = true
        let layer = CAGradientLayer()
        layer.frame = frame

        let primaryBackgroundColor = manager.backgroundColor
        let darkerGradientColor = SKColor(
            calibratedHue: primaryBackgroundColor.hueComponent,
            saturation: primaryBackgroundColor.saturationComponent,
            brightness: max(primaryBackgroundColor.brightnessComponent - 0.3, 0),
            alpha: 1
        ).cgColor
        let middleGradientColor = primaryBackgroundColor.cgColor
        let brighterGradientColor = SKColor(
            calibratedHue: primaryBackgroundColor.hueComponent,
            saturation: primaryBackgroundColor.saturationComponent,
            brightness: min(primaryBackgroundColor.brightnessComponent + 0.3, 1),
            alpha: 1
        ).cgColor
        layer.colors = [darkerGradientColor, middleGradientColor, brighterGradientColor]

        layer.startPoint = CGPoint(x: 0.25, y: 0)
        layer.endPoint = CGPoint(x: 0.75, y: 1)
        layer.needsDisplayOnBoundsChange = true
        self.layer = layer
        self.layer?.setNeedsDisplay()

        // Automatic Updates

        if manager.lastSyncTime.addingTimeInterval(604_800) <= Date() {
            manager.updateLocalExecutionStorage()
        }

        // Create sprite view if needed
        if spriteView == nil {
            let spriteView = SKView(frame: frame)
            spriteView.ignoresSiblingOrder = true
            spriteView.preferredFramesPerSecond = 60
            spriteView.allowsTransparency = true
            lastStatementScene = LSScene(size: frame.size)
            self.spriteView = spriteView
            addSubview(spriteView)

            manager.delegate = lastStatementScene
            lastStatementScene?.isUserInteractionEnabled = false

            // Set up theme
            lastStatementScene?.infoOverlayTextColor = .white
            lastStatementScene?.slidingNameTextColor = manager.textColor
            lastStatementScene?.infoOverlayBackgroundColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.5)

            spriteView.presentScene(lastStatementScene)

            // Load in executions
            DispatchQueue.main.async {
                self.lastStatementScene?.executions = manager.getExecutions()
            }
        }

        // Let's get started
        super.startAnimation()
    }

    override func stopAnimation() {
        super.stopAnimation()
        spriteView = nil
        lastStatementScene?.removeAllActions()
        lastStatementScene?.removeAllChildren()
        lastStatementScene = nil
    }
}
