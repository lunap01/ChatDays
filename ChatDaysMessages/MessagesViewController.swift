import Foundation
import UIKit
import SwiftUI
import Messages
import os
import CountdownCore

/// Replaces the template's MessagesViewController.swift.
final class MessagesViewController: MSMessagesAppViewController {

    private let log = Logger(subsystem: "com.paul.ChatDays.messages", category: "messages")
    private var host: UIHostingController<AnyView>?
    /// What is currently on screen, so repeated lifecycle callbacks don't rebuild
    /// the view (and wipe what someone has typed into the composer).
    private var shownKey: String?
    /// Created on first use, so live bubbles in the transcript never start StoreKit.
    private lazy var access = AccessStore()
    private lazy var library = LibraryStore()

    // MARK: Lifecycle

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        refresh(conversation, style: presentationStyle)
        // The composer needs room; the compact drawer is tiny.
        if presentationStyle == .compact {
            requestPresentationStyle(.expanded)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refresh(activeConversation, style: presentationStyle)
    }

    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.willTransition(to: presentationStyle)
        refresh(activeConversation, style: presentationStyle)
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
        refresh(activeConversation, style: presentationStyle)
    }

    /// Called when the person taps Send on a message from this extension.
    override func didStartSending(_ message: MSMessage, conversation: MSConversation) {
        super.didStartSending(message, conversation: conversation)
        guard let url = message.url, let payload = try? CountdownPayload(url: url) else { return }
        access.recordSend(payload.id)
        let line = "didStartSending: used \(access.ledger.sentCount) of \(UsageLedger.freeLimit)"
        log.info("\(line, privacy: .public)")
    }

    /// Size of the live bubble in the transcript.
    override func contentSizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: 200)
    }

    // MARK: Rendering

    /// Style raw values: 0 compact, 1 expanded, 2 transcript.
    private func refresh(_ conversation: MSConversation?, style: MSMessagesAppPresentationStyle) {
        if style == .transcript {
            let selected = conversation?.selectedMessage ?? activeConversation?.selectedMessage
            if let url = selected?.url, let payload = try? CountdownPayload(url: url) {
                display(key: "bubble:\(url.absoluteString)",
                        LiveBubbleView(payload: payload) { [weak self] in
                            // Tapping a live bubble opens ChatDays so viewers can make their own.
                            self?.requestPresentationStyle(.expanded)
                        })
            } else {
                display(key: "placeholder", PlaceholderBubble())
            }
        } else {
            display(key: "composer", ComposerView(access: access, library: library) { [weak self] payload in
                self?.insert(payload)
            })
        }
    }

    private func insert(_ payload: CountdownPayload) {
        guard let conversation = activeConversation else { return }
        let message = MessageFactory.make(payload: payload)
        if AccessPolicy.countAtInsert { access.recordSend(payload.id) }
        conversation.insert(message) { [weak self, log] error in
            if let error {
                let line = "insert failed: \(error.localizedDescription)"
                log.error("\(line, privacy: .public)")
                return
            }
            // The message is now in the text field: close ChatDays so the person
            // can read it and tap Send. Next time it opens with a blank form.
            Task { @MainActor [weak self] in
                self?.shownKey = nil
                self?.dismiss()
            }
        }
    }

    private func display<Content: View>(key: String, _ content: Content) {
        guard key != shownKey else { return }
        shownKey = key

        if let host {
            host.willMove(toParent: nil)
            host.view.removeFromSuperview()
            host.removeFromParent()
        }
        let controller = UIHostingController(rootView: AnyView(content))
        controller.view.backgroundColor = .clear
        addChild(controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        controller.didMove(toParent: self)
        host = controller
    }
}
