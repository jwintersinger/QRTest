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
- (unsigned char*) encode:(NSData*)payload;
@end
