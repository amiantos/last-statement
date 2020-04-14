//
//  LSScene.swift
//  LastStatementScreensaver
//
//  Created by Brad Root on 4/15/20.
//  Copyright © 2020 Brad Root. All rights reserved.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Cocoa
import SpriteKit

public enum NameSize: CaseIterable {
    case small
    case medium
    case large
}

public enum ScreenPosition: CaseIterable {
    case top
    case midTop
    case middle
    case midBottom
    case bottom
}

class LSScene: SKScene, LSManagerDelegate {
    var executions: [Deceased] = [] {
        didSet {
            executions.shuffle()
            slideRandomName()
            beginRandomNameDisplay()
            showInformationDisplayAfterDelay()
        }
    }

    // MARK: Theme Settings

    var infoOverlayTextColor: NSColor = .white
    var slidingNameTextColor: NSColor = .white
    var infoOverlayBackgroundColor: NSColor = .black

    // MARK: Scene Lifecycle

    override func sceneDidLoad() {
        super.sceneDidLoad()

        backgroundColor = .clear
    }

    func updatedSettings() {
        removeAllActions()
        removeAllChildren()
    }

    // MARK: Information Overlay

    var informationDisplayTimer: Timer?

    private func showInformationDisplayAfterDelay() {
        // Using wait actions here instead of timers because timers don't invalidate when preview updates
        let informationDisplayWaitAction = SKAction.wait(forDuration: 10)
        run(informationDisplayWaitAction) {
            self.showInformationDisplay()
        }
    }

