//
//  TPPopupListWindow.m
//  TeXnicle
//
//  Created by Martin Hewitson on 15/5/10.
//  Copyright 2010 bobsoft. All rights reserved.
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

#import "TPPopupListWindowController.h"
#import "TPThemeManager.h"

#define MAX_ENTRY_LENGTH 200
#define kCompletionWindowMaxWidth 1000

@implementation TPPopupListWindowController

- (id) initWithEntries:(NSArray*)entryArray 
							 atPoint:(NSPoint)aPoint 
				inParentWindow:(NSWindow*)aWindow
								mode:(NSUInteger)aMode
								 title:(NSString*)aTitle
{
	self = [super initWithNibName:@"TPPopuplistView" bundle:nil];
	
	if (self) {
    attachedWindow = nil;
		self.isVisible = NO;
		[self setTitle:aTitle];
		self.mode = aMode;
		parentWindow = aWindow;
		entries = [[NSMutableArray alloc] initWithCapacity:[entryArray count]];
		for (id entry in entryArray) {
      [entries addObject:entry];
		}
		point = aPoint;
		
		TPPopuplistView *view = (TPPopuplistView*)[self view];
		[view setDelegate:self];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleWindowDidResignKeyNotification)
                                                 name:NSWindowDidResignKeyNotification
                                               object:[self window]];
    
	}
	
	return self;
}

- (void) handleWindowDidResignKeyNotification
{
  [self dismiss];
}

- (void)setList:(NSArray*)aList
{
  [entries removeAllObjects];
  [entries addObjectsFromArray:aList];
  [table reloadData];
}

- (void) awakeFromNib
{
	[self setupWindow];
}

- (void) setupWindow
{
	if (!attachedWindow) {
		NSView *view = [self view];
		CGFloat rowHeight = [table rowHeight];
		CGFloat width = 200.0;
		CGFloat height = MAX(150.0, 20.0 + rowHeight*(1+[entries count]));
		
		if (height > 200)
			height = 200;
		
//    NSLog(@"Row height: %f", rowHeight);
//    NSLog(@"Table height: %f", 20.0 + rowHeight*(1+[entries count]));
//    NSLog(@"Setting height %f", height);
    
		// get max width of entries
		NSDictionary *f = @{NSFontAttributeName: [NSFont systemFontOfSize:12.0]};		
//		NSLog(@"Font atts: %@", f);
		CGFloat maxWidth = 0;
		if (f) {
			for (id entry in entries) {
        NSSize s = NSZeroSize;
        
        if ([entry respondsToSelector:@selector(attributedString)]) {
          s = [[entry attributedString] size];
        } else if ([entry respondsToSelector:@selector(string)]) {
          s = [[entry string] sizeWithAttributes:f];
        } else {
          s = [entry sizeWithAttributes:f];
        }
        
        if (s.width > maxWidth) {
					maxWidth = s.width;
				}
			}
		}
    
		if (maxWidth > kCompletionWindowMaxWidth)
			maxWidth = kCompletionWindowMaxWidth;
		
		
		width = MAX(width, maxWidth);
    
    MAWindowPosition pos = MAPositionBottomRight;
		
    // compare point on screen coordinates to check if the 
    // window will be off the bottom of the screen
    NSRect r = [parentWindow convertRectToScreen:NSMakeRect(point.x, point.y, 1, 1)];
    NSPoint screenPoint = r.origin;
    CGFloat y = screenPoint.y - height;
    if (y<0) {
      pos = MAPositionTopRight;
    }
    
		[view setFrame:NSMakeRect(0, 0, width+20.0, height)];
    if (attachedWindow == nil) {
      attachedWindow = [[MAAttachedWindow alloc] initWithView:view
                                              attachedToPoint:point
                                                     inWindow:parentWindow
                                                       onSide:pos
                                                   atDistance:5.0];
    }
    
    TPThemeManager *tm = [TPThemeManager sharedManager];
    TPTheme *theme = tm.currentTheme;
    
		[attachedWindow setBorderColor:[NSColor clearColor]];
		[attachedWindow setBackgroundColor:theme.documentEditorBackgroundColor];
    [table setBackgroundColor:theme.documentEditorBackgroundColor];
    
		[attachedWindow setViewMargin:5.0];
		[attachedWindow setBorderWidth:3.0];
		[attachedWindow setCornerRadius:5.0];
		[attachedWindow setHasArrow:NO];
		[attachedWindow setDrawsRoundCornerBesideArrow:YES];
		
    if (self.title) {
      [titleView setStringValue:self.title];
    }
	} // end if !attachedWindow
}

//- (void)keyDown:(NSEvent *)theEvent
//{
//  [self.delegate keyDown:theEvent];
//}

- (void) dealloc
{
  self.delegate = nil;
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self dismiss];
}

- (void) moveToPoint:(NSPoint)aPoint
{
  point = aPoint;
  [attachedWindow moveToPoint:aPoint];
  [attachedWindow displayIfNeeded];
}

