//
//  CoreGraphicsExtensions.swift
//  LyricsMTMR
//
//  Extracted from FrameworkToolbox/CoreGraphicsExt
//  Original: https://github.com/Mx-Iris/FrameworkToolbox
//
//  This source code is licensed under GPL 2.0.
//  See LICENSE file in the project root for full license information.
//

import CoreGraphics

extension CGAffineTransform {
    static func flip(height: CGFloat) -> CGAffineTransform {
        CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: height)
    }

    static func swap() -> CGAffineTransform {
        CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0)
    }
}
