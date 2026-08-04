//
//  WidgetProtocol.swift
//  MTMR
//
//  Created by Anton Palgunov on 20/10/2018.
//  Copyright © 2018 Anton Palgunov. All rights reserved.
//

protocol Widget {
    static var name: String { get }
    static var identifier: String { get }
}

/// Optional teardown hook for bar items that own live resources
/// (repeating timers, notification observers, lazily created child items).
/// TouchBarController calls this on the main thread right before it drops
/// its reference to an item during a preset switch. Implementations must be
/// idempotent — deinit should run the same cleanup.
protocol BarItemDiscarding {
    func barItemWillDiscard()
}
