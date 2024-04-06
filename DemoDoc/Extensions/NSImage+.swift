//
//  NSImage+.swift
//  SourceView
//
//  Created by Michael Rockhold on 4/4/24.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation
import Cocoa

extension NSImage {

    // Returns the Data version of NSImage.
    func pngData() -> Data? {
        var data: Data?
        if let tiffRep = tiffRepresentation {
            if let bitmap = NSBitmapImageRep(data: tiffRep) {
                data = bitmap.representation(using: .png, properties: [:])
            }
        }
        return data
    }
}

