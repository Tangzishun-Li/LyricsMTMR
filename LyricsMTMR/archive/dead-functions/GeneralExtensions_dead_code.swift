// ============================================================
// 归档来源: MTMR/GeneralExtensions.swift
// 归档原因: Swift 4.1 兼容 shim，项目已使用 Swift 5+，完全多余
// ============================================================

#if swift(>=4.1)
    // compactMap supported
#else
    extension Sequence {
        func compactMap<ElementOfResult>(_ transform: (Self.Element) throws -> ElementOfResult?) rethrows -> [ElementOfResult] {
            return try flatMap(transform)
        }
    }
#endif
