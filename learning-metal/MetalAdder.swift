//
//  MetalAdder.swift
//  learning-metal
//

import Foundation
import Metal

class MetalAdder {
    static let arrayLength = 1 << 24
    static let bufferLength = MetalAdder.arrayLength * MemoryLayout<Float>.stride

    
    let device: MTLDevice
    let addFunctionPSO: MTLComputePipelineState
    let commandQueue: MTLCommandQueue
    
    var bufferA: MTLBuffer?
    var bufferB: MTLBuffer?
    var bufferResult: MTLBuffer?

    init?(_ device: MTLDevice)
    {
        self.device = device
        
        let defaultLibrary = self.device.makeDefaultLibrary()
        if (defaultLibrary == nil) {
            NSLog("Could not find library.")
            return nil
        }
        
        let addFunction = defaultLibrary!.makeFunction(name: "add_arrays")
        if (addFunction == nil) {
            NSLog("Could not find function.")
            return nil
        }
        
        do {
            try self.addFunctionPSO = self.device.makeComputePipelineState(function: addFunction!)
        } catch {
            NSLog("Could not create pipeline")
            return nil
        }
        
        self.commandQueue = self.device.makeCommandQueue()!
        
    }
    
    func prepareData()
    {
        self.bufferA = self.device.makeBuffer(length: MetalAdder.bufferLength, options: MTLResourceOptions.storageModeShared)!
        self.bufferB = self.device.makeBuffer(length: MetalAdder.bufferLength, options: MTLResourceOptions.storageModeShared)!
        self.bufferResult = self.device.makeBuffer(length: MetalAdder.bufferLength, options: MTLResourceOptions.storageModeShared)!

        self.generateRandomFloatData(self.bufferA!)
        self.generateRandomFloatData(self.bufferB!)
    }
    
    func generateRandomFloatData(_ buffer: MTLBuffer)
    {
        let dataPtr: UnsafeMutablePointer<Float> = buffer.contents().assumingMemoryBound(to: Float.self)
        
        for index in 0 ... MetalAdder.arrayLength
        {
            dataPtr[index] = Float.random(in: 0...Float(RAND_MAX)) / Float.random(in: 0...Float(RAND_MAX))
        }
    }
    
    func sendComputeCommand()
    {
        let commandBuffer: MTLCommandBuffer = self.commandQueue.makeCommandBuffer()!
        let computeEncoder: MTLComputeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!

        self.encodeAddCommand(computeEncoder)
        
        computeEncoder.endEncoding()
        commandBuffer.commit()
        
        commandBuffer.waitUntilCompleted()
        self.verifyResults()
    }
    
    func encodeAddCommand(_ computeEncoder: MTLComputeCommandEncoder)
    {
        // Set the work
        computeEncoder.setComputePipelineState(self.addFunctionPSO)
        computeEncoder.setBuffer(self.bufferA, offset: 0, index: 0)
        computeEncoder.setBuffer(self.bufferB, offset: 0, index: 1)
        computeEncoder.setBuffer(self.bufferResult, offset: 0, index: 2)
        
        let gridSize: MTLSize = MTLSizeMake(MetalAdder.arrayLength, 1, 1)
        
        // Calculate a threadgroup size.
        var threadGroupSizeInt: Int = self.addFunctionPSO.maxTotalThreadsPerThreadgroup
        if (threadGroupSizeInt > MetalAdder.arrayLength)
        {
            threadGroupSizeInt = MetalAdder.arrayLength
        }
        let threadGroupSize: MTLSize = MTLSizeMake(threadGroupSizeInt, 1, 1)
        
        // Encode the compute command.
        computeEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)
    }

    func verifyResults()
    {
        let a: UnsafeMutablePointer<Float> = self.bufferA!.contents().assumingMemoryBound(to: Float.self)
        let b: UnsafeMutablePointer<Float> = self.bufferB!.contents().assumingMemoryBound(to: Float.self)
        let result: UnsafeMutablePointer<Float> = self.bufferResult!.contents().assumingMemoryBound(to: Float.self)
        
        for index in 0 ..< MetalAdder.arrayLength
        {
            if (result[index] !=
                (a[index] +
                    b[index]))
            {
                print(NSString(format: "Compute ERROR: index=%lu result=%g vs %g=%g+%g\n",
                       index, result[index], a[index] + b[index], a[index], b[index]))
                assert(result[index] == (a[index] + b[index]))
            }
        }
        print("Compute results as expected")
    }
}
