//
//  TPNewCommandsViewController.h
//  TeXnicle
//
//  Created by Martin Hewitson on 17/7/12.
//  Copyright (c) 2012 bobsoft. All rights reserved.
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

#import <Cocoa/Cocoa.h>
#import "HHValidatedButton.h"

@class TPNewCommandsViewController;
@class TPNewCommand;

@protocol TPNewCommandsViewDelegate <NSObject>

- (NSArray*) commandsViewlistOfFiles:(TPNewCommandsViewController*)aView;
- (NSArray*) commandsView:(TPNewCommandsViewController*)aView newCommandsForFile:(id)file;
- (void) commandsView:(TPNewCommandsViewController*)aView didSelectNewCommand:(id)aCommand;

@end


@interface TPNewCommandsViewController : NSViewController <NSUserInterfaceValidations, NSOutlineViewDelegate, NSOutlineViewDataSource, TPNewCommandsViewDelegate> {
  
  NSMutableArray *sets;
  NSOutlineView *outlineView;
  id<TPNewCommandsViewDelegate> delegate;
  HHValidatedButton *revealButton;  
}

@property (assign) IBOutlet HHValidatedButton *revealButton;
@property (assign) id<TPNewCommandsViewDelegate> delegate;
@property (assign) IBOutlet NSOutlineView *outlineView;
@property (retain) NSMutableArray *sets;

- (id) initWithDelegate:(id<TPNewCommandsViewDelegate>)aDelegate;

- (void) updateUI;
- (IBAction)reveal:(id)sender;


@end