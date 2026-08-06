//
//  CPU.swift
//  Pods
//
//  Created by zixun on 2016/12/5.
//  https://github.com/zixun/SystemEye
//  MIT License
//
//

import Foundation

private let HOST_CPU_LOAD_INFO_COUNT      : mach_msg_type_number_t =
    UInt32(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)

/// CPU Class
public class CPU: NSObject {
    
    //--------------------------------------------------------------------------
    // MARK: OPEN FUNCTIONS
    //--------------------------------------------------------------------------
    
    ///  Get CPU usage of hole system (system, user, idle, nice). Determined by the delta between
    ///  the current and last call.
    public static func systemUsage() -> (system: Double,
                                         user: Double,
                                         idle: Double,
                                         nice: Double) {
        let load = self.hostCPULoadInfo
        
        let userDiff = Double(load.cpu_ticks.0 - loadPrevious.cpu_ticks.0)
        let sysDiff  = Double(load.cpu_ticks.1 - loadPrevious.cpu_ticks.1)
        let idleDiff = Double(load.cpu_ticks.2 - loadPrevious.cpu_ticks.2)
        let niceDiff = Double(load.cpu_ticks.3 - loadPrevious.cpu_ticks.3)
        
        let totalTicks = sysDiff + userDiff + niceDiff + idleDiff
        
        let sys  = sysDiff  / totalTicks * 100.0
        let user = userDiff / totalTicks * 100.0
        let idle = idleDiff / totalTicks * 100.0
        let nice = niceDiff / totalTicks * 100.0
        
        loadPrevious = load
        
        return (sys, user, idle, nice)
    }
    
    //--------------------------------------------------------------------------
    // MARK: PRIVATE PROPERTY
    //--------------------------------------------------------------------------
    
    /// previous load of cpu
    private static var loadPrevious = host_cpu_load_info()
    
    static var hostCPULoadInfo: host_cpu_load_info {
        get {
            var size     = HOST_CPU_LOAD_INFO_COUNT
            var hostInfo = host_cpu_load_info()
            let result = withUnsafeMutablePointer(to: &hostInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                    host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
                }
            }
            
            #if DEBUG
                if result != KERN_SUCCESS {
                    fatalError("ERROR - \(#file):\(#function) - kern_result_t = "
                        + "\(result)")
                }
            #endif
            
            return hostInfo
        }
    }
}