- (NSPoint)currentPoint
{
  return [attachedWindow currentPoint];
}


- (void) showPopup
{
	[self setupWindow];
	[parentWindow addChildWindow:attachedWindow ordered:NSWindowAbove];	
	[attachedWindow makeFirstResponder:table];
	[table selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
  self.isVisible = YES;
}

- (IBAction)moveUp:(id)sender
{
  [table moveUp:sender];
}

- (IBAction)moveDown:(id)sender
{
  [table moveDown:sender];
}

- (void) dismiss
{
  if (attachedWindow == nil || parentWindow == nil) {
    return;
  }
  
	if ([[parentWindow childWindows] containsObject:attachedWindow]) {
		[parentWindow removeChildWindow:attachedWindow];
	}
	if (attachedWindow) {
		[attachedWindow close];
		attachedWindow = nil;
	}
  self.isVisible = NO;
  
  if (self.delegate && [self.delegate respondsToSelector:@selector(didDismissPopupList)]) {
    [self.delegate performSelector:@selector(didDismissPopupList)];
  }
}


#pragma mark -
#pragma mark List View delegate

- (NSString*)selectedValue
{
  NSInteger row = [table selectedRow];
  if (row<0) {
    row = 0;
  }
  if ([[self filteredEntries] count] == 0) {
    return nil;
  }
  
	id value = [self filteredEntries][row];
  NSString *tag = @"";
  if ([value respondsToSelector:@selector(tag)]) {
    tag = [value valueForKey:@"tag"];
  } else if ([value respondsToSelector:@selector(string)]) {
    tag = [value string];
  } else {
    tag = value;
  }
  
  return tag;
}

- (IBAction)selectSelectedItem:(id)sender
{
  NSInteger row = [table selectedRow];
  [self userSelectedRow:@(row)];
}

- (void) userSelectedRow:(NSNumber*)aRow
{
  NSString *tag = [self selectedValue];
  
	if (self.mode == TPPopupListInsert) {
		if (self.delegate && [self.delegate respondsToSelector:@selector(insertWordAtCurrentLocation:)]) {
			[self.delegate performSelector:@selector(insertWordAtCurrentLocation:) withObject:tag];
		}
	} else if (self.mode == TPPopupListSpell) {
		if (self.delegate && [self.delegate respondsToSelector:@selector(replaceWordAtCurrentLocationWith:)]) {
			[self.delegate performSelector:@selector(replaceWordAtCurrentLocationWith:) withObject:tag];
		}
	} else if (self.mode == TPPopupListReplace) {
		if (self.delegate && [self.delegate respondsToSelector:@selector(replaceWordUpToCurrentLocationWith:)]) {
			[self.delegate performSelector:@selector(replaceWordUpToCurrentLocationWith:) withObject:tag];
		}
	}
  
//  if (self.delegate && [self.delegate respondsToSelector:@selector(didSelectPopupListItem)]) {
//    [self.delegate performSelector:@selector(didSelectPopupListItem)];
//  }
  
  
}

#pragma mark -
#pragma mark Table delegate


- (id)tableView:(NSTableView *)tableView 
objectValueForTableColumn:(NSTableColumn *)tableColumn 
						row:(NSInteger)row;
{
	if (tableView == table) {
    
		id value = [self filteredEntries][row];
    
    BOOL isHighlighted = [tableView selectedRow] == row;
    
    
    if (isHighlighted && [value respondsToSelector:@selector(alternativeAttributedString)]) {
      NSAttributedString *str = [value performSelector:@selector(alternativeAttributedString)];
//      NSLog(@"alternativeAttributedString: %@", str);
      return str;
    } else if ([value respondsToSelector:@selector(attributedString)]) {
      NSAttributedString *str = [value attributedString];
//      NSLog(@"attributedString: %@", str);
      return str;
    } else if ([value respondsToSelector:@selector(string)]) {
      NSString *str = [value string];
//      NSLog(@"string: %@", str);
      NSMutableAttributedString *att = [[NSMutableAttributedString alloc] initWithString:str];
      return att;
    } else {
      // if we have a string, then we should color it if necessary
      if ([value isKindOfClass:[NSString class]]) {
        NSMutableAttributedString *att = [[NSMutableAttributedString alloc] initWithString:value];
        return att;
      }
      
      return value;
    }
    
	}
	return nil;
}


- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
  TPThemeManager *tm = [TPThemeManager sharedManager];
  TPTheme *theme = tm.currentTheme;
  NSTextFieldCell *cell = [tableColumn dataCell];
  
  BOOL isHighlighted = [tableView selectedRow] == row;
  if (isHighlighted) {
    [cell setTextColor:theme.documentEditorSelectionColor];
  } else {
    [cell setTextColor:theme.documentTextColor];
  }
  return cell;
}


- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView;
{
	if (tableView == table) {
		return [[self filteredEntries] count];
	}		
	
	return 0;
}

- (NSArray*) filteredEntries
{
  return entries;
}

-(NSWindow*)window
{
  return attachedWindow;
}


@end
