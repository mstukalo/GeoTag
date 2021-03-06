//
//  AppDelegate.swift
//  GeoTag (3rd version)
//
//  Created by Marco S Hyman on 6/11/14.
//
// Copyright 2014-2017 Marco S Hyman
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in the
// Software without restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the
// Software, and to permit persons to whom the Software is furnished to do so,
// subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
// AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import Foundation
import AppKit

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate {
    lazy var preferences: Preferences = Preferences()
    lazy var undoManager: UndoManager = UndoManager()

    var modified: Bool {
        get {
            return window.isDocumentEdited
        }
        set {
            window.isDocumentEdited = newValue
        }
    }

    @IBOutlet var window: NSWindow!
    @IBOutlet var tableViewController: TableViewController!
    @IBOutlet var progressIndicator: NSProgressIndicator!

    //MARK: App start up

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        window.delegate = self
        // Pop open a preferences window if a backup (save) folder location hasn't
        // yet been selected
        if Preferences.saveFolder() == nil {
            perform(#selector(openPreferencesWindow(_:)), with: nil, afterDelay: 0)
        }
    }

    //MARK: open panel handling

    /// action bound to File -> Open
    /// - Parameter AnyObject: unused
    ///
    /// Allows selection of image files and/or directories.  If a directory
    /// is selected all files within the directory and any enclosed sub-directories
    /// will be added to the table of images.  The same file can not be added
    /// to the table multiple times.   If duplicates are detected the user
    /// will be alerted that some files were not opened.
    @IBAction func showOpenPanel(_: AnyObject) {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = CGImageSourceCopyTypeIdentifiers() as? [String]
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        if panel.runModal().rawValue == NSFileHandlingPanelOKButton {
            var urls = [URL]()
            for url in panel.urls {
                if !addUrlsInFolder(url: url, toUrls: &urls) {
                    urls.append(url)
                }
            }
            let dups = tableViewController.addImages(urls: urls)
            if dups {
                let alert = NSAlert()
                alert.addButton(withTitle: NSLocalizedString("CLOSE", comment: "Close"))
                alert.messageText = NSLocalizedString("WARN_TITLE", comment: "Files not opened")
                alert.informativeText = NSLocalizedString("WARN_DESC", comment: "Files not opened")
                alert.runModal()
            }
        }
    }

    //MARK: Save image changes (if any)

    @objc func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        guard let action = item.action else { return false }
        switch action {
        case #selector(showOpenPanel(_:)):
            return true
        case #selector(save(_:)):
            return modified
        case #selector(openPreferencesWindow(_:)):
            return true
        default:
            print("default for item \(item)")
        }
        return false
    }

    /// action bound to File -> Save
    /// - Parameter AnyObject: unused
    ///
    /// Save all images with updated geolocation information and clear all
    /// undo actions.
    @IBAction func save(_: AnyObject?) {
        if tableViewController.saveAllImages() {
            modified = false
            undoManager.removeAllActions()
        }
    }

    @IBAction func openPreferencesWindow(_ sender: AnyObject!) {
        preferences.showWindow(sender)
    }

    //MARK: app termination

    func applicationShouldTerminateAfterLastWindowClosed(_ theApplication: NSApplication) -> Bool {
        return true
    }

    /// Give the user a chance to save changes
    /// - Returns: true if all changes have been saved, false otherwise
    ///
    /// Alert the user if there are unsaved geo location changes and allow
    /// the user to save or discard the changes before terminating the
    /// application. The user can also cancel program termination without
    /// saving any changes.
    func saveOrDontSave() -> Bool {
        if modified {
            let alert = NSAlert()
            alert.addButton(withTitle: NSLocalizedString("SAVE",
                                                       comment: "Save"))
            alert.addButton(withTitle: NSLocalizedString("CANCEL",
                                                       comment: "Cancel"))
            alert.addButton(withTitle: NSLocalizedString("DONT_SAVE",
                                                       comment: "Don't Save"))
            alert.messageText = NSLocalizedString("UNSAVED_TITLE",
                                                  comment: "Unsaved Changes")
            alert.informativeText = NSLocalizedString("UNSAVED_DESC",
                                                      comment: "Unsaved Changes")
            alert.beginSheetModal(for: window) {
                (response: NSApplication.ModalResponse) -> Void in
                switch response {
                case NSApplication.ModalResponse.alertFirstButtonReturn:      // Save
                    self.save(nil)
                case NSApplication.ModalResponse.alertSecondButtonReturn:     // Cancel
                    // Close/terminate cancelled
                    return
                default:
                    // Don't bother saving
                    break
                }
                self.modified = false
                self.window.close()
            }
            return false
        }
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if saveOrDontSave() {
            return .terminateNow
        }
        return .terminateCancel
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
}

/// Window delegate functions

extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_: NSWindow) -> Bool {
        return saveOrDontSave()
    }

    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        return undoManager
    }
}
