//
//  AppDelegate.swift
//  SlidePilot
//
//  Created by Pascal Braband on 23.03.20.
//  Copyright © 2020 Pascal Braband. All rights reserved.
//

import Cocoa
import PDFKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Menu Outlets
    @IBOutlet weak var showNotesItem: NSMenuItem!
    
    @IBOutlet weak var notesPositionMenu: NSMenu!
    @IBOutlet weak var notesPositionNoneItem: NSMenuItem!
    @IBOutlet weak var notesPositionRightItem: NSMenuItem!
    @IBOutlet weak var notesPositionLeftItem: NSMenuItem!
    @IBOutlet weak var notesPositionBottomItem: NSMenuItem!
    @IBOutlet weak var notesPositionTopItem: NSMenuItem!
    


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Disable Tabs
        if #available(OSX 10.12, *) {
            NSWindow.allowsAutomaticWindowTabbing = false
        }
        
        // Enable TouchBar
        if #available(OSX 10.12.2, *) {
            NSApplication.shared.isAutomaticCustomizeTouchBarMenuItemEnabled = true
        }
        
        // Count app starts
        AppStartTracker.startup()
        
        // Subscribe to display changes
        DisplayController.subscribeNotesPosition(target: self, action: #selector(notesPositionDidChange(_:)))
        DisplayController.subscribeDisplayNotes(target: self, action: #selector(displayNotesDidChange(_:)))
        
        startup()
    }
    

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    
    
    
    // MARK: - Window Management
    
    var presenterWindowCtrl: PresenterWindowController?
    var presenterWindow: NSWindow?
    var presenterDisplay: PresenterViewController?
    
    var presentationWindowCtrl: PresentationWindowController?
    var presentationWindow: NSWindow?
    var presentationView: PresentationViewController?
    
    
    func startup() {
        presentOpenFileDialog { (fileUrl) in
            setupWindows()
            openFile(url: fileUrl)
        }
    }
    
    
    func setupWindows() {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        
        guard let presenterWindowCtrl = storyboard.instantiateController(withIdentifier: .init(stringLiteral: "PresenterWindow")) as? PresenterWindowController else { return }
        guard let presenterWindow = presenterWindowCtrl.window else { return }
        guard let presenterDisplay = presenterWindowCtrl.contentViewController as? PresenterViewController else { return }
        
        guard let presentationWindowCtrl = storyboard.instantiateController(withIdentifier: .init(stringLiteral: "PresentationWindow")) as?
            PresentationWindowController else { return }
        guard let presentationWindow = presentationWindowCtrl.window else { return }
        guard let presentationView = presentationWindowCtrl.contentViewController as? PresentationViewController else { return }
        
        NSApp.activate(ignoringOtherApps: true)
        
        // Move window to second screen if possible
        if NSScreen.screens.count >= 2 {
            let secondScreen = NSScreen.screens[1]
            presentationWindow.setFrame(secondScreen.visibleFrame, display: true, animate: true)
            presentationWindow.level = .normal
        }
        
        // Setup communication between the two windows
        presenterDisplay.pointerDelegate = presentationView
        
        // Open Presentation Window in fullscreen
        presentationWindow.orderFront(self)
        presentationWindow.toggleFullScreen(self)
        
        // Open Presenter Display
        presenterWindow.makeKeyAndOrderFront(nil)
        
        // Set properties
        self.presenterWindowCtrl = presenterWindowCtrl
        self.presenterWindow = presenterWindow
        self.presenterDisplay = presenterDisplay
        
        self.presentationWindowCtrl = presentationWindowCtrl
        self.presentationWindow = presentationWindow
        self.presentationView = presentationView
    }
    
    
    
    
    // MARK: - Open File
    
    @IBAction func openDocument(_ sender: NSMenuItem) {
        presentOpenFileDialog { (fileUrl) in
            openFile(url: fileUrl)
        }
    }
    
    
    /** Presents the dialog to open a PDF document. */
    func presentOpenFileDialog(completion: (URL) -> ()) {
        let dialog = NSOpenPanel();

        dialog.title = NSLocalizedString("Choose File", comment: "Title for open file panel.");
        dialog.showsResizeIndicator = true
        dialog.showsHiddenFiles = false
        dialog.canChooseFiles = true
        dialog.canChooseDirectories = false
        dialog.canCreateDirectories = false
        dialog.allowsMultipleSelection = false
        dialog.allowedFileTypes = ["pdf"]

        if (dialog.runModal() == .OK) {
            if let result = dialog.url {
                completion(result)
            }
        }
    }
    
    
    /** Opens the PDF document at the given `URL` in both presenter and presentation window. */
    func openFile(url: URL) {
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        guard let pdfDocument = PDFDocument(url: url) else { return }
        
        // Reset page
        PageController.selectPage(at: 0, sender: self)
        
        // Reset display options
        DisplayController.setNotesPosition(.none, sender: self)
        DisplayController.setDisplayNotes(false, sender: self)
        
        // Open document
        DocumentController.setDocument(pdfDocument, sender: self)
    }
    
    
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        openFile(url: URL(fileURLWithPath: filename))
        return true
    }
    
    
    
    // MARK: - Handling Slides
    
    @IBAction func previousSlide(_ sender: NSMenuItem) {
        PageController.previousPage(sender: self)
    }
    
    
    @IBAction func nextSlide(_ sender: NSMenuItem) {
        PageController.nextPage(sender: self)
    }
    
    
    @IBAction func selectNotesPositionNone(_ sender: NSMenuItem) {
        // Publish changed notes position
        DisplayController.setNotesPosition(.none, sender: self)
    }
    
    
    @IBAction func selectNotesPositionRight(_ sender: NSMenuItem) {
        // Publish changed notes position
        DisplayController.setNotesPosition(.right, sender: self)
    }
    
    
    @IBAction func selectNotesPositionLeft(_ sender: NSMenuItem) {
        // Publish changed notes position
        DisplayController.setNotesPosition(.left, sender: self)
    }
    
    
    @IBAction func selectNotesPositionBottom(_ sender: NSMenuItem) {
        // Publish changed notes position
        DisplayController.setNotesPosition(.bottom, sender: self)
    }
    
    
    @IBAction func selectNotesPositionTop(_ sender: NSMenuItem) {
        // Publish changed notes position
        DisplayController.setNotesPosition(.top, sender: self)
    }
    
    
    @IBAction func displayWhiteScreen(_ sender: NSMenuItem) {
        // Uncheck other item
        if let whiteScreenItem = sender.menu?.items.first(where: { $0.identifier == NSUserInterfaceItemIdentifier(rawValue: "DisplayBlackScreen") }) {
            whiteScreenItem.state = .off
        }
        
        guard let isCovered = presentationView?.pageView.isCoveredWhite else { return }
        
        // Cover or uncover
        if isCovered {
            presentationView?.pageView.uncover()
            sender.state = .off
        } else {
            presentationView?.pageView.coverWhite()
            sender.state = .on
        }
    }
    
    
    @IBAction func displayBlackScreen(_ sender: NSMenuItem) {
        // Uncheck other item
        if let whiteScreenItem = sender.menu?.items.first(where: { $0.identifier == NSUserInterfaceItemIdentifier(rawValue: "DisplayWhiteScreen") }) {
            whiteScreenItem.state = .off
        }
        
        guard let isCovered = presentationView?.pageView.isCoveredBlack else { return }
        
        // Cover or uncover
        if isCovered {
            presentationView?.pageView.uncover()
            sender.state = .off
        } else {
            presentationView?.pageView.coverBlack()
            sender.state = .on
        }
    }
    
    
    @IBAction func showNotes(_ sender: NSMenuItem) {
        DisplayController.switchDisplayNotes(sender: sender)
    }
    
    
    
    
    // MARK: - Control Handlers
    
    @objc func notesPositionDidChange(_ notification: Notification) {
        // Turn off all items in notes position menu
        notesPositionMenu.items.forEach({ $0.state = .off })
        
        // Set correct menu item identifier for notes position
        switch DisplayController.notesPosition {
        case .none:
            notesPositionNoneItem.state = .on
        case .right:
            notesPositionRightItem.state = .on
        case .left:
            notesPositionLeftItem.state = .on
        case .bottom:
            notesPositionBottomItem.state = .on
        case .top:
            notesPositionTopItem.state = .on
        }
    }
    
    
    @objc func displayNotesDidChange(_ notification: Notification) {
        // Set correct state for display notes menu item
        showNotesItem.state = DisplayController.displayNotes ? .on : .off
        
        
        // Select notes position right by default when displaying notes
        // Only if notes are displayed currently and current note position is none
        if DisplayController.displayNotes, DisplayController.notesPosition == .none {
            DisplayController.setNotesPosition(.right, sender: self)
        }
        
        // Enable selecting notes position none when notes ARE NOT displayed
        // Disable selecting notes position none when notes ARE displayed
        notesPositionNoneItem.isEnabled = !DisplayController.displayNotes
    }
}
