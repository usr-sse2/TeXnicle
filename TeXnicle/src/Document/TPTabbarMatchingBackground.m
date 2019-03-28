//
//  TPTabbarMatchingBackground.m
//  TeXnicle
//
//  Created by Martin Hewitson on 13/7/12.
//  Copyright (c) 2012 bobsoft. All rights reserved.
//

#import "TPTabbarMatchingBackground.h"

@interface TPTabbarMatchingBackground ()

@property (strong) NSColor *activeColor;
@property (strong) NSColor *inactiveColor;

@end

@implementation TPTabbarMatchingBackground

- (void) awakeFromNib
{
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self selector:@selector(windowStatusDidChange:) name:NSWindowDidBecomeKeyNotification object:[self window]];
  [nc addObserver:self selector:@selector(windowStatusDidChange:) name:NSWindowDidResignKeyNotification object:[self window]];
  
}

- (void) windowStatusDidChange:(NSNotification*)aNote
{
  [self setNeedsDisplay:YES];
}

@end
