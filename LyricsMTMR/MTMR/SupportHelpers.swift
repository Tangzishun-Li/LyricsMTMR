//
//  SupportHelpers.swift
//  MTMR
//
//  Created by Anton Palgunov on 13/04/2018.
//  Copyright © 2018 Anton Palgunov. All rights reserved.
//

import AppKit
import Foundation

extension String {
    func stripComments() -> String {
        let lines = split(separator: "\n", omittingEmptySubsequences: false)
        var result: [String] = []
        var inBlockComment = false

        for line in lines {
            var lineStr = String(line)
            var i = lineStr.startIndex
            var out = ""

            while i < lineStr.endIndex {
                if inBlockComment {
                    if i < lineStr.index(before: lineStr.endIndex),
                       lineStr[i] == "*",
                       lineStr[lineStr.index(after: i)] == "/" {
                        inBlockComment = false
                        i = lineStr.index(i, offsetBy: 2)
                    } else {
                        i = lineStr.index(after: i)
                    }
                } else {
                    if lineStr[i] == "\"" || lineStr[i] == "'" {
                        let quote = lineStr[i]
                        out.append(quote)
                        i = lineStr.index(after: i)
                        while i < lineStr.endIndex {
                            out.append(lineStr[i])
                            if lineStr[i] == "\\" {
                                i = lineStr.index(after: i)
                                if i < lineStr.endIndex {
                                    out.append(lineStr[i])
                                }
                            } else if lineStr[i] == quote {
                                i = lineStr.index(after: i)
                                break
                            }
                            i = lineStr.index(after: i)
                        }
                    } else if i < lineStr.index(before: lineStr.endIndex),
                              lineStr[i] == "/",
                              lineStr[lineStr.index(after: i)] == "*" {
                        inBlockComment = true
                        i = lineStr.index(i, offsetBy: 2)
                    } else if i < lineStr.index(before: lineStr.endIndex),
                              lineStr[i] == "/",
                              lineStr[lineStr.index(after: i)] == "/" {
                        break
                    } else {
                        out.append(lineStr[i])
                        i = lineStr.index(after: i)
                    }
                }
            }
            result.append(out)
        }

        return result.joined(separator: "\n")
    }

    var hexColor: NSColor? {
        let hex = trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt32()
        Scanner(string: hex).scanHexInt32(&int)
        let a, r, g, b: UInt32
        switch hex.count {
        case 3: // RGB (12-bit)
            (r, g, b, a) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17, 255)
        case 6: // RGB (24-bit)
            (r, g, b, a) = (int >> 16, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8: // ARGB (32-bit)
            (r, g, b, a) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        return NSColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}

extension NSImage {
    func resize(maxSize: NSSize) -> NSImage {
        var ratio: Float = 0.0
        let imageWidth = Float(size.width)
        let imageHeight = Float(size.height)
        let maxWidth = Float(maxSize.width)
        let maxHeight = Float(maxSize.height)

        // Get ratio (landscape or portrait)
        if imageWidth > imageHeight {
            // Landscape
            ratio = maxWidth / imageWidth
        } else {
            // Portrait
            ratio = maxHeight / imageHeight
        }

        // Calculate new size based on the ratio
        let newWidth = imageWidth * ratio
        let newHeight = imageHeight * ratio

        // Create a new NSSize object with the newly calculated size
        let newSize: NSSize = NSSize(width: Int(newWidth), height: Int(newHeight))

        // Cast the NSImage to a CGImage
        var imageRect: NSRect = NSMakeRect(0, 0, size.width, size.height)
        let imageRef = cgImage(forProposedRect: &imageRect, context: nil, hints: nil)

        // Create NSImage from the CGImage using the new size
        let imageWithNewSize = NSImage(cgImage: imageRef!, size: newSize)

        // Return the new image
        return imageWithNewSize
    }
}
