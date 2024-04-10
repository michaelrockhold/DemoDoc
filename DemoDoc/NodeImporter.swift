//
//  NodeImporter.swift
//  DemoDoc
//
//  Created by Michael Rockhold on 4/2/24.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation
import Cocoa

struct NodeImporter {

    let importContext: NSManagedObjectContext

    // Populate the tree controller from the disk-based dictionary (DataSource.plist).
    func importFile(at url: URL) {
        Task {
            // TODO: refactor to inject Node protocol and its creation into this class
            let node = Node(context: importContext)
            node.type = .root
            node.title = url.lastPathComponent
            node.identifier = UUID().uuidString

            do {
                // Populate the outline view with the .plist file content.
                struct OutlineData: Decodable {
                    let children: [ExternalNode]
                }
                // Decode the top-level children of the outline.
                let plistDecoder = PropertyListDecoder()
                let data = try Data(contentsOf: url)
                let decodedData = try plistDecoder.decode(OutlineData.self, from: data)
                addNodesRecursively(parent: node, children: decodedData.children)
            } catch {
                fatalError("Failed to load URL \(url)")
            }
        }
    }

    private func addNodesRecursively(parent: Node, children: [ExternalNode]) {
        for externalNode in children {
            if externalNode.type == .separator { continue }
            // Recursively add further content from the specified node.
            let node = Node(context: importContext, externalNode: externalNode)
            parent.addToChildrenSet(node)
            addNodesRecursively(parent: node, children: externalNode.children)
        }
    }
}
