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
        // Create background gradient
        wantsLayer = true
        let layer = CAGradientLayer()
        layer.frame = frame
        // Default Theme
//        layer.colors = [
//            CGColor(red: 0 / 255, green: 124 / 255, blue: 183 / 255, alpha: 1),
//            CGColor(red: 57 / 255, green: 198 / 255, blue: 241 / 255, alpha: 1),
//        ]
        // Dark Mode
        layer.colors = [
            CGColor(red: 0.149, green: 0, blue: 0, alpha: 1.0), /* #7c0000 */
            CGColor(red: 0.2078, green: 0, blue: 0, alpha: 1.0), /* #350000 */
        ]
        layer.startPoint = CGPoint(x: 1, y: 0)
        layer.endPoint = CGPoint(x: 0, y: 1)
        layer.needsDisplayOnBoundsChange = true
        self.layer = layer
        self.layer?.setNeedsDisplay()

        // Create sprite view if needed
        if spriteView == nil {
            let spriteView = SKView(frame: frame)
            spriteView.ignoresSiblingOrder = true
            spriteView.preferredFramesPerSecond = 60
            spriteView.allowsTransparency = true
            lastStatementScene = LSScene(size: frame.size)
            self.spriteView = spriteView
            addSubview(spriteView)

            lastStatementScene?.isUserInteractionEnabled = true

            // MARK: - Set up theme

            lastStatementScene?.infoOverlayTextColor = .white
            lastStatementScene?.slidingNameTextColor = .black
            lastStatementScene?.infoOverlayBackgroundColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.5)

            spriteView.presentScene(lastStatementScene)
        }

        // Let's get started
        super.startAnimation()
    }

    override func stopAnimation() {
        super.stopAnimation()
        spriteView = nil
    }
}
