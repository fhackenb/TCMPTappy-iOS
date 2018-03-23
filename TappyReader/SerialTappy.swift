//
//  SerialTappy.swift
//  TCMP
//
//  Created by David Shalaby on 2018-03-08.
//  Copyright © 2018 Papyrus Electronics Inc d/b/a TapTrack. All rights reserved.
//
/*
 * Copyright (c) 2018. Papyrus Electronics, Inc d/b/a TapTrack.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * you may obtain a copy of the License at
 *
 *        http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import Foundation

public class SerialTappy : Tappy {
    public var state : TappyStatus = TappyStatus.STATUS_CLOSED
    
    var communicator : TappySerialCommunicator?
    var receiveBuffer : [UInt8] = []
    var statusListener : (TappyStatus) -> ()
    var responseListener : (TCMPMessage) -> ()
    var unparsableListener : ([UInt8]) -> ()
    
    public init() {
        responseListener = {_ in func emptyResponseListener(message: TCMPMessage) -> (){}}
        statusListener = {_ in func emptyStatusListener(status: TappyStatus) -> (){}}
        unparsableListener = {_ in func emptyUnparsablePacketListener(packet : [UInt8]) -> (){}}
    }
    
    public init(communicator : TappySerialCommunicator){
        responseListener = {_ in func emptyResponseListener(message: TCMPMessage) -> (){}}
        statusListener = {_ in func emptyStatusListener(status: TappyStatus) -> (){}}
        unparsableListener = {_ in func emptyUnparsablePacketListener(packet : [UInt8]) -> (){}}
        self.communicator = communicator
        communicator.setDataListener(receivedBytes: receiveBytes)
        communicator.setStatusListener(statusReceived: notifyListenerOfStatus)
    }
    
    public func receiveBytes(data : [UInt8]){
        var commands : [[UInt8]] = [[]]
        receiveBuffer.append(contentsOf: data)
        if(TCMPUtils.containsHdlcEndpoint(packet: data)){
            let currentBuffer : [UInt8] = receiveBuffer
            let parseResult : TCMPUtils.HDLCParseResult = TCMPUtils.HDLCByteArrayParser(bytes: currentBuffer)
            commands = parseResult.getPackets()
            receiveBuffer = parseResult.getRemainder()
        }
        
        if (commands.count == 0){
            return
        }
        
        for hdlcPacket in commands{
            do{
                let decodedPacket : [UInt8] = try TCMPUtils.hdlcDecodePacket(frame: hdlcPacket)
                if(decodedPacket.count != 0){
                    do{
                        let message : RawTCMPMesssage = try RawTCMPMesssage(message: decodedPacket)
                        responseListener(message)
                    }catch{
                        unparsableListener(hdlcPacket)
                    }
                }else{
                    unparsableListener(hdlcPacket)
                }
            }catch{
                unparsableListener(hdlcPacket)
            }
        }
    }

   public func setResponseListener(listener: @escaping (TCMPMessage) -> ()) {
        responseListener = listener
    }
    
    public func removeResponseListener() {
        responseListener = {_ in func emptyResponseListener(message: TCMPMessage) -> (){}}
    }
    
    public func setStatusListener(listner: @escaping (TappyStatus) -> ()) {
        statusListener = listner
    }
    
    public func removeStatusListener() {
        statusListener = {_ in func emptyStatusListener(status: TappyStatus) -> (){}}
    }
    
    public func setUnparsablePacketListener(listener: @escaping ([UInt8]) -> ()) {
        unparsableListener = listener
    }
    
    public func removeUnparsablePacketListener() {
        unparsableListener = {_ in func emptyUnparsablePacketListener(packet : [UInt8]) -> (){}}
    }

    public func removeAllListeners() {
        removeResponseListener()
        removeUnparsablePacketListener()
        removeUnparsablePacketListener()
    }
    
    private func notifyListenerOfStatus(status : TappyStatus/*, affectedTappy: SerialTappy*/){
        statusListener(status)
    }
    
    public func connect(){
        if let comm = communicator{
            comm.connect()
        }
        
    }
    
    public func sendMessage(message: TCMPMessage) {
        if let comm = communicator{
            comm.sendBytes(data: TCMPUtils.hdlcEncodePacket(packet: message.toByteArray()))
        }
    }
    
    public func disconnect() {
        if let comm = communicator{
            comm.disconnect()
        }
        
    }
    
    public func close() {
        if let comm = communicator{
            comm.close()
        }
        
    }
    
    public func getDeviceDescription() -> String {
        if let comm = communicator{
            return comm.getDeviceDescription();
        }else{
            return ""
        }
        
    }
    
    public func getLatestStatus() -> TappyStatus {
        return state
    }
    
}

