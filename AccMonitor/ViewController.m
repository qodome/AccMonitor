//
//  ViewController.m
//  BatteryMonitor
//
//  Created by Ting Wang on 11/30/14.
//  Copyright (c) 2014 Ting Wang. All rights reserved.
//

#import "ViewController.h"

@interface ViewController () <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (strong, nonatomic) CBCentralManager *central;
@property (strong, nonatomic) NSMutableArray *devices;
@property (strong, nonatomic) NSMutableDictionary *peripheral_dict;
@property UInt8 scanning;
@property (strong, nonatomic) NSString *fileName;
@property (strong, nonatomic) NSMutableDictionary *peripheral_timestamp;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.central = [[CBCentralManager alloc] initWithDelegate:self queue:nil
                        options:@{ CBCentralManagerOptionRestoreIdentifierKey:
                        @"BatteryMonitorCentralManagerIdentifier" }];
    
    //self.central = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    self.devices = [[NSMutableArray alloc] init];
    self.peripheral_dict = [[NSMutableDictionary alloc] init];
    self.scanning = 0;
    self.peripheral_timestamp = [[NSMutableDictionary alloc] init];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - CBCentralManagerDelegate

// First time invoke at app launch
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state == CBCentralManagerStatePoweredOn) {
        [central scanForPeripheralsWithServices:nil options:nil];
        self.scanning = 1;
    }
}

// Invoke when resumed app
- (void)centralManager:(CBCentralManager *)central
      willRestoreState:(NSDictionary *)state
{
    //NSArray *peripherals = state[CBCentralManagerRestoredStatePeripheralsKey];
    
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSLog(@"discovered device: %@", peripheral.name);
    NSString *regEx = [NSString stringWithFormat:@"Ting's ACC*"];
    NSRange range = [peripheral.name rangeOfString:regEx options:NSRegularExpressionSearch];
    if (range.location != NSNotFound) {
        if ([self.peripheral_dict objectForKey:[peripheral.identifier UUIDString]] == nil) {
            [self.devices addObject:peripheral];
            [central connectPeripheral:peripheral options:nil];
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"disconnected from %@", peripheral.name);
    [central connectPeripheral:peripheral options:nil];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    [central connectPeripheral:peripheral options:nil];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"connected with %@", peripheral.name);
    peripheral.delegate = self;
    [peripheral discoverServices:@[[CBUUID UUIDWithString:@"1110"], [CBUUID UUIDWithString:@"1809"], [CBUUID UUIDWithString:@"1805"]]];
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (!error) {
        NSLog(@"didDiscoverServices");
        for (CBService *service in peripheral.services) { // 遍历所有服务
            if ([[BLEUtility CBUUIDToString:service.UUID] isEqualToString:@"1110"]) {
                [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:@"1212"]] forService:service];
            } else if ([[BLEUtility CBUUIDToString:service.UUID] isEqualToString:@"1809"]) {
                [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:@"2A1E"]] forService:service];
            } else if ([[BLEUtility CBUUIDToString:service.UUID] isEqualToString:@"1805"]) {
                [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:@"2A08"]] forService:service];
            }
        }
    } else {
        NSLog(@"discover service error");
        [self.central cancelPeripheralConnection:peripheral];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (!error) {
        UInt8 buf[7] = {0};
        
        [self.peripheral_dict setObject:peripheral forKey:[peripheral.identifier UUIDString]];
        [self.peripheral_timestamp setObject:[[NSData alloc] initWithBytes:buf length:7] forKey:peripheral.name];
        
        NSLog(@"didDiscoverCharacteristicsForService");
        if ([[self.peripheral_dict allKeys] count] == 2 && self.scanning == 1) {
            self.scanning = 0;
            NSLog(@"stop scan now");
            [self.central stopScan];
        }
        
        if ([[BLEUtility CBUUIDToString:service.UUID] isEqualToString:@"1110"]) {
            NSLog(@"1110 char discovered");
            [BLEUtility setNotificationForCharacteristic:peripheral sUUID:@"1110" cUUID:@"1212" enable:YES];
        } else if ([[BLEUtility CBUUIDToString:service.UUID] isEqualToString:@"1809"]) {
            NSLog(@"1809 char discovered");
            [BLEUtility setNotificationForCharacteristic:peripheral sUUID:@"1809" cUUID:@"2A1E" enable:YES];
        } else if ([[BLEUtility CBUUIDToString:service.UUID] isEqualToString:@"1805"]) {
            NSLog(@"2A08 char discovered");
            UInt8 buf[7];
            
            NSDateComponents *components = [[NSCalendar currentCalendar] components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:[NSDate date]];
            
            buf[0] = (UInt8)(components.year & 0xFF);
            buf[1] = (UInt8)((components.year & 0xFF00) >> 8);
            buf[2] = (UInt8)(components.month);
            buf[3] = (UInt8)(components.day);
            buf[4] = (UInt8)(components.hour);
            buf[5] = (UInt8)(components.minute);
            buf[6] = (UInt8)(components.second);
            
            
            [BLEUtility writeCharacteristic:peripheral sUUID:@"1805" cUUID:@"2A08" data:[[NSData alloc] initWithBytes:buf length:7]];
        }
    } else {
        NSLog(@"discover char for service error");
        [self.central cancelPeripheralConnection:peripheral];
    }
}

