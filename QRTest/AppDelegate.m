//
//  AppDelegate.m
//  QRTest
//
//  Created by Jeff Wintersinger on 12-05-17.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"
#import "qrencode.h"

@implementation AppDelegate

@synthesize window = _window;
@synthesize imageLOL = _imageLOL;
@synthesize partIDsInput = _partIDsInput;

- (void) generateImageForQrCode:(QRcode*)resultCode intoBuffer:(unsigned char**)imageBuffer withWidth:(unsigned int*)imageBufferWidth
{ 
    unsigned char blockPixelWidth = 15;
    unsigned int blockPixelSize = blockPixelWidth * blockPixelWidth;
    
    unsigned int blocksPerRow = resultCode->width;
    *imageBufferWidth = blockPixelWidth * blocksPerRow;
    unsigned int imageBufferSize = (*imageBufferWidth) * (*imageBufferWidth);
    
    *imageBuffer = malloc(imageBufferSize);
    memset(*imageBuffer, 0xff, imageBufferSize);
    
    
    
    for(int blockIndex = 0; blockIndex < blocksPerRow * blocksPerRow; blockIndex++) {
        if(!(resultCode->data[blockIndex] & 0x01)) continue;
        //NSLog(@"bi = %d", blockIndex);
        //if(blockIndex != 284 && blockIndex != 285 && blockIndex != 11286) continue;
        
        unsigned int blockRow = blockIndex / blocksPerRow;
        unsigned int blockCol = blockIndex % blocksPerRow;
        unsigned char* base = (*imageBuffer) + (blockPixelSize * blockRow * blocksPerRow) + (blockPixelWidth * blockCol);     
        
        for(unsigned char j = 0; j < blockPixelWidth; j++) {
            memset(base + (j * *imageBufferWidth), 0x00, blockPixelWidth);
        }
    }
}

- (void) displayImage:(unsigned char*)imageBuffer width:(NSInteger)width height:(NSInteger)height
{
    unsigned char samplesPerPixel = 1;
    unsigned char bitsPerSample = 8;
    
    NSBitmapImageRep* bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:&imageBuffer
                                                                       pixelsWide:width 
                                                                       pixelsHigh:height
                                                                    bitsPerSample:bitsPerSample 
                                                                  samplesPerPixel:samplesPerPixel 
                                                                         hasAlpha:NO 
                                                                         isPlanar:NO 
                                                                   colorSpaceName:@"NSCalibratedWhiteColorSpace"
                                                                      bytesPerRow:width * samplesPerPixel
                                                                     bitsPerPixel:bitsPerSample * samplesPerPixel];
    NSImage* image = [[NSImage alloc] init];
    [image addRepresentation:bitmap];
    //[self.imageLOL setImageScaling:NSScaleToFit];
    [self.imageLOL setImage:image];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //[self displaySolidColour];

}

