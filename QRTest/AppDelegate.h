//
//  AppDelegate.h
//  QRTest
//
//  Created by Jeff Wintersinger on 12-05-17.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSImageView *imageLOL;
@property (weak) IBOutlet NSTextField *partIDsInput;
- (IBAction)generateQrCodeButtonPressed:(id)sender;

@end
