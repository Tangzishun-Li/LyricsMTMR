//
//  Then.swift
//  LyricsMTMR
//
//  Extracted from LyricsX
//  Original: https://github.com/MxIris-LyricsX-Project/LyricsX
//
//  This source code is licensed under GPL 2.0.
//  See LICENSE file in the project root for full license information.
//

import CoreGraphics
import Foundation

protocol Then {}

extension Then where Self: Any {
    func with(_ block: (inout Self) throws -> Void) rethrows -> Self {
        var copy = self
        try block(&copy)
        return copy
    }

    func `do`<T>(_ block: (Self) throws -> T) rethrows -> T {
        return try block(self)
    }
}

extension Then where Self: AnyObject {
    func then(_ block: (Self) throws -> Void) rethrows -> Self {
        try block(self)
        return self
    }
}

extension NSObject: Then {}

extension CGPoint: Then {}
extension CGRect: Then {}
extension CGSize: Then {}
extension CGVector: Then {}
