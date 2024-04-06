//
//  ViewController.swift
//  DocumentOutlineCoreData
//
//  Created by Michael Rockhold on 4/4/24.
//

import Cocoa

extension NSViewController {
    var document: Document? {
        if let doc = self.representedObject as? Document {
            return doc
        }
        if let p = self.parent {
            return p.document
        } else {
            return nil
        }
    }

    var dataManager: DataManager? {
        guard let doc = document else {
            return nil
        }
        return doc.dataManager
    }

    var treeController: NSTreeController? {
        return dataManager?.treeController
    }
}
