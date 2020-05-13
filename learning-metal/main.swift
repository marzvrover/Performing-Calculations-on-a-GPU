//
//  main.swift
//  learning-metal
//

import Foundation
import Metal

main()

func add(inA: [Float], inB: [Float], result: inout [Float]) -> Void {
    for index in 0 ..< inA.count {
        result[index] = inA[index] + inB[index]
    }
}

func main() -> Void {
    let device: MTLDevice = MTLCreateSystemDefaultDevice()!
    let adder: MetalAdder = MetalAdder(device)!
    
    adder.prepareData()
    adder.sendComputeCommand()
    
    NSLog("Execution finished");
}
