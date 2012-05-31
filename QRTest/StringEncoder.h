//
//  StringEncoder.h
//  QRTest
//
//  Created by Huge Bonner on 12-05-31.
//  Copyright (c) 2012 Huge Bonner Inc. All rights reserved.
//

#import <Foundation/Foundation.h>



@interface StringEncoder : NSObject
- (const unsigned char*) mapping;
- (void) encode:(NSData*)payload intoBuffer:(unsigned char**)encoded encodedLength:(size_t*)encodedLength;
- (void) decode:(const unsigned char*)encoded intoBuffer:(uint16_t**)decoded elementCount:(size_t*)elementCount;
@end