    private func showInformationDisplay() {
        guard let deceased = getNextDeceased() else { return }

        let infoDuration = getEstimatedReadingTimeForString(deceased.lastStatement)

        // Create Intro Name Label Node
        let slidingNameLabel = SKLabelNode(text: deceased.getName())
        slidingNameLabel.fontName = "Arial Rounded MT Bold"
        slidingNameLabel.fontSize = frame.size.height / 8
        slidingNameLabel.zPosition = 1
        slidingNameLabel.alpha = 0
        slidingNameLabel.fontColor = slidingNameTextColor
        addChild(slidingNameLabel)

        // Animations
        let yPosition: CGFloat = frame.size.height / 2 + (frame.size.height / 15)
        let xPosition: CGFloat = 0.0 + (slidingNameLabel.frame.width / 2) + (frame.size.width / 10)
        let slideDuration: TimeInterval = max(TimeInterval(frame.size.width / 300), 4)
        let maxAlpha: CGFloat = 0.4

        slidingNameLabel.position = CGPoint(x: frame.size.width + (slidingNameLabel.frame.width / 2), y: yPosition)
        let nameMoveInAction = SKAction.moveTo(x: xPosition, duration: slideDuration)
        let nameFadeInAction = SKAction.fadeAlpha(to: maxAlpha, duration: slideDuration * 0.75)
        nameFadeInAction.timingMode = .easeIn
        nameMoveInAction.timingMode = .easeOut
        let nameMoveInActionGroup = SKAction.group([nameMoveInAction, nameFadeInAction])
        let nameWaitAction = SKAction.wait(forDuration: infoDuration + 4)
        let nameMoveOutAction = SKAction.moveTo(x: 0 - (slidingNameLabel.frame.width / 2), duration: slideDuration)
        nameMoveOutAction.timingMode = .easeIn
        let nameFadeOutAction = SKAction.fadeAlpha(to: 0, duration: slideDuration)
        let nameMoveOutActionGroup = SKAction.group([nameMoveOutAction, nameFadeOutAction])

        let nameActionSequence = SKAction.sequence([nameMoveInActionGroup, nameWaitAction, nameMoveOutActionGroup])

        // Create Background
        let backgroundNode = SKSpriteNode(color: infoOverlayBackgroundColor, size: frame.size)
        backgroundNode.alpha = 0
        backgroundNode.position = CGPoint(x: frame.size.width / 2, y: frame.size.height / 2)
        backgroundNode.zPosition = 2
        addChild(backgroundNode)

        // Animations
        let backgroundInitialWaitAction = SKAction.wait(forDuration: slideDuration)
        let backgroundFadeInAction = SKAction.fadeAlpha(to: 0.8, duration: 1)
        backgroundFadeInAction.timingMode = .easeIn
        let backgroundSecondWaitAction = SKAction.wait(forDuration: infoDuration + 2)
        let backgroundFadeOutAction = SKAction.fadeOut(withDuration: 1)
        let backgroundActionSequence = SKAction.sequence([backgroundInitialWaitAction, backgroundFadeInAction, backgroundSecondWaitAction, backgroundFadeOutAction])

        // Shared attributes
        let infoBaseYPosition = yPosition + (slidingNameLabel.frame.size.height / 8)

        // Shared actions
        let infoWaitAction = SKAction.wait(forDuration: slideDuration)
        let infoFadeInAction = SKAction.fadeAlpha(to: 0.9, duration: 2)
        infoFadeInAction.timingMode = .easeInEaseOut
        let infoWaitDurationAction = SKAction.wait(forDuration: infoDuration - 1)
        let infoFadeOutAction = SKAction.fadeAlpha(to: 0, duration: 2)
        infoFadeOutAction.timingMode = .easeInEaseOut
        let infoActionSequence = SKAction.sequence([infoWaitAction, infoFadeInAction, infoWaitDurationAction, infoFadeOutAction])

        // Info Display Name Label
        let nameLabel = SKLabelNode(text: deceased.getName())
        nameLabel.fontName = "Arial Rounded MT Bold"
        nameLabel.fontSize = max(frame.size.height / 24, 12)
        nameLabel.zPosition = 3
        nameLabel.alpha = 0
        nameLabel.fontColor = infoOverlayTextColor
        addChild(nameLabel)

        let nameXPosition: CGFloat = 0.0 + (nameLabel.frame.width / 2) + (frame.size.width / 8)
        nameLabel.position = CGPoint(x: nameXPosition, y: infoBaseYPosition)

        // Info Display Execution Date
        let executionDateLabel = SKLabelNode(text: "Executed \(deceased.getExecutionDateAsString())")
        executionDateLabel.fontName = "Arial Italic"
        executionDateLabel.fontSize = max(frame.size.height / 60, 6)
        executionDateLabel.numberOfLines = 1
        executionDateLabel.zPosition = 3
        executionDateLabel.alpha = 0
        executionDateLabel.fontColor = infoOverlayTextColor
        addChild(executionDateLabel)

        let executionDateXPosition = 0.0 + (executionDateLabel.frame.width / 2) + (frame.size.width / 8)
        let executionDateYPosition = infoBaseYPosition - (executionDateLabel.frame.height * 1.65)
        executionDateLabel.position = CGPoint(x: executionDateXPosition, y: executionDateYPosition)

        // Info Display Last Statement
        let lastStatementLabel = SKLabelNode(text: deceased.lastStatement)
        lastStatementLabel.fontName = "Arial"
        lastStatementLabel.fontSize = max(frame.size.height / 50, 8)
        lastStatementLabel.lineBreakMode = .byWordWrapping
        lastStatementLabel.numberOfLines = 0
        lastStatementLabel.zPosition = 3
        lastStatementLabel.alpha = 0
        lastStatementLabel.preferredMaxLayoutWidth = frame.size.width * 0.75
        lastStatementLabel.fontColor = infoOverlayTextColor
        addChild(lastStatementLabel)

        while lastStatementLabel.frame.height > (frame.height * 0.4) {
            lastStatementLabel.fontSize -= 1
        }

        let lastStatmentXPosition = 0.0 + (lastStatementLabel.frame.width / 2) + (frame.size.width / 8)
        let lastStatementYPosition = infoBaseYPosition - lastStatementLabel.frame.height - (executionDateLabel.frame.height * 1.5) - nameLabel.frame.height
        lastStatementLabel.position = CGPoint(x: lastStatmentXPosition, y: lastStatementYPosition)

        // Animate
        lastStatementLabel.run(infoActionSequence)
        nameLabel.run(infoActionSequence)
        executionDateLabel.run(infoActionSequence)
        backgroundNode.run(backgroundActionSequence)

        slidingNameLabel.run(nameActionSequence) {
            lastStatementLabel.removeFromParent()
            nameLabel.removeFromParent()
            executionDateLabel.removeFromParent()
            backgroundNode.removeFromParent()
            slidingNameLabel.removeFromParent()
            self.showInformationDisplayAfterDelay()
        }
    }

    // MARK: Floating Name Displays

    var randomNameTimer: Timer?

    private func beginRandomNameDisplay() {
        // Using wait actions here instead of timers because timers don't invalidate when preview updates
        let informationDisplayWaitAction = SKAction.wait(forDuration: max(TimeInterval(frame.size.width / 400), 3))
        run(informationDisplayWaitAction) {
            self.slideRandomName()
            self.beginRandomNameDisplay()
        }
    }

