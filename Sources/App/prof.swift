//
//  prof.swift
//  perf
//
//  Created by Brian Floersch on 2/19/25.
//

@_silgen_name("HeapProfilerStart")
func HeapProfilerStart(_ prefix: UnsafePointer<CChar>?)

@_silgen_name("HeapProfilerDump")
func HeapProfilerDump(_ reason: UnsafePointer<CChar>?)

@_silgen_name("HeapProfilerStop")
func HeapProfilerStop()

func startHeapProfiling(prefix: String = "heap_profile") {
    prefix.withCString { HeapProfilerStart($0) }
}

func dumpHeapProfile(reason: String = "manual_dump") {
    reason.withCString { HeapProfilerDump($0) }
}

func stopHeapProfiling() {
    HeapProfilerStop()
}

@_silgen_name("ProfilerStart")
func ProfilerStart(_ fname: UnsafePointer<CChar>?) -> Int32

@_silgen_name("ProfilerStop")
func ProfilerStop()

func startCPUProfiling(filename: String = "cpu_profile.out") {
    _ = filename.withCString { ProfilerStart($0) }
}

func stopCPUProfiling() {
    ProfilerStop()
}
