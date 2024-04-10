//
//  OutlineViewModel.swift
//  DemoDoc
//
//  Created by Michael Rockhold on 4/8/24.
//

import Foundation
import Cocoa
import CoreData

class OutlineViewModel {

    let managedObjectContext: NSManagedObjectContext
    let treeController: NSTreeController

    init(document: Document) {
        managedObjectContext = document.managedObjectContext!
        treeController = document.treeController
    }

    // Returns a generic node (folder or leaf) from a specified URL.
    public func fileSystemNode(from url: URL) -> Node {
        return Node(context: managedObjectContext, url: url)
    }

    public func newNode(type t: Node.TypeCode, url: URL?, title: String) -> Node {
        return Node(context: managedObjectContext, type: t, url: url, title: title)
    }

    public func newNode(type t: Node.TypeCode, title: Node.Name, identifier: String) -> Node {
        return Node(context: managedObjectContext, type: t, title: title, identifier: identifier)
    }

    public func newNode(type t: Node.TypeCode, title: Node.Name, uuid: NSUUID) -> Node {
        return Node(context: managedObjectContext, type: t, title: title, uuid: uuid)
    }

    // The system calls this by drag and drop from the Finder.
    func addFileSystemObject(_ url: URL, indexPath: IndexPath) {
        let node = fileSystemNode(from: url)
        treeController.insert(node, atArrangedObjectIndexPath: indexPath)

        if url.isFolder {
            do {
                node.identifier = NSUUID().uuidString
                // It's a folder node, so find its children.
                let fileURLs =
                try FileManager.default.contentsOfDirectory(at: node.url!,
                                                            includingPropertiesForKeys: [],
                                                            options: [.skipsHiddenFiles])
                // Move indexPath one level deep for insertion.
                let newIndexPath = indexPath
                let finalIndexPath = newIndexPath.appending(0)

                addFileSystemObjects(fileURLs, indexPath: finalIndexPath)
            } catch _ {
                // No content at this URL.
            }
        } else {
            // This is just a leaf node, so there aren't any children to insert.
        }
    }

    private func addFileSystemObjects(_ entries: [URL], indexPath: IndexPath) {
        // Sort the array of URLs.
        var sorted = entries
        sorted.sort( by: { $0.lastPathComponent > $1.lastPathComponent })

        // Insert the sorted URL array into the tree controller.
        for entry in sorted {
            if entry.isFolder {
                // It's a folder node, so add the folder.
                let node = fileSystemNode(from: entry)
                node.identifier = NSUUID().uuidString
                treeController.insert(node, atArrangedObjectIndexPath: indexPath)

                do {
                    let fileURLs =
                    try FileManager.default.contentsOfDirectory(at: entry,
                                                                includingPropertiesForKeys: [],
                                                                options: [.skipsHiddenFiles])
                    if !fileURLs.isEmpty {
                        // Move indexPath one level deep for insertions.
                        let newIndexPath = indexPath
                        let final = newIndexPath.appending(0)

                        addFileSystemObjects(fileURLs, indexPath: final)
                    }
                } catch _ {
                    // No content at this URL.
                }
            } else {
                // It's a leaf node, so add the leaf.
                addFileSystemObject(entry, indexPath: indexPath)
            }
        }
    }

    private func addNewRoot(_ name: Node.Name, count: Int) {

        // Create and insert the group node.

        let node = Node(
            context: managedObjectContext,
            type: .root,
            title: name,
            uuid: NSUUID()
        )

        // Get the insertion indexPath from the current selection.
        var insertionIndexPath: IndexPath
        // If there is no selection, add a new group to the end of the content's array.
        if treeController.selectedObjects.isEmpty {
            // There's no selection, so add the folder to the top-level and at the end.
            insertionIndexPath = IndexPath(index: /*contents.count*/ 0)
        } else {
            /** Get the index of the currently selected node, then add the number of its children to the path.
             This gives you an index that allows you to add a node to the end of the currently
             selected node's children array.
             */
            insertionIndexPath = treeController.selectionIndexPath!
            if let selectedNode = treeController.selectedObjects[0] as? Node {
                // The user is trying to add a folder on a selected folder, so add the selection to the children.
                insertionIndexPath.append(selectedNode.children!.count)
            }
        }

        treeController.insert(node, atArrangedObjectIndexPath: insertionIndexPath)
    }

