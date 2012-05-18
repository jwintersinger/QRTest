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

- (void)displaySolidColour
{
    unsigned int width = self.imageLOL.frame.size.width;
    unsigned int height = self.imageLOL.frame.size.height;
    width = 40;
    height = 40;
    
    unsigned char samplesPerPixel= 1;
    unsigned char bitsPerSample = 8;
    unsigned int bufferSize = samplesPerPixel * width * height;
    
    unsigned char* bytes = malloc(bufferSize);
    memset(bytes, 0xff, bufferSize);
    
    unsigned char color = 0x80;
    unsigned int blockWidth = 5;
    for(int i = 0; i < bufferSize; i += width - 0) {
        bytes[i] = color;
    }
    
    NSBitmapImageRep* bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:&bytes 
                                                                       pixelsWide:width 
                                                                       pixelsHigh:height
                                                                    bitsPerSample:bitsPerSample 
                                                                  samplesPerPixel:samplesPerPixel 
                                                                         hasAlpha:NO 
                                                                         isPlanar:NO 
                                                                   colorSpaceName:NSCalibratedWhiteColorSpace
                                                                      bytesPerRow:width * samplesPerPixel
                                                                     bitsPerPixel:bitsPerSample * samplesPerPixel];
    NSImage* image = [[NSImage alloc] init];
    [image addRepresentation:bitmap];
    [self.imageLOL setImage:image];
    
    free(bytes);
}

- (QRcode*) generateQrCode
{
    unsigned int payloadSize = 5;
    unsigned char* payload = malloc(payloadSize);
    for(int i = 0; i < payloadSize; i++) {
        payload[i] = 255 - i;
    }
    
    QRcode* resultCode = QRcode_encodeData(payloadSize, payload, 0, QR_ECLEVEL_L);
    free(payload);
    return resultCode;
}

- (void) generateImageForQrCode:(QRcode*)resultCode intoBuffer:(unsigned char**)imageBuffer withWidth:(unsigned int*)imageBufferWidth
{ 
    unsigned char blockPixelWidth = 10;
    unsigned int blockPixelSize = blockPixelWidth * blockPixelWidth;
    
    unsigned int blocksPerRow = resultCode->width;
    *imageBufferWidth = blockPixelWidth * blocksPerRow;
    unsigned int imageBufferSize = (*imageBufferWidth) * (*imageBufferWidth);
    
    *imageBuffer = malloc(imageBufferSize);
    memset(*imageBuffer, 0xff, imageBufferSize);
    
    
    
    for(int blockIndex = 0; blockIndex < blocksPerRow * blocksPerRow; blockIndex++) {
        zif(!(resultCode->data[blockIndex] & 0x01)) continue;
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
    QRcode* resultCode = [self generateQrCode];
    
    unsigned char* imageBuffer = NULL;
    unsigned int imageBufferWidth = 0;
    [self generateImageForQrCode:resultCode intoBuffer:&imageBuffer withWidth:&imageBufferWidth];
    [self displayImage:imageBuffer width:imageBufferWidth height:imageBufferWidth];
    
    free(imageBuffer);
    QRcode_free(resultCode);
}

@end