    private func slideRandomName() {
        let size = getRandomNameSize()
        let position = getRandomScreenPosition()

        var fontSize: CGFloat = 0.0
        var slideDuration: TimeInterval = 0
        var maxAlpha: CGFloat = 0.5
        var zPosition: CGFloat = 0

        switch size {
        case .small:
            fontSize = frame.size.height / 8
            slideDuration = max(TimeInterval(frame.size.width / 95), 12)
            maxAlpha = 0.1
            zPosition = -3
        case .medium:
            fontSize = frame.size.height / 6
            slideDuration = max(TimeInterval(frame.size.width / 100), 10)
            maxAlpha = 0.2
            zPosition = -2
        case .large:
            fontSize = frame.size.height / 4
            slideDuration = max(TimeInterval(frame.size.width / 120), 8)
            maxAlpha = 0.3
            zPosition = -1
        }

        // Create SKLabelNode
        let nameNode = SKLabelNode(text: getNextName())
        nameNode.fontName = "Arial Rounded MT Bold"
        nameNode.fontSize = fontSize
        nameNode.zPosition = zPosition
        nameNode.alpha = 0
        nameNode.fontColor = slidingNameTextColor
        addChild(nameNode)

        // Determine vertical position
        var yPosition = frame.size.height / 2
        switch position {
        case .top:
            yPosition = frame.size.height - nameNode.frame.height - (nameNode.frame.height / 8)
        case .midTop:
            yPosition = (frame.size.height * 0.75) - (nameNode.frame.height / 2)
        case .middle:
            yPosition = frame.size.height / 2 - (nameNode.frame.height / 4)
        case .midBottom:
            yPosition = (frame.size.height / 4) + (nameNode.frame.height / 4)
        case .bottom:
            yPosition = 0 + (nameNode.frame.height / 4)
        }

        // Animate and remove
        nameNode.position = CGPoint(x: frame.size.width + (nameNode.frame.width / 2), y: yPosition)

        let moveAction = SKAction.moveTo(x: 0 - (nameNode.frame.width / 2), duration: slideDuration)
        moveAction.timingMode = .easeIn
        let fadeInAction = SKAction.fadeAlpha(to: maxAlpha, duration: slideDuration / 2)
        fadeInAction.timingMode = .easeIn
        let fadeOutAction = SKAction.fadeAlpha(to: 0, duration: slideDuration / 2)
        let fadeGroup = SKAction.sequence([fadeInAction, fadeOutAction])
        let actionGroup = SKAction.group([moveAction, fadeGroup])

        nameNode.run(actionGroup) {
            nameNode.removeFromParent()
        }
    }

    // MARK: - Helpers

    fileprivate func getEstimatedReadingTimeForString(_ string: String) -> TimeInterval {
        let minimumInterval: TimeInterval = 20

        let components = string.components(separatedBy: .whitespacesAndNewlines)
        let words = components.filter { !$0.isEmpty }
        let wordCount = Double(words.count)
        // using 150 wpm for slow readers
        let seconds = (wordCount / 150.0) * 60

        return max(minimumInterval, TimeInterval(seconds))
    }

    // MARK: - Randomization Helpers

    let sizes: [NameSize] = NameSize.allCases.shuffled()
    var positions: [ScreenPosition] = ScreenPosition.allCases.shuffled()

    var currentExecutionIndex: Int = 0
    var currentSizeIndex: Int = 0
    var currentPositionIndex: Int = 0

    fileprivate func getNextName() -> String {
        guard let randomDeceased = getNextDeceased() else {
            return "Error: Deceased Not Found"
        }
        return randomDeceased.getName()
    }

    fileprivate func getNextDeceased() -> Deceased? {
        if executions.count == 0 { return nil }

        if currentExecutionIndex >= (executions.count - 1) {
            currentExecutionIndex = 0
        }

        let deceased = executions[currentExecutionIndex]
        currentExecutionIndex += 1

        return deceased
    }

    fileprivate func getRandomNameSize() -> NameSize {
        if currentSizeIndex >= (sizes.count - 1) {
            currentSizeIndex = 0
        }

        let size = sizes[currentSizeIndex]
        currentSizeIndex += 1

        return size
    }

    fileprivate func getRandomScreenPosition() -> ScreenPosition {
        if currentPositionIndex >= (positions.count - 1) {
            currentPositionIndex = 0
            positions = ScreenPosition.allCases.shuffled()
        }

        let position = positions[currentPositionIndex]
        currentPositionIndex += 1

        return position
    }
}
