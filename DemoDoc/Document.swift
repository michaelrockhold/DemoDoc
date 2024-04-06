//
//  Document.swift
//  DemoDoc
//
//  Created by Michael Rockhold on 4/5/24.
//

import Cocoa
import UniformTypeIdentifiers

class Document: NSPersistentDocument {

    let dataManager: DataManager

    override init() {
        dataManager = DataManager()
        super.init()
    }

    override class var autosavesInPlace: Bool {
        return true
    }

    override func makeWindowControllers() {
        // Returns the Storyboard that contains your Document window.
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Document Window Controller")) as! NSWindowController
        self.addWindowController(windowController)
    }

    @IBAction
    func importFile(_: AnyObject) {
        // Present an open panel to choose a picture to display in the outline view.
        let openPanel = NSOpenPanel()

        // Find a picture to add.
        openPanel.message = NSLocalizedString("Choose File to Import message", comment: "")
        openPanel.prompt = NSLocalizedString("open panel prompt", comment: "")
        openPanel.canCreateDirectories = false
        openPanel.allowedContentTypes = [UTType.propertyList]

        openPanel.begin { (response) in
            guard response == NSApplication.ModalResponse.OK else { return }

            self.dataManager.importFile(at: openPanel.url!)
        }
    }

    @IBAction
    func exportToFile(_: AnyObject) {
    }
}
