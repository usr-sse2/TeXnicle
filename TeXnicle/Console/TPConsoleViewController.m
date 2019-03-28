//
//  TPConsoleViewControllerViewController.m
//  TeXnicle
//
//  Created by Martin Hewitson on 10/03/12.
//  Copyright (c) 2012 bobsoft. All rights reserved.
//
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

#import "TPConsoleViewController.h"
#import "externs.h"
#import "TPThemeManager.h"

@interface TPConsoleViewController ()

@property (nonatomic, retain) IBOutlet NSSegmentedControl *viewSelector;
@property (nonatomic, retain) IBOutlet NSTabView *tabView;
@property (nonatomic, retain) IBOutlet NSView *logViewContainer;
@property (nonatomic, retain) TPTeXLogViewController *logViewController;
@property (nonatomic, retain) IBOutlet NSTextView *textView;
@property (nonatomic, retain) IBOutlet NSPopUpButton *displayLevel;
@property (nonatomic, retain) IBOutlet MHStrokedFiledView *toolbarView;


@end

@implementation TPConsoleViewController

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id) initWithDelegate:(id<TPConsoleDelegate>)aDelegate
{
  self = [super initWithNibName:@"TPConsoleViewController" bundle:nil];
  if (self) {
    
    self.delegate = aDelegate;
    
    // Initialization code here.
    TPThemeManager *tm = [TPThemeManager sharedManager];
    TPTheme *theme = tm.currentTheme;
    [self.textView setFont:theme.consoleFont];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(handleThemeChanged:)
               name:TPThemeSelectionChangedNotification
             object:nil];
        
    
  }
  
  return self;
}

- (IBAction)selectView:(id)sender
{
  NSInteger idx = [self.viewSelector selectedSegment];
  [self.tabView selectTabViewItemAtIndex:idx];
  [self didSelectConsoleView:idx];
}


- (void)awakeFromNib
{
  NSColor *color1 = [NSColor controlBackgroundColor];
  [self.toolbarView setFillColor:color1];
  
  self.logViewController = [[TPTeXLogViewController alloc] initWithParsedLog:nil delegate:self];
  [self.logViewController.view setFrame:self.logViewContainer.bounds];
  [self.logViewContainer addSubview:self.logViewController.view];
  
  [self setupTextview];
  
  [self setupUI];
}

- (void) setupUI
{
  [self.viewSelector selectSegmentWithTag:[self consoleView]];
  [self.tabView selectTabViewItemAtIndex:[self consoleView]];
  
  [self.displayLevel selectItemAtIndex:[self logOutputLevel]];
  [self.logViewController showLogInfoItems:[self showLogInfoItems]];
  [self.logViewController showLogWarningItems:[self showLogWarningItems]];
  [self.logViewController showLogErrorItems:[self showLogErrorItems]];
  
}

- (void) setupTextview
{
  TPTheme *theme = [TPThemeManager currentTheme];
	[self.textView setFont:theme.consoleFont];
  [self.textView setTextColor:theme.documentTextColor];
  [self.textView setBackgroundColor:theme.documentEditorBackgroundColor];
}


- (void) loadLogAtPath:(NSString*)path
{
  if (path != nil) {
    TPParsedLog *log = [[TPParsedLog alloc] initWithLogFileAtPath:path];
    self.logViewController.log = log;
  }
}

- (void) handleThemeChanged:(NSNotification*)aNote
{
  [self setupTextview];
}

- (void) clear
{
  [self clear:self];
}

- (IBAction) clear:(id)sender
{
	NSTextStorage *textStorage = [self.textView textStorage];
	[textStorage deleteCharactersInRange:NSMakeRange(0, [textStorage length])];	
}

- (IBAction) displayLevelChanged:(id)sender
{
  if (sender == self.displayLevel) {
    [self didChangeLogOutputLevel:[self.displayLevel indexOfSelectedItem]];
  }
}


- (void) error:(NSString*)someText 
{
  TPThemeManager *tm = [TPThemeManager sharedManager];
  TPTheme *theme = tm.currentTheme;
  NSFont *font = theme.consoleFont;
	if ([someText length]>0) {
		if ([someText characterAtIndex:[someText length]-1] != '\n') {
			someText = [someText stringByAppendingString:@"\n"];
		}
		NSMutableAttributedString *attstr = [[NSMutableAttributedString alloc] initWithString:someText]; 
		NSRange stringRange = NSMakeRange(0, [attstr length]);
		[attstr addAttribute:NSForegroundColorAttributeName
									 value:[NSColor redColor]
									 range:stringRange];
    [attstr addAttribute:NSFontAttributeName
                   value:font
                   range:stringRange];
		[[self.textView textStorage] appendAttributedString:attstr];
		[self.textView moveToEndOfDocument:self];
	}
}

