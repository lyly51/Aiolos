//
//  PanelTransitionCoordinator.swift
//  Aiolos
//
//  Created by Matthias Tretter on 11/07/2017.
//  Copyright © 2017 Matthias Tretter. All rights reserved.
//

import Foundation
import UIKit


/// This coordinator can be used to animate things alongside the movement of the Panel
public final class PanelTransitionCoordinator {

    public enum Direction {
        case horizontal(context: HorizontalTransitionContext)
        case vertical
    }
    
    private unowned let animator: PanelAnimator

    // MARK: - Properties

    public let direction: Direction
    public var isAnimated: Bool { return self.animator.animateChanges }
    
    // MARK: - Lifecycle

    init(animator: PanelAnimator, direction: Direction) {
        self.animator = animator
        self.direction = direction
    }

    // MARK: - PanelTransitionCoordinator

    public func animateAlongsideTransition(_ animations: @escaping () -> Void, completion: ((UIViewAnimatingPosition) -> Void)? = nil) {
        self.animator.transitionCoordinatorQueuedAnimations.append(Animation(animations: animations, completion: completion))
    }
}

extension PanelTransitionCoordinator.Direction {
    public var context: PanelTransitionCoordinator.HorizontalTransitionContext? {
        switch self {
        case .horizontal(let context):
            return context
        case .vertical:
            return nil
        }
    }
}

extension PanelTransitionCoordinator {

    struct Animation {
        let animations: () -> Void
        let completion: ((UIViewAnimatingPosition) -> Void)?
    }
}

// MARK: - HorizontalTransitionContext

public extension PanelTransitionCoordinator {
    
    final class HorizontalTransitionContext {
        
        private unowned let panel: Panel
        private let originalFrame: CGRect
        private let offset: CGFloat
        private let velocity: CGFloat
        
        // MARK: - Lifecycle
        
        init(panel: Panel, originalFrame: CGRect, offset: CGFloat, velocity: CGFloat) {
            self.panel = panel
            self.originalFrame = originalFrame
            self.offset = offset
            self.velocity = velocity
        }
        
        // MARK: - HorizontalTransitionContext
        
        public func targetPosition(in view: UIView) -> Panel.Configuration.Position {
            let supportedPositions = self.panel.configuration.supportedPositions
            let originalPosition = self.panel.configuration.position
            let threshold = self.horizontalThreshold(in: view)
            
            guard self.projectedDelta > threshold else { return originalPosition }
            
            if self.isMovingTowardsLeadingEdge(in: view) && supportedPositions.contains(.leadingBottom) {
                return .leadingBottom
            }
            
            if self.isMovingTowardsTrailingEdge(in: view) && supportedPositions.contains(.trailingBottom) {
                return .trailingBottom
            }
            
            return originalPosition
        }
        
        public func isMovingPastLeadingEdge(in view: UIView) -> Bool {
            guard self.panel.configuration.position == .leadingBottom else { return false }
            return self.destinationFrame.minX < self.leftEdgeThreshold(in: view)
        }
        
        public func isMovingPastTrailingEdge(in view: UIView) -> Bool {
            guard self.panel.configuration.position == .trailingBottom else { return false }
            return self.destinationFrame.maxX > self.rightEdgeThreshold(in: view)
        }
    }
}

// MARK: - Private

private extension PanelTransitionCoordinator.HorizontalTransitionContext {
    
    var destinationFrame: CGRect {
        return self.panel.view.frame
    }
    
    var projectedOffset: CGFloat {
        return project(velocity, onto: offset)
    }
    
    var projectedDelta: CGFloat {
        let projectedOffset = self.projectedOffset
        let delta = abs(projectedOffset)
        return delta
    }
    
    func isMovingTowardsLeadingEdge(in view: UIView) -> Bool {
        let normalizedProjectedOffset = (view.isRTL ? -1 : 1) * self.projectedOffset
        
        return normalizedProjectedOffset < 0
    }
    
    func isMovingTowardsTrailingEdge(in view: UIView) -> Bool {
        let normalizedProjectedOffset = (view.isRTL ? -1 : 1) * self.projectedOffset
        
        return normalizedProjectedOffset > 0
    }
    
    func horizontalThreshold(in view: UIView) -> CGFloat {
        let midScreen = view.bounds.midX
        return min(abs(midScreen - self.originalFrame.maxX), abs(midScreen - self.originalFrame.minX))
    }
    
    func rightEdgeThreshold(in view: UIView) -> CGFloat {
        return view.bounds.maxX + self.originalFrame.width/3
    }
    
    func leftEdgeThreshold(in view: UIView) -> CGFloat {
        return view.bounds.minX - self.originalFrame.width/3
    }
}

private extension UIView {
    var isRTL: Bool {
        return self.effectiveUserInterfaceLayoutDirection == .rightToLeft
    }
}

// Inspired by: https://medium.com/ios-os-x-development/gestures-in-fluid-interfaces-on-intent-and-projection-36d158db7395
private func project(_ velocity: CGFloat, onto position: CGFloat, decelerationRate: UIScrollView.DecelerationRate = .normal) -> CGFloat {
    let factor = -1 / (1000 * log(decelerationRate.rawValue))
    return position + factor * velocity
}