- (NSIndexSet*) generateRangeFromString:(NSString*)inString {
    NSArray* components = [inString componentsSeparatedByString:@","];
    NSMutableIndexSet* indexSet = [NSMutableIndexSet indexSet];
    
    // Note that if user specifies invalid part ID (e.g., via
    // "atlas://parts/?pants", the integerValue call will convert this to zero.
    // As such, the part at index 0 will be loaded in such a case. Though we
    // could work around this, it doesn't seem worth the required effort.
    for(NSString* component in components) {
        NSString* trimmed = [component stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        if([trimmed rangeOfString:@"-"].location != NSNotFound) {
            NSArray* rangeIndexes = [trimmed componentsSeparatedByString:@"-"];
            if ([rangeIndexes count] != 2) continue;
            
            // Note that if you attempt to access a negative index
            // ("atlas://parts/?-1"), we shall hit this code path, with a=""
            // and b="1". As the empty string's integerValue is deemed to be 0,
            // we then attempt to load parts in the range [0, 1].
            NSInteger a = [[rangeIndexes objectAtIndex:0] integerValue];
            NSInteger b = [[rangeIndexes objectAtIndex:1] integerValue];
            
            // [a, b] must specify valid range.
            if(!(b > a && a >= 0)) continue;
            
            NSRange range = NSMakeRange(a, b - a + 1);
            [indexSet addIndexesInRange:range];
        } else {
            NSInteger index = [component integerValue];
            // Index can't be negative.
            if(index < 0) continue;
            [indexSet addIndex:index];
        }
    }
    return indexSet;
}

- (NSData*) generatePayloadHeaderWithBodyLength:(NSUInteger)bodyLength showBody:(BOOL)showBody {
    NSAssert(bodyLength <= UINT16_MAX, @"Body length exceeds header capacity");
    
    uint8_t flags = 0;
    if(showBody) flags |= 0x80;
    
    uint8_t version = 1;
    uint16_t partIdsByteCount  = bodyLength;
    
    NSMutableData* header = [[NSMutableData alloc] initWithCapacity:4];
    [header appendBytes:&version length:sizeof(version)];
    [header appendBytes:&flags length:sizeof(flags)];
    [header appendBytes:&partIdsByteCount length:sizeof(partIdsByteCount)];

    return header;
}

- (NSData*) generatePayloadBody:(NSString*)partIds {

    NSString* trimmedInput = [partIds stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSMutableData* payload = [NSMutableData dataWithCapacity:100];
   
    if([trimmedInput length] == 0) return payload;
    NSIndexSet* partIDs = [self generateRangeFromString:trimmedInput];
    
    NSUInteger currentPartId = [partIDs firstIndex];
    BOOL insideRange = NO;
    
    while(currentPartId != NSNotFound) {
        if(currentPartId >= 4096) {
            NSLog(@"Ignoring part ID %ld (and all subsequent ones), as data format requires part ID to be less than 2^12",
                  currentPartId);
            break;
        }
        
        uint16_t partIdEncoded = (uint16_t)currentPartId;
        NSUInteger nextPartId = [partIDs indexGreaterThanIndex:currentPartId];
        
        if(nextPartId - currentPartId == 1) {
            // We're already in the middle of a range, so do nothing.
            if(insideRange) {
                currentPartId = nextPartId;
                continue;
            }
            
            // We're not currently in a range, so start a new one.
            insideRange = YES;
            // Set left-most bit to 1 to indicate that current partId starts new range.
            partIdEncoded |= 0x8000;
        } else {
            // We are either at the end of a range or outside a range entirely.
            insideRange = NO;
        }
        
        [payload appendBytes:&partIdEncoded length:sizeof(partIdEncoded)];
        currentPartId = nextPartId;
    }
    
    return payload;    
}

- (NSData*) generatePayload:(NSString*)partIds {
    NSData* body = [self generatePayloadBody:partIds];
    NSData* header = [self generatePayloadHeaderWithBodyLength:[body length] showBody:YES];
    
    NSMutableData* combined = [[NSMutableData alloc] initWithCapacity:([header length] + [body length])];
    [combined appendData:header];
    [combined appendData:body];
    
    return combined;
}

// Map each uint16_t in payload to a three-character string.
- (unsigned char*) encodePayload:(NSData*)payload {
    // Taken directly from QR code specification, p. 21: http://raidenii.net/files/datasheets/misc/qr_code.pdf
    // Note that this uses only the first 41 of 45 characters permitted by the QR code specification. The
    // remaining four characters ('-', '.', '/', ':') are unnecessary, as
    // lg(41) = 16.07 >= 16 = sizeof(uint16_t).
    unsigned char baseMapping[] = {
        '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
        'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J',
        'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T',
        'U', 'V', 'W', 'X', 'Y', 'Z',
        ' ', '$', '%', '*', '+'
    };
    
    uint8_t individualElementSize = sizeof(uint16_t);
    uint16_t maxElementValue = UINT16_MAX;
    uint8_t base = sizeof(baseMapping);
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
    NSUInteger encodedLength = digitsPerElement * elementCount;
    // Add one to allow space for string null terminator.
    unsigned char* encoded = malloc(encodedLength + 1);
    *(encoded + encodedLength) = 0;
    
    const uint16_t* payloadBytes = [paddedPayload bytes];
    for(int i = 0; i < elementCount; i++) {
        uint16_t element = *(payloadBytes + i);
        NSLog(@"At %p: %d", payloadBytes + i, element);
        
        const int8_t highestExp = digitsPerElement - 1;
        // exp must be signed so that it can become -1, allowing loop to terminate.
        for(int8_t exp = highestExp; exp >= 0; exp--) {
            uint16_t divisor = pow(base, exp);
            uint8_t mapIndex = element / divisor;
            *(encoded + (digitsPerElement * i) + (highestExp - exp)) = baseMapping[mapIndex];
            element %= divisor;
        }
    }
    
    return encoded;
}

- (IBAction)generateQrCodeButtonPressed:(id)sender {
    NSString* input = [self.partIDsInput stringValue];
    NSData* payload = [self generatePayload:input];
    // Note that third paramemter to QRcode_encodeData specifies version number
    // (i.e., number of rows/columns in QR code). If equal to 0, as minimum value is chosen.
    NSLog(@"Payload: %@ (%ld)", payload, [payload length]);
    
    for(int i = 0; i < [payload length]; i++) {
        printf("%hhx ", *((unsigned char*)[payload bytes] + i));
    }
    printf("\n");
    
    unsigned char* happyPayload = malloc(4);
    happyPayload[0] = 1;
    happyPayload[1] = 2;
    happyPayload[2] = 3;
    happyPayload[3] = 4;
    NSData* testPayload = [NSData dataWithBytes:happyPayload length:4];
    NSLog(@"Test payload: %s", [self encodePayload:testPayload]);
    
    //QRcode* resultCode = QRcode_encodeData([payload length], (unsigned char*)[payload bytes], 0, QR_ECLEVEL_L);
    /*QRcode* resultCode = QRcode_encodeString8bit(<#const char *string#>, <#int version#>, <#QRecLevel level#>)
    
    unsigned char* imageBuffer = NULL;
    unsigned int imageBufferWidth = 0;
    [self generateImageForQrCode:resultCode intoBuffer:&imageBuffer withWidth:&imageBufferWidth];
    [self displayImage:imageBuffer width:imageBufferWidth height:imageBufferWidth];
    
    // This memory should be freed, but corruption results when I do. Fix this when integrated into Presenter.
    //free(imageBuffer);
    QRcode_free(resultCode);*/
}
@end