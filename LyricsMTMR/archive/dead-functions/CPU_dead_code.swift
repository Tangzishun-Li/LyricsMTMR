// ============================================================
// 归档来源: MTMR/CPU.swift
// 归档原因: 以下函数/属性从未被项目中任何代码调用
// ============================================================

// --- applicationUsage(): 获取当前应用 CPU 占用，从未被调用 ---
open class func applicationUsage() -> Double {
    let threads = self.threadBasicInfos()
    var result : Double = 0.0
    threads.forEach { (thread:thread_basic_info) in
        if self.flag(thread) {
            result += Double.init(thread.cpu_usage) / Double.init(TH_USAGE_SCALE);
        }
    }
    return result * 100
}

// --- threadIdentifierInfos(): 带有 "in developing" TODO，从未被调用 ---
private class func threadIdentifierInfos() -> [thread_identifier_info] {
    var result = [thread_identifier_info]()
    let thinfo : thread_info_t = thread_info_t.allocate(capacity: Int(THREAD_INFO_MAX))
    let thread_info_count = UnsafeMutablePointer<mach_msg_type_number_t>.allocate(capacity: 128)
    var identifier_info_th: thread_identifier_info_t? = nil
    
    for act_t in self.threadActPointers() {
        thread_info_count.pointee = UInt32(THREAD_INFO_MAX);
        let kr = thread_info(act_t ,thread_flavor_t(THREAD_IDENTIFIER_INFO),thinfo, thread_info_count);
        if (kr != KERN_SUCCESS) {
            return [thread_identifier_info]();
        }
        identifier_info_th = withUnsafePointer(to: &thinfo.pointee, { (ptr) -> thread_identifier_info_t in
            let int8Ptr = unsafeBitCast(ptr, to: thread_identifier_info_t.self)
            return int8Ptr
        })
        if identifier_info_th != nil {
            result.append(identifier_info_th!.pointee)
        }
    }
    return result
}

// --- physicalCores / logicalCores: 已被注释掉的属性 ---
//    /// Number of physical cores on this machine.
//    public static var physicalCores: Int {
//        get {
//            return Int(System.hostBasicInfo.physical_cpu)
//        }
//    }
//
//    /// Number of logical cores on this machine. Will be equal to physicalCores
//    /// unless it has hyper-threading, in which case it will be double.
//    public static var logicalCores: Int {
//        get {
//            return Int(System.hostBasicInfo.logical_cpu)
//        }
//    }

// --- 以下辅助函数仅被上述死代码调用，一并归档 ---

// --- flag(_:): 仅被 applicationUsage() 调用 ---
private class func flag(_ thread:thread_basic_info) -> Bool {
    let foo = thread.flags & TH_FLAGS_IDLE
    let number = NSNumber.init(value: foo)
    return !Bool.init(truncating: number)
}

// --- threadActPointers(): 仅被 threadBasicInfos() 和 threadIdentifierInfos() 调用 ---
private class func threadActPointers() -> [thread_act_t] {
    var threads_act = [thread_act_t]()
    var threads_array: thread_act_array_t? = nil
    var count = mach_msg_type_number_t()
    let result = task_threads(mach_task_self_, &(threads_array), &count)
    guard result == KERN_SUCCESS else { return threads_act }
    guard let array = threads_array else { return threads_act }
    for i in 0..<count { threads_act.append(array[Int(i)]) }
    let krsize = count * UInt32.init(MemoryLayout<thread_t>.size)
    _ = vm_deallocate(mach_task_self_, vm_address_t(array.pointee), vm_size_t(krsize));
    return threads_act
}

// --- threadBasicInfos(): 仅被 applicationUsage() 调用 ---
private class func threadBasicInfos() -> [thread_basic_info]  {
    var result = [thread_basic_info]()
    let thinfo : thread_info_t = thread_info_t.allocate(capacity: Int(THREAD_INFO_MAX))
    let thread_info_count = UnsafeMutablePointer<mach_msg_type_number_t>.allocate(capacity: 128)
    var basic_info_th: thread_basic_info_t? = nil
    for act_t in self.threadActPointers() {
        thread_info_count.pointee = UInt32(THREAD_INFO_MAX);
        let kr = thread_info(act_t ,thread_flavor_t(THREAD_BASIC_INFO),thinfo, thread_info_count);
        if (kr != KERN_SUCCESS) { return [thread_basic_info](); }
        basic_info_th = withUnsafePointer(to: &thinfo.pointee, { (ptr) -> thread_basic_info_t in
            let int8Ptr = unsafeBitCast(ptr, to: thread_basic_info_t.self)
            return int8Ptr
        })
        if basic_info_th != nil { result.append(basic_info_th!.pointee) }
    }
    return result
}
