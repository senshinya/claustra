import SwiftUI
import AppKit
import Combine

@main
struct ClaustraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var viewModel: StatusViewModel!
    private var animationTimer: Timer?
    private var currentFrame = 0
    private var runningFrames: [NSImage] = []
    private var sleepingFrame: NSImage!
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Generate cat icon frames
        let generator = CatIconGenerator.shared
        runningFrames = generator.runningFrames()
        sleepingFrame = generator.sleepingFrame()

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = sleepingFrame
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 420)
        popover.behavior = .transient
        popover.delegate = self

        // Create view model and start monitoring
        viewModel = StatusViewModel()
        popover.contentViewController = NSHostingController(
            rootView: StatusMenuView(viewModel: viewModel)
        )

        viewModel.start()

        // Observe status changes for icon animation
        viewModel.$claudeStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.updateAnimation(for: status)
            }
            .store(in: &cancellables)

        // Monitor clicks outside to close popover
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let self = self, self.popover.isShown {
                self.popover.performClose(nil)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel?.stop()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            viewModel.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Activate app to make popover key window
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func updateAnimation(for status: ClaudeStatus) {
        animationTimer?.invalidate()
        animationTimer = nil

        switch status {
        case .working:
            currentFrame = 0
            animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self = self else { return }
                    self.currentFrame = (self.currentFrame + 1) % self.runningFrames.count
                    self.statusItem.button?.image = self.runningFrames[self.currentFrame]
                }
            }

        case .idle:
            statusItem.button?.image = sleepingFrame
            statusItem.button?.appearsDisabled = false

        case .stopped:
            statusItem.button?.image = sleepingFrame
            statusItem.button?.appearsDisabled = true
        }
    }
}
