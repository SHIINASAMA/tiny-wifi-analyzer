//
//  ConsoleSplitView.swift
//  WiFi Lens
//
//  Shared Xcode-style resizable bottom console. A persistent status bar always
//  occupies the bottom pane's minimum; dragging the native NSSplitView divider
//  grows the pane and reveals whatever content the caller places under the
//  status bar (for example a log console). Domain-neutral: the caller supplies
//  both panes and owns all strings/state; the controller only moves the divider
//  and never publishes changes from inside NSSplitView delegate callbacks.

import AppKit
import SwiftUI

/// Moves the split divider between "status bar only" and "expanded" extents.
@MainActor
final class ConsolePanelController: NSObject {
    let statusBarHeight: CGFloat
    let topMinimum: CGFloat
    let expandedBottom: CGFloat

    private weak var split: NSSplitView?
    private var didInitialPosition = false

    init(statusBarHeight: CGFloat = 30, topMinimum: CGFloat = 240, expandedBottom: CGFloat = 300) {
        self.statusBarHeight = statusBarHeight
        self.topMinimum = topMinimum
        self.expandedBottom = expandedBottom
    }

    func attach(_ splitView: NSSplitView) {
        split = splitView
        if !didInitialPosition {
            didInitialPosition = true
            let statusHeight = statusBarHeight
            DispatchQueue.main.async { [weak self] in
                self?.setBottomExtent(statusHeight, animate: false)
            }
        }
    }

    func expandLog() {
        setBottomExtent(expandedBottom)
    }

    func collapseLog() {
        setBottomExtent(statusBarHeight)
    }

    func setBottomExtent(_ desired: CGFloat, animate: Bool = true) {
        guard let split else { return }
        let total = split.bounds.height
        let bottom = min(max(desired, statusBarHeight),
                         max(statusBarHeight, total - topMinimum))
        let position = total - bottom
        if animate {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                split.animator().setPosition(position, ofDividerAt: 0)
            }
        } else {
            split.setPosition(position, ofDividerAt: 0)
        }
    }
}

/// Vertical split of `content` (flexible) over `bottom` (status bar + expandable
/// pane). Callers drive expand/collapse through the shared `controller`.
struct ConsoleSplitView<Content: View, Bottom: View>: NSViewRepresentable {
    let content: Content
    let bottom: Bottom
    let controller: ConsolePanelController

    init(content: Content, bottom: Bottom, controller: ConsolePanelController) {
        self.content = content
        self.bottom = bottom
        self.controller = controller
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSSplitView {
        let split = NSSplitView()
        split.isVertical = false
        split.dividerStyle = .thin
        split.delegate = context.coordinator

        let topHost = NSHostingView(rootView: AnyView(content))
        let bottomHost = NSHostingView(rootView: AnyView(bottom))
        topHost.autoresizingMask = [.width, .height]
        bottomHost.autoresizingMask = [.width, .height]

        context.coordinator.topHost = topHost
        context.coordinator.bottomHost = bottomHost
        context.coordinator.split = split
        context.coordinator.controller = controller
        context.coordinator.statusBarHeight = controller.statusBarHeight
        context.coordinator.topMinimum = controller.topMinimum

        split.addArrangedSubview(topHost)
        split.addArrangedSubview(bottomHost)
        split.setHoldingPriority(.defaultLow, forSubviewAt: 0)
        split.setHoldingPriority(.defaultLow, forSubviewAt: 1)

        controller.attach(split)
        return split
    }

    func updateNSView(_ split: NSSplitView, context: Context) {
        context.coordinator.topHost?.rootView = AnyView(content)
        context.coordinator.bottomHost?.rootView = AnyView(bottom)
    }

    final class Coordinator: NSObject, NSSplitViewDelegate {
        weak var topHost: NSHostingView<AnyView>?
        weak var bottomHost: NSHostingView<AnyView>?
        weak var split: NSSplitView?
        weak var controller: ConsolePanelController?
        var statusBarHeight: CGFloat = 30
        var topMinimum: CGFloat = 240

        func splitView(_ splitView: NSSplitView,
                       constrainMinCoordinate proposedMinimumPosition: CGFloat,
                       ofSubviewAt dividerIndex: Int) -> CGFloat {
            dividerIndex == 0 ? topMinimum : proposedMinimumPosition
        }

        func splitView(_ splitView: NSSplitView,
                       constrainMaxCoordinate proposedMaximumPosition: CGFloat,
                       ofSubviewAt dividerIndex: Int) -> CGFloat {
            guard dividerIndex == 0 else { return proposedMaximumPosition }
            return splitView.bounds.height - statusBarHeight
        }
    }
}
