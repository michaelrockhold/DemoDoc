//
//  ViewController.swift
//  DemoDoc
//
//  Created by Michael Rockhold on 4/4/24.
//

import Cocoa

extension NSViewController {
    var outlineViewModel: OutlineViewModel? {
        return representedObject as? OutlineViewModel
    }
}
