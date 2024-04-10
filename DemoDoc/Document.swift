//
//  Document.swift
//  DemoDoc
//
//  Created by Michael Rockhold on 4/5/24.
//

import Cocoa
import UniformTypeIdentifiers

class Document: NSPersistentDocument {

    // MARK: TreeController
    // The data source backing the NSOutlineView.
    lazy var treeController: NSTreeController = {
        let tc = NSTreeController()
        tc.childrenKeyPath = "children"
        tc.leafKeyPath = "isLeaf"
        tc.preservesSelection = true
        tc.selectsInsertedObjects = true
        tc.isEditable = true
        tc.managedObjectContext = self.managedObjectContext
        tc.entityName = "Node"
        return tc
    }()

    override class var autosavesInPlace: Bool {
        return true
    }

    override func makeWindowControllers() {
        // Returns the Storyboard that contains the main Document window.
        // Creates a view model required by some of the various view controllers embedded in that window's hierarchy,
        // and injects it into the root view controller
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Document Window Controller")) as! WindowController
        windowController.contentViewController?.representedObject = OutlineViewModel(document: self)
        self.addWindowController(windowController)
    }

    @IBAction
    func importFile(_: AnyObject) {

        guard let ctx = self.managedObjectContext else { fatalError("unexpected error: document has no managed object context") }
        
        // Present an open panel to choose a picture to display in the outline view.
        let openPanel = NSOpenPanel()

        // Find a picture to add.
        openPanel.message = NSLocalizedString("Choose File to Import message", comment: "")
        openPanel.prompt = NSLocalizedString("Open", comment: "")
        openPanel.canCreateDirectories = false
        openPanel.allowedContentTypes = [UTType.propertyList]

        openPanel.begin { (response) in
            guard response == NSApplication.ModalResponse.OK else { return }

            let importer = NodeImporter(importContext: ctx)
            importer.importFile(at: openPanel.url!)
        }
    }

    @IBAction
    func exportToFile(_: AnyObject) {
        // TODO: implement me
    }
}
