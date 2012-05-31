//
//  StringEncoder.m
//  QRTest
//
//  Created by Huge Bonner on 12-05-31.
//  Copyright (c) 2012 Huge Bonner Inc. All rights reserved.
//

#import "StringEncoder.h"

// Taken directly from QR code specification, p. 21: http://raidenii.net/files/datasheets/misc/qr_code.pdf
// Note that this uses only the first 41 of 45 characters permitted by the QR code specification. The
// remaining four characters ('-', '.', '/', ':') are unnecessary, as
// lg(41) = 16.07 >= 16 = sizeof(uint16_t).
static const unsigned char base41Mapping[] = {
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J',
    'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T',
    'U', 'V', 'W', 'X', 'Y', 'Z',
    ' ', '$', '%', '*', '+'
};
static const uint8_t base41MappingSize = sizeof(base41Mapping);

@implementation StringEncoder

- (const unsigned char*)mapping { return base41Mapping; }
- (uint8_t)mappingSize { return base41MappingSize; }

// Map each uint16_t in payload to a three-character string.
- (void) encode:(NSData*)payload intoBuffer:(unsigned char**)encoded encodedLength:(size_t*)encodedLength {
    uint8_t individualElementSize = sizeof(uint16_t);
    uint16_t maxElementValue = UINT16_MAX;
    uint8_t base = [self mappingSize];
    // Number of digits in encoded format needed to represent each element.
    NSUInteger digitsPerElement = ceil(log2(maxElementValue) / log2(base));
    
    // Append padding if necessary.
    NSMutableData* paddedPayload = [NSMutableData dataWithData:payload];
    NSUInteger paddingBytesNeeded = [paddedPayload length] % individualElementSize;
    if(paddingBytesNeeded != 0) {
        unsigned char* padding = malloc(paddingBytesNeeded);
        memset(padding, 0, paddingBytesNeeded);
        [paddedPayload appendBytes:padding length:paddingBytesNeeded];
        free(padding);
    }
    
    NSUInteger elementCount = [paddedPayload length] / individualElementSize;
    *encodedLength = digitsPerElement * elementCount;
    // Add one to allow space for string null terminator.
    *encoded = malloc(*encodedLength + 1);
    *(*encoded + *encodedLength) = 0;
    
    const uint16_t* payloadBytes = [paddedPayload bytes];
    for(int i = 0; i < elementCount; i++) {
        uint16_t element = *(payloadBytes + i);
        NSLog(@"At %p: %d", payloadBytes + i, element);
        
        const int8_t highestExp = digitsPerElement - 1;
        // exp must be signed so that it can become -1, allowing loop to terminate.
        for(int8_t exp = highestExp; exp >= 0; exp--) {
            uint16_t divisor = pow(base, exp);
            uint8_t mapIndex = element / divisor;
            *(*encoded + (digitsPerElement * i) + (highestExp - exp)) = [self mapping][mapIndex];
            element %= divisor;
        }
    }
}

- (uint8_t)valueForChar:(unsigned char)chr {
    for(uint8_t i = 0; i < [self mappingSize]; i++) {
        if([self mapping][i] == chr)
            return i;
    }
    return 0;
}

- (void) decode:(const unsigned char*)encoded intoBuffer:(uint16_t**)decoded elementCount:(size_t*)elementCount {
    size_t encodedLength = strlen((const char*)encoded);
    uint8_t digitsPerElement = 3;
    NSAssert(encodedLength % digitsPerElement == 0, @"Encoded data length isn't multiple of element size");
    
    *elementCount = encodedLength / digitsPerElement;
    *decoded = malloc(sizeof(uint16_t) * *elementCount);
    
    for(size_t i = 0; i < *elementCount; i++) {
        uint16_t decodedElement = 0;
        
        for(uint8_t j = 0; j < digitsPerElement; j++) {
            uint8_t val = [self valueForChar:encoded[(digitsPerElement * i) + j]];
            decodedElement += val * pow([self mappingSize], digitsPerElement - 1 - j);
        }
        
        *(*decoded + i) = decodedElement;
    }
}

@end
