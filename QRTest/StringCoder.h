//
//  StringCoder.h
//  QRTest
//
//  Created by Huge Bonner on 12-05-31.
//  Copyright (c) 2012 Huge Bonner Inc. All rights reserved.
//

#import <Foundation/Foundation.h>



@interface StringCoder : NSObject
- (const unsigned char*) mapping;
- (void) encodeQrText:(NSData*)payload intoBuffer:(unsigned char**)encoded encodedLength:(size_t*)encodedLength;
- (void) decodeQrText:(const unsigned char*)encoded intoBuffer:(uint16_t**)decoded elementCount:(size_t*)elementCount;
@end
