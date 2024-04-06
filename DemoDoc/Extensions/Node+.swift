/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A generic multiuse node object to use with NSOutlineView and NSTreeController.
*/

import Cocoa
import CoreData
import UniformTypeIdentifiers

class ExternalNode: NSObject, Codable {
    var type: Node.TypeCode = .unknown
    var title: String = ""
    var identifier: String = ""
    var url: URL?
    @objc dynamic var children = [ExternalNode]()
}

extension Node {
    
    // MARK: Constants

    // Unique nodeIDs for the two top-level group nodes.
    enum TopNodeID: String {
        typealias RawValue = String
        case pictures = "1000"
        case places = "1001"
    }

    enum TypeCode: Int, Codable {
        case container
        case document
        case separator
        case root
        case unknown
    }

    enum Name: String {
        case untitled = "untitled string"
        case places = "places string"
        case pictures = "pictures string"

        func localized()->String {
            return NSLocalizedString(self.rawValue, comment: "")
        }
    }

    @objc dynamic var children:[Node]? {
        get {
            if let a = childrenSet?.array as? [Node]? {
                return a
            }
            return nil
        }
        set {
            if newValue == nil {
                childrenSet = nil
            } else {
                childrenSet = NSOrderedSet(array: newValue!)
            }
        }
    }

    convenience init(context: NSManagedObjectContext, externalNode: ExternalNode) {
        self.init(context: context)
        self.type = externalNode.type
        self.title = externalNode.title
        self.identifier = externalNode.identifier
        self.url = externalNode.url
    }

    convenience init(context: NSManagedObjectContext, url: URL) {
        self.init(
            context: context,
            type: url.isFolder ? .container : .document,
            url: url,
            title: url.localizedName
        )
    }
    
    convenience init(context: NSManagedObjectContext, type t: TypeCode, url: URL?, title: String) {
        self.init(context: context)
        self.type = t
        self.url = url
        self.title = title
    }

    convenience init(context: NSManagedObjectContext, type t: TypeCode, title: Name, ID: TopNodeID) {
        self.init(context: context)
        self.type = t
        self.title = title.localized()
        self.identifier = ID.rawValue
    }

    convenience init(context: NSManagedObjectContext, type t: TypeCode, title: Name, identifier: String) {
        self.init(context: context)
        self.type = t
        self.title = title.localized()
        self.identifier = identifier
    }

    convenience init(context: NSManagedObjectContext, type t: TypeCode, title: Name, uuid: NSUUID) {
        self.init(context: context)
        self.type = t
        self.title = title.localized()
        self.identifier = uuid.uuidString
    }

    var type: TypeCode {
        set {
            self.typecode = Int32(newValue.rawValue)
        }
        get {
            return TypeCode(rawValue: Int(self.typecode))!
        }
    }
    /** The tree controller calls this to determine if this node is a leaf node,
        use it to determine if the node needs a disclosure triangle.
     */
    @objc dynamic var isLeaf: Bool {
        return type == .document || type == .separator
    }
    
    var isURLNode: Bool {
        return url != nil
    }
    
    var isRoot: Bool {
        // A group node is a special node that represents either Pictures or Places as grouped sections.
        return type == .root
    }
    
    override public class func description() -> String {
        return "Node"
    }
    
    var nodeIcon: NSImage {
        var icon = NSImage()
        if let nodeURL = url {
            // If the node has a URL, use it to obtain its icon.
            icon = nodeURL.icon
        } else {
            // There's no URL for this node, so determine its icon generically.
            if #available(macOS 11.0, *) {
                let type = isDirectory ? UTType.folder : UTType.image
                icon = NSWorkspace.shared.icon(for: type)
            } else {
                let osType = isDirectory ? kGenericFolderIcon : kGenericDocumentIcon
                let iconType = NSFileTypeForHFSTypeCode(OSType(osType))
                icon = NSWorkspace.shared.icon(forFileType: iconType!)
            }
        }
        return icon
    }
    
    var canChange: Bool {
        // You can only change (rename or add to) non-URL based directory nodes.
        return isDirectory && url == nil  && type != .root
    }
    
    var canAddTo: Bool {
        return isDirectory && canChange
    }
    
    var isDirectory: Bool {
        return type == .container || type == .root
    }
    
}
