//
//  ViewController.swift
//  LastStatementScreensaverDebug
//
//  Created by Brad Root on 4/15/20.
//  Copyright © 2020 Brad Root. All rights reserved.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Cocoa
import ScreenSaver

class ViewController: NSViewController {
    private var saver: LSScreensaverView?
    private var timer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        addScreensaver()
        saver?.startAnimation()
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }

    private func addScreensaver() {
        if let saver = LSScreensaverView(frame: view.frame, isPreview: false) {
            view.addSubview(saver)
            saver.frame.size = view.frame.size
            self.saver = saver
        }
    }
}