    private func addNode(_ node: Node) {
        // Find the selection to insert the node.
        var indexPath: IndexPath
        if treeController.selectedObjects.isEmpty {
            // No selection, so just add the child to the end of the tree.
            indexPath = IndexPath(index: /*contents.count*/ 0)
        } else {
            // There's a selection, so insert the child at the end of the selection.
            indexPath = treeController.selectionIndexPath!
            if let node = treeController.selectedObjects[0] as? Node {
                indexPath.append(node.children!.count)
            }
        }

        // The child to insert has a valid URL, so use its display name as the node title.
        // Take the URL and obtain the display name (nonescaped with no extension).
        if node.isURLNode {
            node.title = node.url!.localizedName
        }

        // The user is adding a child node, so tell the controller directly.
        treeController.insert(node, atArrangedObjectIndexPath: indexPath)

        if !node.isDirectory {
            // For leaf children, select its parent for further additions.
            selectParentFromSelection()
        }
    }

    // The system calls this from handleContextualMenu() or the add group button.
    func addFolderAtItem(_ item: NSTreeNode) -> Node? {
        // Obtain the base node at the specified outline view's row number, and the indexPath of that base node.
        guard let rowItemNode = Node.node(from: item),
              let itemNodeIndexPath = treeController.indexPathOfObject(anObject: rowItemNode) else { return nil }

        // You're inserting a new group folder at the node index path, so add it to the end.
        let indexPathToInsert = itemNodeIndexPath.appending(rowItemNode.children!.count)

        // Create an empty folder node.
        let node = newNode(type: .container, title: .untitled, uuid: NSUUID())
        treeController.insert(node, atArrangedObjectIndexPath: indexPathToInsert)

        return rowItemNode
    }


    // Find the index path to insert the dropped objects.
    func droppedIndexPath(item targetItem: Any?, childIndex index: Int) -> IndexPath? {
        let dropIndexPath: IndexPath?

        if targetItem != nil {
            // Drop-down inside the tree node: fetch the index path to insert the dropped node.
            dropIndexPath = (targetItem! as AnyObject).indexPath!.appending(index)
        } else {
            // Drop at the top root level.
            if index == -1 { // The drop area might be ambiguous (not at a particular location).
                dropIndexPath = IndexPath(index: /*contents.count*/ 0) // Drop at the end of the top level.
            } else {
                dropIndexPath = IndexPath(index: index) // Drop at a particular place at the top level.
            }
        }
        return dropIndexPath
    }

    private func nodeFromIdentifier(anObject: Any, nodes: [NSTreeNode]!) -> NSTreeNode? {
        var treeNode: NSTreeNode?
        for node in nodes {
            if let testNode = node.representedObject as? Node {
                let idCheck = anObject as? String
                if idCheck == testNode.identifier {
                    treeNode = node
                    break
                }
                if node.children != nil {
                    if let nodeCheck = nodeFromIdentifier(anObject: anObject, nodes: node.children) {
                        treeNode = nodeCheck
                        break
                    }
                }
            }
        }
        return treeNode
    }

    func nodeFromIdentifier(anObject: Any) -> NSTreeNode? {
        return nodeFromIdentifier(anObject: anObject, nodes: treeController.arrangedObjects.children)
    }

    // Take the currently selected node and select its parent.
    private func selectParentFromSelection() {
        if !treeController.selectedNodes.isEmpty {
            let firstSelectedNode = treeController.selectedNodes[0]
            if let parentNode = firstSelectedNode.parent {
                // Select the parent.
                let parentIndex = parentNode.indexPath
                treeController.setSelectionIndexPath(parentIndex)
            } else {
                // No parent exists (you are at the top of tree), so make no selection in your outline.
                let selectionIndexPaths = treeController.selectionIndexPaths
                treeController.removeSelectionIndexPaths(selectionIndexPaths)
            }
        }
    }

    typealias ConfirmFn = @MainActor ([Node]) async -> Bool

    @MainActor
    func performRemoval(itemsToRemove: [Node]) {
        // Remove the specified set of node objects from the tree controller.
        var indexPathsToRemove = [IndexPath]()
        for item in itemsToRemove {
            if let indexPath = self.treeController.indexPathOfObject(anObject: item) {
                indexPathsToRemove.append(indexPath)
            }
        }

        self.treeController.removeObjects(atArrangedObjectIndexPaths: indexPathsToRemove)

        // Remove the current selection after the removal.
        self.treeController.setSelectionIndexPaths([])
    }

    func remove(items: [Node]?, confirmFn: ConfirmFn) async {

        let itemsToRemove: [Node]

        if let items2 = items {
            itemsToRemove = items2
        } else {
            itemsToRemove = treeController.selectedNodes.compactMap { treeNode in
                if let node = Node.node(from: treeNode) {
                    return node
                } else {
                    return nil
                }
            }
        }

        // Confirm the removal operation.
        if await confirmFn(itemsToRemove) {
            await performRemoval(itemsToRemove: itemsToRemove)
        }
    }
}
