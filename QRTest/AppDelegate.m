//
//  AppDelegate.m
//  QRTest
//
//  Created by Jeff Wintersinger on 12-05-17.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"
#import "qrencode.h"
#import "StringCoder.h"

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

- (void) displayQrCode:(QRcode*)code {
    unsigned char* imageBuffer = NULL;
    unsigned int imageBufferWidth = 0;
    [self generateImageForQrCode:code intoBuffer:&imageBuffer withWidth:&imageBufferWidth];
    [self displayImage:imageBuffer width:imageBufferWidth height:imageBufferWidth];
    
    // This memory should be freed, but corruption results when I do. Fix this when integrated into Presenter.
    //free(imageBuffer);
    //QRcode_free(resultCode);
}

- (IBAction)generateQrCodeButtonPressed:(id)sender {
    NSString* input = [self.partIDsInput stringValue];
    NSData* payload = [self generatePayload:input];

    StringCoder* coder = [[StringCoder alloc] init];
    
    unsigned char* encoded = NULL;
    size_t encodedLength = 0;
    [coder encodeQrText:payload intoBuffer:&encoded encodedLength:&encodedLength];
    
    uint16_t* decoded = NULL;
    size_t elementCount = 0;
    [coder decodeQrText:encoded intoBuffer:&decoded elementCount:&elementCount];
    
    // Must make these four calls rather than simply use QRcode_encodeString(), as QRcode_encodeString() will reject any
    // string encoding hint that's not QR_MODE_8 or QR_MODE_KANJI. (To see the code that does this rejecting, see
    // QRcode_encodeStringReal()'s implementation in libqrencode's qrencode.c.) Only by using QRinput explicitly
    // can we encode with QR_MODE_AN, which does indeed result in smaller QR codes relative to QR_MODE_8.
    // Note that QRinput_new() defaults to initializing a QR code with a low error correction level and version
    // of 0 (meaning that the version [i.e., number of columns/rows] will be set to the minimum possible value).
    QRinput* qrInput = QRinput_new();
    QRinput_append(qrInput, QR_MODE_AN, encodedLength, encoded);
    QRcode* resultCode = QRcode_encodeInput(qrInput);
    QRinput_free(qrInput);
    
    if(resultCode == NULL) {
        NSLog(@"Error creating QR code from encoded data: %s", strerror(errno));
    } else {
        [self displayQrCode:resultCode];
    }
    
    free(encoded);
    free(decoded);
}
@end