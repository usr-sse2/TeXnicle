//
//  TeXnicleAppController.h
//  TeXnicle
//
//  Created by hewitson on 26/5/11.
//  Copyright 2011 bobsoft. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//      * Redistributions of source code must retain the above copyright
//        notice, this list of conditions and the following disclaimer.
//      * Redistributions in binary form must reproduce the above copyright
//        notice, this list of conditions and the following disclaimer in the
//        documentation and/or other materials provided with the distribution.
//  
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL MARTIN HEWITSON OR BOBSOFT SOFTWARE BE LIABLE FOR ANY
//  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
//  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//   LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
//  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import <Foundation/Foundation.h>
#import "TPLibrary.h"
#import "TPPalette.h"
#import "PDFViewer.h"

@class StartupScreenController;

@interface TeXnicleAppController : NSObject <NSApplicationDelegate, PDFViewerDelegate> {
@private
	StartupScreenController *startupScreenController;    
  NSInteger lineToOpen;
}

@property (assign) BOOL openStartupScreenAtAppStartup;
@property (strong) TPLibrary *library;
@property (strong) TPPalette *palette;
@property (strong) PDFViewer *helpViewer;
@property (assign) BOOL didSetup;

- (void) checkVersion;

- (IBAction)showPreferences:(id)sender;
- (id)startupScreen;
- (IBAction) showStartupScreen:(id)sender;

#pragma mark -
#pragma mark Document Control 

- (IBAction) createProjectFromTemplate:(id)sender;
- (IBAction) newEmptyProject:(id)sender;
- (IBAction) newArticleDocument:(id)sender;
- (IBAction) buildNewProject:(id)sender;
- (IBAction) newLaTeXFile:(id)sender;
- (IBAction)showUserManual:(id)sender;

@end
