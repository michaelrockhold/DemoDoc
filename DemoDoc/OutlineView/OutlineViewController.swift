/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The primary view controller that contains the NSOutlineView.
*/

import Cocoa
import Combine
import UniformTypeIdentifiers // for UTType

class OutlineViewController: NSViewController,
    							NSTextFieldDelegate, // To respond to the text field's edit sending.
								NSUserInterfaceValidations { // To enable/disable menu items for the outline view.

    // MARK: Outlets
    
    @IBOutlet weak var outlineView: OutlineView!

	@IBOutlet private weak var placeHolderView: NSView!
    
    // MARK: Instance Variables
    
    // We observe the tree controller's selection changing.
    var selectionChangedCancellable: Cancellable?

    // The outline view of top-level content. NSTreeController backs this.
//    @objc dynamic var contents: [AnyObject] = []
    
  	var rowToAdd = -1 // The addition of a flagged row (for later renaming).
    
    // The directory for accepting promised files.
    lazy var promiseDestinationURL: URL = {
        let promiseDestinationURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Drops")
        try? FileManager.default.createDirectory(at: promiseDestinationURL, withIntermediateDirectories: true, attributes: nil)
        return promiseDestinationURL
    }()

    private var iconViewController: IconViewController!
    private var fileViewController: FileViewController!
    private var imageViewController: ImageViewController!
    private var multipleItemsViewController: NSViewController!

    // MARK: View Controller Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Determine the contextual menu for the outline view.
   		outlineView.customMenuDelegate = self
        
        // Dragging items out: Set the default operation mask so you can drag (copy) items to outside this app, and delete them in the Trash can.
        outlineView?.setDraggingSourceOperationMask([.copy, .delete], forLocal: false)
        
        // Register for drag types coming in to receive file promises from Photos, Mail, Safari, and so forth.
        outlineView.registerForDraggedTypes(NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) })
        
        // You want these drag types: your own type (outline row number), and fileURLs.
		outlineView.registerForDraggedTypes([
      		.nodeRowPasteBoardType, // Your internal drag type, the outline view's row number for internal drags.
            NSPasteboard.PasteboardType.fileURL // To receive file URL drags.
            ])


        // Load the icon view controller from the storyboard for later use as your Detail view.
        iconViewController =
            storyboard!.instantiateController(withIdentifier: "IconViewController") as? IconViewController
        iconViewController.view.translatesAutoresizingMaskIntoConstraints = false
        
        // Load the file view controller from the storyboard for later use as your Detail view.
        fileViewController =
            storyboard!.instantiateController(withIdentifier: "FileViewController") as? FileViewController
        fileViewController.view.translatesAutoresizingMaskIntoConstraints = false
        
        // Load the image view controller from the storyboard for later use as your Detail view.
        imageViewController =
            storyboard!.instantiateController(withIdentifier: "ImageViewController") as? ImageViewController
        imageViewController.view.translatesAutoresizingMaskIntoConstraints = false
        
        // Load the multiple items selected view controller from the storyboard for later use as your Detail view.
        multipleItemsViewController =
            storyboard!.instantiateController(withIdentifier: "MultipleSelection") as? NSViewController
		multipleItemsViewController.view.translatesAutoresizingMaskIntoConstraints = false
        
        /** Note: The following makes the outline view appear with gradient background and proper
         	selection to behave like the Finder sidebar, iTunes, and so forth.
         */
        //outlineView.selectionHighlightStyle = .sourceList // But you already do this in the storyboard.
        
        if let tc = self.treeController {
            outlineView.bind(.content,
                             to: tc,
                             withKeyPath: "arrangedObjects",
                             options:[.raisesForNotApplicableKeys: true])

            outlineView.bind(.selectionIndexPaths,
                             to: tc,
                             withKeyPath: "selectionIndexPaths",
                             options:[.raisesForNotApplicableKeys: true])
        }


        // Set up observers for the outline view's selection, adding items, and removing items.
        setupObservers()

        self.treeController?.fetchPredicate = NSPredicate(format: "parent == %@", NSNull())
        self.treeController?.fetch(self)
    }

    override func viewWillAppear() {
        /** Disclose the two root outline groups (Places and Pictures) at first launch.
             With all subsequent launches, the autosave disclosure states determine these disclosure states.
         */
        let defaults = UserDefaults.standard
        let initialDisclosure = defaults.string(forKey: "initialDisclosure")
        if initialDisclosure == nil {
            if !(self.treeController?.arrangedObjects.children?.isEmpty ?? true) {
                outlineView.expandItem(self.treeController?.arrangedObjects.children![0])
                outlineView.expandItem(self.treeController?.arrangedObjects.children![1])
            }
            defaults.set("initialDisclosure", forKey: "initialDisclosure")
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(
            self,
            name: Notification.Name(WindowViewController.NotificationNames.addFolder),
            object: nil)
        NotificationCenter.default.removeObserver(
            self,
        	name: Notification.Name(WindowViewController.NotificationNames.addPicture),
         	object: nil)
        NotificationCenter.default.removeObserver(
            self,
    		name: Notification.Name(WindowViewController.NotificationNames.removeItem),
   			object: nil)
    }
    
    // MARK: Removal and Addition

    private func removalConfirmAlert(_ itemsToRemove: [Node]) -> NSAlert {
        let alert = NSAlert()
        
        var messageStr: String
        if itemsToRemove.count > 1 {
            // Remove multiple items.
            alert.messageText = NSLocalizedString("remove multiple string", comment: "")
        } else {
            // Remove the single item.
            if itemsToRemove[0].isURLNode {
                messageStr = NSLocalizedString("remove link confirm string", comment: "")
            } else {
                messageStr = NSLocalizedString("remove confirm string", comment: "")
            }
            alert.messageText = String(format: messageStr, itemsToRemove[0].title!)
        }
        
        alert.addButton(withTitle: NSLocalizedString("ok button title", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("cancel button title", comment: ""))
        
        return alert
    }
    
    // The system calls these from handleContextualMenu() or the remove button.
    // Remove the currently selected items.

    func removeSelectedItems() {
        remove(items: nil)
    }

    func remove(item: Node) {
        remove(items: [item])
    }

    func remove(items itemsToRemove: [Node]? = nil) {
        Task {
            await self.dataManager?.remove(items: itemsToRemove) { itemsToRemove in
                let confirmAlert = removalConfirmAlert(itemsToRemove)
                let response = await confirmAlert.beginSheetModal(for: view.window!)
                return response == NSApplication.ModalResponse.alertFirstButtonReturn
            }
        }
    }

/// - Tag: Delete
    // The user chose the Delete menu item or pressed the Delete key.
    @IBAction func delete(_ sender: AnyObject) {
        removeSelectedItems()
    }

    // The system calls this from handleContextualMenu() or the add picture button.
    func addPictureAtItem(_ item: Node) {
        // Present an open panel to choose a picture to display in the outline view.
        let openPanel = NSOpenPanel()
        
        // Find a picture to add.
        let locationTitle = item.title!
        let messageStr = NSLocalizedString("choose picture message", comment: "")
        openPanel.message = String(format: messageStr, locationTitle)
        openPanel.prompt = NSLocalizedString("open panel prompt", comment: "") // Set the Choose button title.
        openPanel.canCreateDirectories = false
        
        // Allow choosing all kinds of image files.
        if #available(macOS 11.0, *) {
            openPanel.allowedContentTypes = [UTType.image]
        } else {
            if let imageTypes = CGImageSourceCopyTypeIdentifiers() as? [String] {
                openPanel.allowedFileTypes = imageTypes
            }
        }
        
        openPanel.beginSheetModal(for: view.window!) { (response) in
            guard response == NSApplication.ModalResponse.OK else { return }

            // Get the indexPath of the folder you're adding to.
            guard let itemNodeIndexPath = self.treeController?.indexPathOfObject(anObject: item) else { return }

            // You're inserting a new picture at the item node index path.
            let indexPathToInsert = itemNodeIndexPath.appending(IndexPath(index: 0))

            // Create a leaf picture node.
            let node = self.dataManager?.newNode(
                type: .document,
                url: openPanel.url,
                title: openPanel.url?.localizedName ?? ""
            )

            self.treeController?.insert(node, atArrangedObjectIndexPath: indexPathToInsert)
        }
    }
    
    // MARK: Notifications
    
    private func setupObservers() {
        // A notification to add a folder.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(addFolder(_:)),
            name: Notification.Name(WindowViewController.NotificationNames.addFolder),
            object: nil)
        
        // A notification to add a picture.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(addPicture(_:)),
            name: Notification.Name(WindowViewController.NotificationNames.addPicture),
            object: nil)
        
        // A notification to remove an item.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(removeItem(_:)),
            name: Notification.Name(WindowViewController.NotificationNames.removeItem),
            object: nil)
        
        // Listen to the treeController's selection change so you inform clients to react to selection changes.
        selectionChangedCancellable = self.treeController?.publisher(for: \.selectedNodes)
            .sink() { [self] selectedNodes in

                // Save the outline selection state for later when the app relaunches.
                self.invalidateRestorableState()
            }
    }
    
    // A notification that the WindowViewController class sends to add a generic folder to the current selection.
    @objc
    private func addFolder(_ notif: Notification) {
        // Add the folder with the "untitled" title.
        let selectedRow = outlineView.selectedRow
        if let folderToAddNode = self.outlineView.item(atRow: selectedRow) as? NSTreeNode {
            self.addFolderAtItem(folderToAddNode)
        }
        // Flag the row you're adding (for later renaming).
        rowToAdd = outlineView.selectedRow
    }
    
    // A notification that the WindowViewController class sends to add a picture to the selected folder node.
    @objc
    private func addPicture(_ notif: Notification) {
        let selectedRow = outlineView.selectedRow
        
        if let item = self.outlineView.item(atRow: selectedRow) as? NSTreeNode,
            let addToNode = DataManager.node(from: item) {
            	addPictureAtItem(addToNode)
        }
    }
    
    // A notification that the WindowViewController remove button sends to remove a selected item from the outline view.
    @objc
    private func removeItem(_ notif: Notification) {
        removeSelectedItems()
    }
    
    // The system calls this from handleContextualMenu() or the add group button.
   func addFolderAtItem(_ item: NSTreeNode) {

       if let rowItemNode = self.dataManager?.addFolderAtItem(item) {
           // Flag the row you're adding (for later renaming).
           rowToAdd = outlineView.row(forItem: item) + rowItemNode.children!.count
       }
    }

    // MARK: NSTextFieldDelegate
    
    // For a text field in each outline view item, the user commits the edit operation.
    func controlTextDidEndEditing(_ obj: Notification) {
        // Commit the edit by applying the text field's text to the current node.
        guard let item = outlineView.item(atRow: outlineView.selectedRow),
            let node = DataManager.node(from: item) else { return }

        if let textField = obj.object as? NSTextField {
            node.title = textField.stringValue
        }
    }
    
    // MARK: NSValidatedUserInterfaceItem

    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(delete(_:)) {
            return !(self.treeController?.selectedObjects.isEmpty ?? true)
        }
        return true
    }

    // MARK: Detail View Management
    
    // Use this to decide which view controller to use as the detail.
    func viewControllerForSelection(_ selection: [NSTreeNode]?) -> NSViewController? {
        guard let outlineViewSelection = selection else { return nil }
        
        var viewController: NSViewController?
        
        switch outlineViewSelection.count {
        case 0:
            // No selection.
            viewController = nil
        case 1:
            // A single selection.
            if let node = DataManager.node(from: selection?[0] as Any) {
                if let url = node.url {
                    // The node has a URL.
                    if node.isDirectory {
                        // It is a folder URL.
                        iconViewController.url = url
                        viewController = iconViewController
                    } else {
                        // It is a file URL.
                        fileViewController.url = url
                        viewController = fileViewController
                    }
                } else {
                    // The node doesn't have a URL.
                    if node.isDirectory {
                        // It is a non-URL grouping of pictures.
                        iconViewController.nodeContent = node
                        viewController = iconViewController
                    } else {
                        // It is a non-URL image document, so load its image.
                        if let loadedImage = NSImage(named: node.title!) {
                            imageViewController.fileImageView?.image = loadedImage
                        } else {
                            debugPrint("Failed to load built-in image: \(node.title!)")
                        }
                        viewController = imageViewController
                    }
                }
            }
        default:
            // The selection is multiple or more than one.
            viewController = multipleItemsViewController
        }

        return viewController
    }
    
    // MARK: File Promise Drag Handling

    /// The queue for reading and writing file promises.
    lazy var workQueue: OperationQueue = {
        let providerQueue = OperationQueue()
        providerQueue.qualityOfService = .userInitiated
        return providerQueue
    }()
    
}