- (void)data_to_int:(uint8_t *)ptr
{
    uint16_t x = 0, y = 0, z = 0;
    uint8_t *buf = ptr;
    uint8_t idx;
    
    for (idx = 0; idx < 3; idx++) {
        if ((buf[1] & 0xC0) == 0x00) {
            x = ((uint16_t)(buf[1] & 0x3F) << 8) | (uint16_t)(buf[0]);
            if (x & 0x1000) {
                x |= 0xC000;
            }
        } else if ((buf[1] & 0xC0) == 0x40) {
            y = ((uint16_t)(buf[1] & 0x3F) << 8) | (uint16_t)(buf[0]);
            if (y & 0x1000) {
                y |= 0xC000;
            }
        } else if ((buf[1] & 0xC0) == 0x80) {
            z = ((uint16_t)(buf[1] & 0x3F) << 8) | (uint16_t)(buf[0]);
            if (z & 0x1000) {
                z |= 0xC000;
            }
        }
        buf += 2;
    }
    ((uint16_t *)ptr)[0] = x;
    ((uint16_t *)ptr)[1] = y;
    ((uint16_t *)ptr)[2] = z;
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *publicDocumentsDir = [paths objectAtIndex:0];
    
    if (!error) {
        if ([[BLEUtility CBUUIDToString:characteristic.UUID] isEqualToString:@"2a1e"]) {
            //NSLog(@"%@", [[NSString alloc] initWithFormat:@"Got temperature from %@\n", peripheral.name]);
            NSString *content;
            uint8_t *ptr = NULL;
            int32_t u32 = 0;
            
            NSDateFormatter *formatter;
            NSString        *dateString;
            
            formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"yyyy-MM-dd HH:mm\n"];
            
            dateString = [formatter stringFromDate:[NSDate date]];
            
            ptr = (uint8_t *)[characteristic.value bytes];
            NSFileHandle *fileHandler = [NSFileHandle fileHandleForUpdatingAtPath:[NSString stringWithFormat:@"%@/%@", publicDocumentsDir, peripheral.name]];
            [fileHandler seekToEndOfFile];
            
            [fileHandler writeData:[dateString dataUsingEncoding:NSUTF8StringEncoding]];
            
            u32 = (uint32_t)ptr[3] << 16 | (uint32_t)ptr[2] << 8 | (uint32_t)ptr[1];
            content = [[NSString alloc] initWithFormat:@"temperature: %f\n", (float)u32/10000.0];
            [fileHandler writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
            
            [fileHandler closeFile];
        } else if ([[BLEUtility CBUUIDToString:characteristic.UUID] isEqualToString:@"1212"]) {
            NSString *content;
            uint8_t *ptr = NULL;
            uint8_t *ptr2 = NULL;
            int16_t *ptr16 = NULL;
            
            NSLog(@"%@ %@", peripheral.name, characteristic.value);
            
            if (characteristic.value.length == 1) {
                NSDateFormatter *formatter;
                NSString        *dateString;
                
                formatter = [[NSDateFormatter alloc] init];
                [formatter setDateFormat:@"yyyy-MM-dd HH:mm "];
                
                dateString = [formatter stringFromDate:[NSDate date]];
                
                ptr = (uint8_t *)[characteristic.value bytes];
                NSFileHandle *fileHandler = [NSFileHandle fileHandleForUpdatingAtPath:[NSString stringWithFormat:@"%@/%@", publicDocumentsDir, peripheral.name]];
                [fileHandler seekToEndOfFile];
                
                [fileHandler writeData:[dateString dataUsingEncoding:NSUTF8StringEncoding]];
                NSString *content = [[NSString alloc] initWithFormat:@"acc \n"];
                [fileHandler writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
                
                [fileHandler closeFile];
            } else if (characteristic.value.length == 8) {
                UInt8 idx, same = 1;
                UInt8 bytes[7];
                
                ptr = (uint8_t *)[characteristic.value bytes];

                NSData *dataPtr = [self.peripheral_timestamp objectForKey:peripheral.name];
                                   
                [dataPtr getBytes:bytes length:7];
                
                for (idx = 0; idx < 7; idx++) {
                    if (ptr[1+idx] != bytes[idx]) {
                        same = 0;
                        break;
                    }
                }
                
                if (same == 0) {
                    NSLog(@"Same!");
                    [self.peripheral_timestamp setObject:[[NSData alloc] initWithBytes:&ptr[1] length:7] forKey:peripheral.name];
                    
                    NSFileHandle *fileHandler = [NSFileHandle fileHandleForUpdatingAtPath:[NSString stringWithFormat:@"%@/%@", publicDocumentsDir, peripheral.name]];
                    [fileHandler seekToEndOfFile];
                    
                    NSString *content = [[NSString alloc] initWithFormat:@"acc %d %d-%d-%d %d:%d:%d\n",
                                         ptr[0], (UInt16)ptr[1] + (UInt16)ptr[2] * 256, ptr[3], ptr[4], ptr[5], ptr[6], ptr[7]];
                    [fileHandler writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
                    
                    [fileHandler closeFile];
                    
                }
            } else if (characteristic.value.length == 20) {
                NSDateFormatter *formatter;
                NSString        *dateString;
                
                formatter = [[NSDateFormatter alloc] init];
                [formatter setDateFormat:@"yyyy-MM-dd HH:mm\n"];
                
                dateString = [formatter stringFromDate:[NSDate date]];
                
                ptr = (uint8_t *)[characteristic.value bytes];
                NSFileHandle *fileHandler = [NSFileHandle fileHandleForUpdatingAtPath:[NSString stringWithFormat:@"%@/%@", publicDocumentsDir, peripheral.name]];
                [fileHandler seekToEndOfFile];
                
                [fileHandler writeData:[dateString dataUsingEncoding:NSUTF8StringEncoding]];
                
                [self data_to_int:((uint8_t *)(ptr + 2))];
                ptr16 = (uint16_t *)(ptr + 2);
                content = [[NSString alloc] initWithFormat:@"%d %d %d\n", ptr16[0], ptr16[1], ptr16[2]];
                [fileHandler writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
                
                [self data_to_int:((uint8_t *)(ptr + 2 + 6))];
                ptr16 = (uint16_t *)(ptr + 2 + 6);
                content = [[NSString alloc] initWithFormat:@"%d %d %d\n", ptr16[0], ptr16[1], ptr16[2]];
                [fileHandler writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
                
                [self data_to_int:((uint8_t *)(ptr + 2 + 12))];
                ptr16 = (uint16_t *)(ptr + 2 + 12);
                content = [[NSString alloc] initWithFormat:@"%d %d %d\n", ptr16[0], ptr16[1], ptr16[2]];
                [fileHandler writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
                
                [fileHandler closeFile];
            }
        }
    } else {
        NSLog(@"didUpdateValueForChar error");
        [self.central cancelPeripheralConnection:peripheral];
    }
}

@end