- (void) message:(NSString*)someText 
{
	if ([self.displayLevel indexOfSelectedItem] < TPConsoleDisplayErrors) {
		[self appendText:someText withColor:[NSColor blueColor]];
	}
}


- (void) appendText:(NSString *)someText
{
	if ([self.displayLevel indexOfSelectedItem] < TPConsoleDisplayTeXnicle) {
		[self appendText:someText withColor:nil];
	}
}

- (void) appendText:(NSString*)someText withColor:(NSColor*)aColor
{
  TPTheme *theme = [TPThemeManager currentTheme];
  NSFont *font = theme.consoleFont;
  NSString *str = [someText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	NSColor *textColor = aColor;
	if (!textColor) {
		textColor = theme.documentTextColor;
	}
	NSArray *strings = [str componentsSeparatedByString:@"\n"];
	
	for (__strong NSString *string in strings) {
		string = [string stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
		if ([string length]>0) {
			if ([string characterAtIndex:[string length]-1] != '\n') {
				string = [string stringByAppendingString:@"\n"];
			}
			NSMutableAttributedString *attstr = [[NSMutableAttributedString alloc] initWithString:string]; 
			NSRange stringRange = NSMakeRange(0, [attstr length]);
			[attstr addAttribute:NSForegroundColorAttributeName
										 value:textColor
										 range:stringRange];
      [attstr addAttribute:NSFontAttributeName
                     value:font
                     range:stringRange];
			[[self.textView textStorage] appendAttributedString:attstr];
		}
	}
	
  [self.textView moveToEndOfDocument:self];
}

#pragma mark -
#pragma mark log parser delegate

- (void) texlogview:(TPTeXLogViewController *)logview didSelectLogItem:(TPLogItem *)aLog
{
  // pass on to delegate
  if (self.delegate && [self.delegate respondsToSelector:@selector(texlogview:didSelectLogItem:)]) {
    [self.delegate texlogview:logview didSelectLogItem:aLog];
  }
}

- (BOOL) texlogview:(TPTeXLogViewController *)logview shouldShowEntriesForFile:(NSString *)aFile
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(texlogview:shouldShowEntriesForFile:)]) {
    return [self.delegate texlogview:logview shouldShowEntriesForFile:aFile];
  }
  
  return YES;
}

- (void) shouldShowErrorItems:(BOOL)state
{
  [self didSelectLogErrorItems:state];
}

- (void) shouldShowInfoItems:(BOOL)state
{
  [self didSelectLogInfoItems:state];
}

- (void) shouldShowWarningItems:(BOOL)state
{
  [self didSelectLogWarningItems:state];
}

#pragma mark -
#pragma mark console view delegate

- (void) didChangeLogOutputLevel:(NSInteger)view
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(didChangeLogOutputLevel:)]) {
    [self.delegate didChangeLogOutputLevel:view];
  }
}

- (void) didSelectConsoleView:(NSInteger)view
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(didSelectConsoleView:)]) {
    [self.delegate didSelectConsoleView:view];
  }
}

- (void) didSelectLogInfoItems:(BOOL)state
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(didSelectLogInfoItems:)]) {
    [self.delegate didSelectLogInfoItems:state];
  }
}

- (void) didSelectLogWarningItems:(BOOL)state
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(didSelectLogWarningItems:)]) {
    [self.delegate didSelectLogWarningItems:state];
  }
}

- (void) didSelectLogErrorItems:(BOOL)state
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(didSelectLogErrorItems:)]) {
    [self.delegate didSelectLogErrorItems:state];
  }
}

- (NSInteger)logOutputLevel
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(logOutputLevel)]) {
    return [self.delegate logOutputLevel];
  }
  
  return TPConsoleDisplayAll;
}

- (NSInteger)consoleView
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(consoleView)]) {
    return [self.delegate consoleView];
  }
  
  return 0;
}

- (BOOL)showLogInfoItems
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(showLogInfoItems)]) {
    return [self.delegate showLogInfoItems];
  }
  
  return YES;
}

- (BOOL)showLogWarningItems
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(showLogWarningItems)]) {
    return [self.delegate showLogWarningItems];
  }
  
  return YES;
}

- (BOOL)showLogErrorItems
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(showLogErrorItems)]) {
    return [self.delegate showLogErrorItems];
  }
  
  return YES;
}




@end
