//
//  LSFileGrabber.swift
//  LastStatementScreensaver
//
//  Created by Brad Root on 4/17/20.
//  Copyright © 2020 Brad Root. All rights reserved.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.

import SpriteKit

#if os(macOS)
    import Cocoa

    // Step 1: Typealias UIImage to NSImage
    typealias UIImage = NSImage
#endif

class LSFileGrabber {
    let bundle: Bundle

    static let shared: LSFileGrabber = LSFileGrabber()

    init() {
        let bundle = Bundle(for: LSScene.self)
        self.bundle = bundle
    }

    public func getSKTexture(named: String) -> SKTexture? {
        #if os(macOS)
            guard let image = bundle.image(forResource: named) else { return nil }
        #else
            guard let image = UIImage(named: named, in: bundle, compatibleWith: nil) else { return nil }
        #endif
        return SKTexture(image: image)
    }

    public func getExecutionsFile() -> String? {
        guard let file = bundle.path(forResource: "executions", ofType: "json") else { return nil }
        let content = try! String(contentsOfFile: file)
        return content
    }
}
