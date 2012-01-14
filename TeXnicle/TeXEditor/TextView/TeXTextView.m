//
//  TeXTextView.m
//  TeXEditor
//
//  Created by hewitson on 27/3/11.
//  Copyright 2011 bobsoft. All rights reserved.
//

#import "TeXTextView.h"
#import "RegexKitLite.h"
#import "LibraryController.h"
#import "NSArray+Color.h"
#import "NSMutableAttributedString+CodeFolding.h"
#import "NSAttributedString+CodeFolding.h"
#import "NSString+Comparisons.h"
#import "NSString+CharacterSize.h"

#import "MHEditorRuler.h"
#import "MHCodeFolder.h"
#import "TeXColoringEngine.h"
#import "TPPopupListWindowController.h"
#import "TPFoldedCodeSnippet.h"
#import "NSString+RelativePath.h"
#import "NSString+WordRanges.h"

#import "NSDictionary+TeXnicle.h"
#import "NSString+LaTeX.h"
#import "NSAttributedString+LineNumbers.h"
#import "KSPathUtilities.h"

#import "MHLineNumber.h"
#import "NSString+FileTypes.h"

#import "MHPlaceholderAttachment.h"
#import "MHFileReader.h"
#import "externs.h"

#define LargeTextWidth  1e7
#define LargeTextHeight 1e7

NSString * const TELineNumberClickedNotification = @"TELineNumberClickedNotification";

@implementation TeXTextView

@synthesize editorRuler;
@synthesize coloringEngine;
@synthesize highlightRange;
@synthesize lineHighlightColor;
@synthesize syntaxHighlightTags;
@synthesize highlightingTimer;
@synthesize shiftKeyOn;
@synthesize commandList;
@synthesize beginList;
@synthesize wordHighlightRanges;

- (void) dealloc
{
//  NSLog(@"TextView dealloc");
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  self.delegate = nil;
  [self stopObserving];
  self.editorRuler = nil;
  self.lineHighlightColor = nil;
  self.coloringEngine = nil;
  self.syntaxHighlightTags = nil;
  self.commandList = nil;
  self.beginList = nil;
	[newLineCharacterSet release];
	[whitespaceCharacterSet release];
  [super dealloc];
}

- (void) awakeFromNib
{
//  NSLog(@"TextView awakeFromNib");
  
	newLineCharacterSet = [[NSCharacterSet newlineCharacterSet] retain];
	whitespaceCharacterSet = [[NSCharacterSet whitespaceCharacterSet] retain];	
    
  [self defaultSetup];
  [self setUpRuler];
  [self setupLists];
  
  [self setSmartInsertDeleteEnabled:NO];
  [self setAutomaticTextReplacementEnabled:NO];
  [self setAutomaticSpellingCorrectionEnabled:NO];
  
  self.coloringEngine = [TeXColoringEngine coloringEngineWithTextView:self];
    
}


// Do the default setup for the text view.
- (void) defaultSetup
{
//  NSLog(@"TeX TextView default setup");
  self.lineHighlightColor = [[self backgroundColor] shadowWithLevel:0.1];
  
	[[self layoutManager] setAllowsNonContiguousLayout:YES];
//	[self setTextContainerInset:NSMakeSize(3, 3)];
  [self turnOffWrapping];
  [self observePreferences];
  
  // set font and color
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  
  // basic text
  NSFont *font = [NSUnarchiver unarchiveObjectWithData:[defaults valueForKey:TEDocumentFont]];
  NSColor *color = [[defaults valueForKey:TESyntaxTextColor] colorValue];
  [[self textStorage] setFont:font];
  [[self textStorage] setForegroundColor:color];
  [self setFont:font];
  [self setTextColor:color];
  [self setTypingAttributes:[NSDictionary currentTypingAttributes]];
  
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self
				 selector:@selector(handleSelectionChanged:)
						 name:NSTextViewDidChangeSelectionNotification
					 object:self];
  
  [self setPostsFrameChangedNotifications:YES];
  [[[self enclosingScrollView] contentView] setPostsBoundsChangedNotifications:YES];
  [nc addObserver:self
         selector:@selector(handleFrameChangeNotification:)
             name:NSViewBoundsDidChangeNotification 
           object:[[self enclosingScrollView] contentView]];
  
 
//  [nc addObserver:self
//         selector:@selector(colorVisibleText)
//             name:NSTextStorageDidProcessEditingNotification
//           object:[self textStorage]];
}


- (void) setUpRuler
{
  self.editorRuler = [MHEditorRuler editorRulerWithTextView:self];
  
  [[self layoutManager] ensureLayoutForTextContainer:[self textContainer]];
	
	NSScrollView *scrollView = [self enclosingScrollView];
	[scrollView setHasVerticalScroller:YES];
	[scrollView setAutohidesScrollers:YES];
	[scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
	[[scrollView contentView] setAutoresizesSubviews:YES];  
	[scrollView setVerticalRulerView:self.editorRuler];
	[scrollView setHasHorizontalRuler:NO];
	[scrollView setHasVerticalRuler:YES];
	[scrollView setRulersVisible:YES];  
}

- (void) setupLists
{
  // build the command list
	NSString *path = [[NSBundle mainBundle] pathForResource:@"Commands" ofType:@"plist"];
	NSDictionary *commmandDict = [NSMutableDictionary dictionaryWithContentsOfFile:path];
  path = [[NSBundle mainBundle] pathForResource:@"ContextCommands" ofType:@"plist"];
	NSDictionary *contextCommandDict = [NSMutableDictionary dictionaryWithContentsOfFile:path];
	self.commandList = [[[NSMutableArray alloc] init] autorelease];								
	[self.commandList addObjectsFromArray:[commmandDict valueForKey:@"Commands"]];
	[self.commandList addObjectsFromArray:[contextCommandDict valueForKey:@"Commands"]];
	
	// add all commands from the palette
  //	NSArray *pcommands = [[PaletteController sharedPaletteController] listOfCommands];	
  //	[commands addObjectsFromArray:pcommands];
	
	// remove \ from the front of commands
	NSString *c = [self.commandList componentsJoinedByString:@" "];
	[self.commandList removeAllObjects];
	[self.commandList addObjectsFromArray:[c componentsSeparatedByString:@" "]];
	
	// possible sections and completions for \begin
	self.beginList = [[[NSMutableArray alloc] init] autorelease];
	[self.beginList addObject:@"enumerate"];
	[self.beginList addObject:@"array"];
	[self.beginList addObject:@"matrix"];
	[self.beginList addObject:@"itemize"];
	[self.beginList addObject:@"eqnarray"];
	[self.beginList addObject:@"description"];
	[self.beginList addObject:@"quotation"];
	[self.beginList addObject:@"quote"];
	[self.beginList addObject:@"verbatim"];
	[self.beginList addObject:@"verse"];
	[self.beginList addObject:@"table"];
	[self.beginList addObject:@"tabular"];
	[self.beginList addObject:@"center"];
	[self.beginList addObject:@"figure"];
	[self.beginList addObject:@"table"];
}

-(void) turnOffWrapping
{
	NSTextContainer*	textContainer = [self textContainer];
	NSScrollView*		scrollView = [self enclosingScrollView];
	
	// Make sure we can see right edge of line:
	[scrollView setHasHorizontalScroller:YES];
	
	// Make text container so wide it won't wrap:
	[textContainer setContainerSize: NSMakeSize(LargeTextWidth, LargeTextHeight)];
	[textContainer setWidthTracksTextView:NO];
	[textContainer setHeightTracksTextView:NO];
	
	// Make sure text view is wide enough:	
	[self setMaxSize:NSMakeSize(LargeTextWidth, LargeTextHeight)];
	[self setHorizontallyResizable:YES];
	[self setVerticallyResizable:YES];	
  
  [self setWrapStyle];
}


#pragma mark -
#pragma mark Go to methods

- (IBAction) gotoLine:(id)sender
{
	[goToLineController showGoToSheet:[self window]];
}

-(void)	goToCharacter: (int)charNum
{
	[self goToRangeFrom: charNum toChar: charNum +1];
}


-(void) goToRangeFrom: (int)startCh toChar: (int)endCh
{
	NSRange		theRange = { 0, 0 };
	
	theRange.location = startCh -1;
	theRange.length = endCh -startCh;
	
	if( startCh == 0 || startCh > [[self string] length] )
		return;
	
	[self scrollRangeToVisible: theRange];
	[self setSelectedRange: theRange];
}

-(void)	goToLine: (int)targetLineNumber
{
  NSString *text = [self string];  
  NSInteger lineNumber = 0;
  NSInteger idx = 0;
  NSRange lineRange;
  NSInteger lineCount;
  NSAttributedString *attributedString = [self attributedString];
  BOOL foundLinenumber = NO;
  NSAttributedString *attLine;
  do
  {
    // get the range of the current line
    lineRange = [text lineRangeForRange:NSMakeRange(idx, 0)];    
    // Get an attributed version of this line
    attLine = [attributedString attributedSubstringFromRange:lineRange];    
    // Get a line count for this line of text.
    lineCount = [NSAttributedString lineCountForLine:attLine];
    lineNumber += lineCount;
    if (targetLineNumber == lineNumber) {
      foundLinenumber = YES;
      break;
    }
    // move on to the next line
		idx = NSMaxRange(lineRange);
  }
  while (idx < [text length]);
  
  // did we find something?
	if (foundLinenumber) {
    [self scrollRangeToVisible: lineRange];
    [self setSelectedRange:lineRange];  
  } else {
    // did the user ask for a line number greater than the document length?
    if (targetLineNumber < lineNumber) {
      // didn't find a line number, this shouldn't happen
      NSString *format = [NSString stringWithFormat:@"Line number %d not found in text"];
      [NSException raise:@"Line number not found" format:format, targetLineNumber];
    } else {
      // tell the user the line number is too high
      NSAlert *alert = [NSAlert alertWithMessageText:@"Document length exceeded." defaultButton:@"OK" 
                                     alternateButton:nil otherButton:nil informativeTextWithFormat:@"Requested line %d is greater than the number of lines in the document", targetLineNumber];
      [alert runModal];
    }
  }
}



#pragma mark -
#pragma mark Control

- (IBAction)commentSelection:(id)sender
{
	NSRange				selRange = [self selectedRange];
	NSMutableString*	str = [[self textStorage] mutableString];
  
	// Get the range to edit
	NSRange r = [str paragraphRangeForRange:selRange];	
	// Get a mutable string for this range
	NSInteger inserted = 0;
  NSMutableString *newString = [NSMutableString string];
	[newString appendString:[str substringWithRange:r]];
  [newString insertString:@"%" atIndex:0];
  inserted++;
  
	for (int ll=0; ll<[newString length]-1; ll++) {
		if ([newLineCharacterSet characterIsMember:[newString characterAtIndex:ll]]) {
      [newString insertString:@"%" atIndex:ll+1];
      inserted++;
		}
	}  
  
  if (inserted == 0)
    return;
  
	[self setSelectedRange:r];
	[self delete:self];
	[self insertText:newString];
	
	NSInteger len = selRange.length+inserted-1;
	
  if (len<0)
    len = 0;
  [self setSelectedRange:NSMakeRange(selRange.location+1,len)];
	
  // color visible text
  [self performSelector:@selector(colorVisibleText) withObject:nil afterDelay:0.2];
}

- (IBAction)uncommentSelection:(id)sender
{
	NSRange				selRange = [self selectedRange];
	NSMutableString*	str = [[self textStorage] mutableString];
  
	// Get the range to edit
	NSRange r = [str paragraphRangeForRange:selRange];	
	// Get a mutable string for this range
	NSMutableString *newString = [NSMutableString string];
	[newString appendString:[str substringWithRange:r]];
	int inserted = 0;
	if ([newString characterAtIndex:0]=='%') {
    
    [newString replaceCharactersInRange:NSMakeRange(0, 1) withString:@""];
    inserted--;
    
	}
  
	for (int ll=0; ll<[newString length]-1; ll++) {
		if ([newLineCharacterSet characterIsMember:[newString characterAtIndex:ll]]) {
			if ([newString characterAtIndex:ll+1] == '%') {
				[newString replaceCharactersInRange:NSMakeRange(ll+1, 1) withString:@""];
				inserted--;
			}
		}
	}
	
  if (inserted == 0)
    return;
  
	[self setSelectedRange:r];
	[self delete:self];
	[self insertText:newString];
	NSInteger len = selRange.length+inserted+1;
	
  if (len<0)
    len = 0;
  [self setSelectedRange:NSMakeRange(selRange.location-1,len)];
	
  // color visible text
  [self performSelector:@selector(colorVisibleText) withObject:nil afterDelay:0.2];  
}

- (IBAction) toggleCommentForSelection:(id)sender
{
	NSRange				selRange = [self selectedRange];
	NSMutableString*	str = [[self textStorage] mutableString];
  
	// Get the range to edit
	NSRange r = [str paragraphRangeForRange:selRange];	
	// Get a mutable string for this range
	NSMutableString *newString = [NSMutableString string];
	[newString appendString:[str substringWithRange:r]];
	int move = 0;
	if ([newString characterAtIndex:0]=='%') {
    
    // remove all comment chars
    while([newString characterAtIndex:0]=='%') {
      [newString replaceCharactersInRange:NSMakeRange(0, 1) withString:@""];
      move--;
    }
    
	} else {
		[newString insertString:@"%" atIndex:0];
		move++;
	}
  
	NSInteger inserted = 0;
	for (int ll=0; ll<[newString length]-1; ll++) {
		if ([newLineCharacterSet characterIsMember:[newString characterAtIndex:ll]]) {
			if ([newString characterAtIndex:ll+1] == '%') {
        while([newString characterAtIndex:ll+1]=='%') {
          [newString replaceCharactersInRange:NSMakeRange(ll+1, 1) withString:@""];
          inserted--;
        }
			} else {
				[newString insertString:@"%" atIndex:ll+1];
				inserted++;
			}
		}
	}
	
	[self setSelectedRange:r];
	[self delete:self];
	[self insertText:newString];
	NSInteger len = selRange.length+inserted;
	
  if (len<0)
    len = 0;
  [self setSelectedRange:NSMakeRange(selRange.location+move,len)];
	
  // color visible text
  [self performSelector:@selector(colorVisibleText) withObject:nil afterDelay:0.2];
	
	return;
}


- (IBAction) toggleControlCharacters:(id)sender
{
  [[self layoutManager] setShowsControlCharacters:![[self layoutManager] showsControlCharacters]];
}

- (IBAction) toggleInvisibleCharacters:(id)sender
{
  [[self layoutManager] setShowsInvisibleCharacters:![[self layoutManager] showsInvisibleCharacters]];
}



#pragma mark -
#pragma mark Syntax highlighting

- (NSArray*)bookmarksForLineRange:(NSRange)aRange
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(bookmarksForCurrentFileInLineRange:)]) {
    id<TeXTextViewDelegate> d = (id<TeXTextViewDelegate>)self.delegate;
    return [d bookmarksForCurrentFileInLineRange:aRange];
  }  
  return [NSArray array];
}


- (void) resetLineNumbers
{
  [self.editorRuler resetLineNumbers];
  [self setNeedsDisplay:YES];
}

- (void) colorWholeDocument
{
//  NSLog(@"Color whole doc: delegate %@", self.delegate);
  if (self.delegate != nil && [self.delegate respondsToSelector:@selector(shouldSyntaxHighlightDocument)]) {
    if (![self.delegate performSelector:@selector(shouldSyntaxHighlightDocument)]) {
      return;
    }
  }
//  NSLog(@"Coloring whole document");
  if (self.coloringEngine) {
    [self.coloringEngine colorTextView:self
                           textStorage:[self textStorage]
                         layoutManager:[self layoutManager]
                               inRange:NSMakeRange(0, [[self string] length])];
    [self setNeedsDisplay:YES];
  }
}

- (void) colorVisibleText
{
//  NSLog(@"Color visible text: delegate %@", self.delegate);
  if (self.delegate && [self.delegate respondsToSelector:@selector(shouldSyntaxHighlightDocument)]) {
    if (![self.delegate performSelector:@selector(shouldSyntaxHighlightDocument)]) {
      return;
    }
  }
  
  NSRange vr = [self getVisibleRange];
//  NSLog(@"Visible range %ld-%ld", vr.location, vr.location+vr.length);
  
  // adjust range to be greater than the visible range
  NSInteger loc = vr.location-vr.length/2;
  NSInteger strLen = [[self string] length];
  if (loc < 0) 
    loc = 0;
  NSInteger length = vr.length*2;
  if (loc+length >= strLen) {
    length = strLen - loc - 1;
  }
  if (length < 0) {
    length = 0;
  }
  
  // make sure we start and end at line ends
  NSRange lr = [[self string] lineRangeForRange:NSMakeRange(loc, 0)];
  loc = lr.location;
  lr = [[self string] lineRangeForRange:NSMakeRange(loc+length, 0)];
  NSRange r = NSMakeRange(loc, NSMaxRange(lr)-loc);
  
//  NSLog(@"Coloring range %ld-%ld", r.location, r.location+r.length);
  if (self.coloringEngine) {
    [self.coloringEngine colorTextView:self
                           textStorage:[self textStorage]
                         layoutManager:[self layoutManager]
                               inRange:r];
  }
  
}

#pragma mark -
#pragma mark Actions



- (void) handleFrameChangeNotification:(NSNotification*)aNote
{
  [self colorVisibleText];
  [self highlightMatchingWords];
}

- (void) updateEditorRuler
{
  [self.editorRuler resetLineNumbers];
  [self.editorRuler setNeedsDisplay];
  [self setNeedsDisplay:YES];
}




#pragma mark -
#pragma mark KVO 

- (void) stopObserving
{
	NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
  [defaults removeObserver:self forKeyPath:[NSString stringWithFormat:@"values.%@", TESyntaxTextColor]];
  [defaults removeObserver:self forKeyPath:[NSString stringWithFormat:@"values.%@", TEDocumentFont]];
  [defaults removeObserver:self forKeyPath:[NSString stringWithFormat:@"values.%@", TEDocumentBackgroundColor]];
  [defaults removeObserver:self forKeyPath:[NSString stringWithFormat:@"values.%@", TEShowCodeFolders]];
  [defaults removeObserver:self forKeyPath:[NSString stringWithFormat:@"values.%@", TEShowLineNumbers]];
  [defaults removeObserver:self forKeyPath:[NSString stringWithFormat:@"values.%@", TEHighlightCurrentLine]];
  [defaults removeObserver:self forKeyPath:[NSString stringWithFormat:@"values.%@", TEHighlightMatchingWords]];
  [defaults removeObserver:self forKeyPath:[NSString stringWithFormat:@"values.%@", TELineWrapStyle]];
  [defaults removeObserver:self forKeyPath:[NSString stringWithFormat:@"values.%@", TELineLength]];
}

- (void) observePreferences
{
	NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
  
  [defaults addObserver:self
             forKeyPath:[NSString stringWithFormat:@"values.%@", TEDocumentFont]
                options:NSKeyValueObservingOptionNew
                context:NULL];		

  [defaults addObserver:self
             forKeyPath:[NSString stringWithFormat:@"values.%@", TESyntaxTextColor]
                options:NSKeyValueObservingOptionNew
                context:NULL];		
  
  [defaults addObserver:self
             forKeyPath:[NSString stringWithFormat:@"values.%@", TEDocumentBackgroundColor]
                options:NSKeyValueObservingOptionNew
                context:NULL];		
  
  [defaults addObserver:self
             forKeyPath:[NSString stringWithFormat:@"values.%@", TEShowCodeFolders]
                options:NSKeyValueObservingOptionNew
                context:NULL];		
  
  [defaults addObserver:self
             forKeyPath:[NSString stringWithFormat:@"values.%@", TEShowLineNumbers]
                options:NSKeyValueObservingOptionNew
                context:NULL];		
  
  [defaults addObserver:self
             forKeyPath:[NSString stringWithFormat:@"values.%@", TEHighlightCurrentLine]
                options:NSKeyValueObservingOptionNew
                context:NULL];		
  
  [defaults addObserver:self
             forKeyPath:[NSString stringWithFormat:@"values.%@", TEHighlightMatchingWords]
                options:NSKeyValueObservingOptionNew
                context:NULL];		
  
  [defaults addObserver:self
             forKeyPath:[NSString stringWithFormat:@"values.%@", TELineWrapStyle]
                options:NSKeyValueObservingOptionNew
                context:NULL];	
	
  [defaults addObserver:self
             forKeyPath:[NSString stringWithFormat:@"values.%@", TELineLength]
                options:NSKeyValueObservingOptionNew
                context:NULL];		
}


- (void)observeValueForKeyPath:(NSString *)keyPath
											ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
//  NSLog(@"Changed in %@", keyPath);
	if ([keyPath hasPrefix:[NSString stringWithFormat:@"values.%@", TEDocumentBackgroundColor]]) {	
    NSColor *c = [[[NSUserDefaults standardUserDefaults] valueForKey:TEDocumentBackgroundColor] colorValue];
    [self setBackgroundColor:c];
	} else if ([keyPath isEqual:[NSString stringWithFormat:@"values.%@", TEShowCodeFolders]]) {
    [self performSelector:@selector(updateEditorRuler) withObject:nil afterDelay:0];
    [self.editorRuler recalculateThickness];
	} else if ([keyPath isEqual:[NSString stringWithFormat:@"values.%@", TEShowLineNumbers]]) {
    [self performSelector:@selector(updateEditorRuler) withObject:nil afterDelay:0];
    [self.editorRuler recalculateThickness];
	} else if ([keyPath isEqual:[NSString stringWithFormat:@"values.%@", TEHighlightMatchingWords]]) {
    NSRange vr = [self getVisibleRange];
    [[self layoutManager] removeTemporaryAttribute:NSBackgroundColorAttributeName forCharacterRange:vr];
    [self highlightMatchingWords];
	} else if ([keyPath isEqual:[NSString stringWithFormat:@"values.%@", TEHighlightCurrentLine]]) {
		[self setNeedsDisplayInRect:[self bounds] avoidAdditionalLayout:YES];
	} else if ([keyPath isEqual:[NSString stringWithFormat:@"values.%@", TELineWrapStyle]]) {
    [self setWrapStyle];
	} else if ([keyPath isEqual:[NSString stringWithFormat:@"values.%@", TELineLength]]) {
    [self setWrapStyle];
	} else if ([keyPath isEqual:[NSString stringWithFormat:@"values.%@", TEDocumentFont]]) {
    [self applyFontAndColor];
	} else if ([keyPath isEqual:[NSString stringWithFormat:@"values.%@", TESyntaxTextColor]]) {
    [self applyFontAndColor];
	}
}

- (void) setTypingColor:(NSColor*)aColor
{
  NSDictionary *catts = [NSDictionary currentTypingAttributes];
  NSMutableDictionary *atts = [[catts mutableCopy] autorelease];
  [atts setValue:aColor forKey:NSForegroundColorAttributeName];
  [self setTypingAttributes:atts];
}

- (void) applyFontAndColor
{
  NSDictionary *atts = [NSDictionary currentTypingAttributes];
  NSFont *newFont = [atts valueForKey:NSFontAttributeName];
  NSColor *newColor = [atts valueForKey:NSForegroundColorAttributeName];
  if (![newFont isEqualTo:[self font]]) {
    [self setFont:[atts valueForKey:NSFontAttributeName]];
  }
  if (![newColor isEqualTo:[self textColor]]) {
    [self setTextColor:[atts valueForKey:NSForegroundColorAttributeName]];
  }
  
  NSDictionary *currentAtts = [self typingAttributes];
  if (![currentAtts isEqualToDictionary:atts]) {
//    NSLog(@"setting typing atts");
    [self setTypingAttributes:atts];
  } else {
//    NSLog(@"Skipping setting atts");
  }
}

- (void) setWrapStyle
{
  int wrapStyle = [[[NSUserDefaults standardUserDefaults] valueForKey:TELineWrapStyle] intValue];
  int wrapAt = [[[NSUserDefaults standardUserDefaults] valueForKey:TELineLength] intValue];
  NSTextContainer *textContainer = [self textContainer];
  if (wrapStyle == TPSoftWrap) {
    CGFloat scale = [NSString averageCharacterWidthForCurrentFont];
    [textContainer setContainerSize:NSMakeSize(scale*wrapAt, LargeTextHeight)];
  }	else if (wrapStyle == TPNoWrap) {
    [textContainer setContainerSize:NSMakeSize(LargeTextWidth, LargeTextHeight)];
  } else {
    // set large size - hard wrap is handled in the wrapLine
    [textContainer setContainerSize:NSMakeSize(LargeTextWidth, LargeTextHeight)];
  }
  [self setNeedsDisplay:YES];
}

#pragma mark -
#pragma mark Text Storage Observing

- (void) processEditing:(NSNotification*)aNote
{
	[self setNeedsDisplayInRect:[self bounds] avoidAdditionalLayout:NO];
}

- (void) stopObservingTextStorage
{
	if ([self textStorage]) {
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		[nc removeObserver:self 
									name:NSTextStorageDidProcessEditingNotification
								object:[self textStorage]];
	}
}


- (void) observeTextStorage
{
	if ([self textStorage]) {
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		
		// Register for "text changed" notifications of our text storage:
		[nc addObserver:self selector:@selector(processEditing:)
							 name: NSTextStorageDidProcessEditingNotification
						 object:[self textStorage]];	
	}
	
}

#pragma mark -
#pragma mark Completion and spelling



- (NSArray*)userDefaultCommands
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSArray *commandDicts = [defaults valueForKey:TEUserCommands];
  NSMutableArray *commands = [NSMutableArray array];
  for (NSDictionary *dict in commandDicts) {
    [commands addObject:[dict valueForKey:@"Name"]];
  }
  return commands;
}

- (void) completeFromList:(NSArray*)aList
{
//  NSLog(@"Completing from list %@", aList);
	if ([aList count]==0) 
		return;
	
	NSPoint point = [self listPointForCurrentWord];
	//			NSLog(@"Point for word:%@", NSStringFromPoint(point));
	NSPoint wp = [self convertPoint:point toView:nil];
	[self clearSpellingList];
	popupList = [[TPPopupListWindowController alloc] initWithEntries:aList
																													 atPoint:wp
																										inParentWindow:[self window]
																															mode:TPPopupListReplace
																														 title:@"Replace..."];
	[popupList setDelegate:self];
	[popupList showPopup];	
}

- (void) insertFromList:(NSArray*)aList
{
	if ([aList count]==0) 
		return;
	
	NSPoint point = [self listPointForCurrentWord];
	//			NSLog(@"Point for word:%@", NSStringFromPoint(point));
	NSPoint wp = [self convertPoint:point toView:nil];
	[self clearSpellingList];
	popupList = [[TPPopupListWindowController alloc] initWithEntries:aList
																													 atPoint:wp
																										inParentWindow:[self window]
																															mode:TPPopupListInsert
																														 title:@"Insert..."];
	[popupList setDelegate:self];
	[popupList showPopup];	
}

- (IBAction) showSpellingList:(id)sender
{	
	NSString *word = [self currentWord];
  //	NSLog(@"Checking spelling for '%@'", word);
	if (word) {
		NSSpellChecker *sc = [NSSpellChecker sharedSpellChecker];
		NSArray *guesses = [sc guessesForWord:word];
		if ([guesses count]>0) {
      //			NSLog(@"Guesses: %@", guesses);
			
			NSPoint point = [self listPointForCurrentWord];
      //			NSLog(@"Point for word:%@", NSStringFromPoint(point));
			NSPoint wp = [self convertPoint:point toView:nil];
			[self clearSpellingList];
			popupList = [[TPPopupListWindowController alloc] initWithEntries:guesses
																															 atPoint:wp
																												inParentWindow:[self window]
																																	mode:TPPopupListSpell
																																 title:@"Correct..."];
			[popupList setDelegate:self];
			[popupList showPopup];
		}
	}
}

- (void) clearSpellingList
{
//  NSLog(@"Clearing old spelling list %@", popupList);
	if (popupList) {
    [popupList dismiss];
		[popupList release];
		popupList = nil;
    //		NSLog(@"... done");
	}
}

- (void) insertWordAtCurrentLocation:(NSString*)aWord
{
	NSString *replacement = [NSString stringWithString:aWord];
	NSRange curr = [self selectedRange];
	NSRange rr = NSMakeRange(curr.location, 0);
	[self shouldChangeTextInRange:rr replacementString:replacement];
	[self replaceCharactersInRange:rr withString:replacement];
	[self clearSpellingList];
}

- (void) replaceWordUpToCurrentLocationWith:(NSString*)aWord
{
	NSString *replacement = [NSString stringWithString:aWord];
  //	NSLog(@"Replacing current word with %@", replacement);
	[self selectUpToCurrentLocation];
	NSRange sel = [self selectedRange];
	[self shouldChangeTextInRange:sel replacementString:replacement];
	[self replaceCharactersInRange:sel withString:replacement];
	[self clearSpellingList];
}

- (void) replaceWordAtCurrentLocationWith:(NSString*)aWord
{
	NSString *replacement = [NSString stringWithString:aWord];
	//	NSLog(@"Replacing current word with %@", replacement);
  //	[self selectWord:self];
	NSRange sel = [self rangeForCurrentWord];
	[self shouldChangeTextInRange:sel replacementString:replacement];
	[self replaceCharactersInRange:sel withString:replacement];
	[self clearSpellingList];
}


#pragma mark -
#pragma mark Folding

- (IBAction) unfoldSelection:(id)sender
{
	// get the line
	NSRange sel = [self selectedRange];
	NSAttributedString *attStr = [self attributedString];
	NSRange lineRange = [[self string] lineRangeForRange:NSMakeRange(sel.location, 0)];
	NSAttributedString *line = [attStr attributedSubstringFromRange:lineRange];
	
	int idx = 0;
	NSRange effRange;
	while (idx < [line length]) {
		
		NSTextAttachment *att = [line attribute:NSAttachmentAttributeName
																		atIndex:idx
														 effectiveRange:&effRange];
		
		if (att && [att respondsToSelector:@selector(object)]) {			
			NSData *data = [[att fileWrapper] regularFileContents];
			NSString *code = [[NSString alloc] initWithData:data encoding:[MHFileReader defaultEncoding]];
			// delete the line up to and including the attachment
			[[self textStorage] replaceCharactersInRange:NSMakeRange(lineRange.location, idx+2) 
																				withString:[code stringByAppendingString:@"\n"]];
			[code release];
			
		}
		
		idx++;
	}
	
}

- (IBAction) collapseAll:(id)sender
{
//  NSLog(@"Collapse all");
  [self.editorRuler collapseAll];
}

- (IBAction) expandAll:(id)sender
{
//  NSLog(@"Expand all");
	[self unfoldAllInRange:NSMakeRange(0, [[self string] length]) max:100000];
}

- (void) unfoldAllInRange:(NSRange)aRange max:(NSInteger)max
{
	NSAttributedString *text = [[self textStorage] attributedSubstringFromRange:aRange];
	NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithAttributedString:text];
  
	[string unfoldAllInRange:aRange max:max];
	
	[[self textStorage] beginEditing];
	[[self textStorage] deleteCharactersInRange:aRange];
	[[self textStorage] insertAttributedString:string atIndex:aRange.location];
	[[self textStorage] endEditing];
	[string release];
  
  [self performSelector:@selector(colorVisibleText) withObject:nil afterDelay:0.2];
}

- (void) unfoldTextWithFolder:(MHCodeFolder*)aFolder
{	
	NSRange lineRange = [[self string] lineRangeForRange:NSMakeRange(aFolder.startIndex, 0)];
	[self unfoldAllInRange:lineRange max:10000];
}

- (void) foldTextWithFolder:(MHCodeFolder*)aFolder
{	
	NSRange foldRange = NSMakeRange(aFolder.startIndex, aFolder.endIndex-aFolder.startIndex);
//  NSLog(@"Folding range %@", NSStringFromRange(foldRange));
	NSAttributedString *fold = [[self textStorage] attributedSubstringFromRange:foldRange];
  
	// make an attachement object
	TPFoldedCodeSnippet *snippet = [[TPFoldedCodeSnippet alloc] initWithCode:fold];
  snippet.object = aFolder;
	
	// make an attachment	
	NSAttributedString *attachment = [NSAttributedString attributedStringWithAttachment:snippet];
	NSMutableAttributedString *aaa = [[NSMutableAttributedString alloc] initWithAttributedString:attachment];
	
	[aaa addAttribute:NSCursorAttributeName 
              value:[NSCursor pointingHandCursor] 
              range:NSMakeRange(0, [aaa length])];
  
	[[self textStorage] deleteCharactersInRange:foldRange];
	[[self textStorage] insertAttributedString:aaa atIndex:foldRange.location];
	
	[aaa release];
	[snippet release];
  
  // update editor ruler
	[self.editorRuler resetLineNumbers];
  [self.editorRuler setNeedsDisplay:YES];
  [self performSelector:@selector(colorVisibleText) withObject:nil afterDelay:0.2];
}



- (void) unfoldAttachment:(NSTextAttachment*)snippet atIndex:(NSNumber*)index
{	
	// find the location of this attachment in the text	
	NSData *data = [[snippet fileWrapper] regularFileContents];
	NSAttributedString *code = [[NSAttributedString alloc] initWithRTFD:data documentAttributes:nil];
	NSRange attRange = NSMakeRange([index unsignedLongValue], 1);
	[[self textStorage] removeAttribute:NSAttachmentAttributeName range:attRange];
	[[self textStorage] replaceCharactersInRange:attRange withAttributedString:code];
	[code release];
  
  // update editor ruler
	[self.editorRuler resetLineNumbers];
  [self.editorRuler setNeedsDisplay:YES];
  [self performSelector:@selector(colorVisibleText) withObject:nil afterDelay:0.2];
}

#pragma mark -
#pragma mark TeXTextView delegate


-(NSString*)codeForCommand:(NSString *)command
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(codeForCommand:)]) {
    if (command && [command length]>0) {
      if ([command characterAtIndex:0] == '#') {
        command = [command substringFromIndex:1];
      }
      NSString *code = [self.delegate performSelector:@selector(codeForCommand:) withObject:command];
      return code;
    }
  }
  return nil;
}

-(NSArray*)commandsBeginningWithPrefix:(NSString*)prefix;
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(commandsBeginningWithPrefix:)]) {
    return [self.delegate performSelector:@selector(commandsBeginningWithPrefix:) withObject:prefix];
  }
  return nil;
}


#pragma mark -
#pragma mark Selection

- (void) jumpToLine:(NSInteger)aLinenumber inFile:(FileEntity*)aFile select:(BOOL)selectLine
{
  NSMutableAttributedString *aStr = [[[[aFile document] textStorage] mutableCopy] autorelease];
  NSArray *lineNumbers = [aStr lineNumbersForTextRange:NSMakeRange(0, [aStr length])];
  MHLineNumber *matchingLine = nil;
  for (MHLineNumber *line in lineNumbers) {
    if (line.number == aLinenumber) {
      matchingLine = line;
      break;
    }
  }
  if (matchingLine) {
    if (selectLine) {
      [self setSelectedRange:matchingLine.range];
      [self scrollRangeToVisible:matchingLine.range];
    } else {
      NSRange r = NSMakeRange(matchingLine.range.location, 0);
      [self setSelectedRange:r];
      [self scrollRangeToVisible:r];
    }
  }
}

- (void) replaceRange:(NSRange)aRange withText:(NSString*)replacement scrollToVisible:(BOOL)scroll animate:(BOOL)animate
{
  [self setSelectedRange:aRange];
  [self replaceCharactersInRange:aRange withString:replacement];
  if (scroll) {    
    [self scrollRangeToVisible:aRange];
  }
  if (animate) {
    [self showFindIndicatorForRange:aRange];
  }
}

- (void) selectRange:(NSRange)aRange scrollToVisible:(BOOL)scroll animate:(BOOL)animate
{
  if (NSMaxRange(aRange) < [[self string] length]) {
    [self setSelectedRange:aRange];
    if (scroll) {    
      [self scrollRangeToVisible:aRange];
    }
    if (animate) {
      [self showFindIndicatorForRange:aRange];
    }
  }
}


- (NSPoint) listPointForCurrentWord
{
	NSRange curr = [self selectedRange];
	[self selectWord:self];
	NSRange sel = [self selectedRange];
	[self setSelectedRange:curr];
	NSLayoutManager *lm = [self layoutManager];
	NSRange wr = NSMakeRange(sel.location+sel.length-1,1);
	NSRange gr = [lm glyphRangeForCharacterRange:wr actualCharacterRange:NULL];
  //	NSLog(@"Glyph range: %@", NSStringFromRange(gr));
	NSRect bounds = [lm boundingRectForGlyphRange:gr inTextContainer:[self textContainer]];
  //	NSLog(@"bounds: %@", NSStringFromRect(bounds));
	return bounds.origin;
}

- (NSString*) currentWord
{
	NSString *string = [self string];
	NSRange sel = [self rangeForCurrentWord];
  //	NSLog(@"Word range: %@", NSStringFromRange(sel));
	NSString *text = [string substringWithRange:sel];	
	return text;
}

- (NSRange) rangeForCurrentCommand
{
  NSString *string = [self string];
  NSRange sel = [self selectedRange];
  NSInteger end = sel.location;
  if (end < 0 || end >= [string length]) {
    return NSMakeRange(NSNotFound, 0);
  }
  NSInteger idx = end-1;
  NSInteger start = -1;  
  while (idx >= 0) {
    
    unichar c = [string characterAtIndex:idx];
    if ([newLineCharacterSet characterIsMember:c] || [whitespaceCharacterSet characterIsMember:c]) {
      start = idx+1;
      break;
    }
    
    idx--;
  }
  
  if (start < 0 || start >= [string length]) {
    return NSMakeRange(NSNotFound, 0);
  }
  //  NSLog(@"Start %d, end %d", start, end);
  NSRange r = NSMakeRange(start, end-start);  
  return r;
}

- (NSString*)currentCommand
{
  NSString *string = [self string];
  NSRange r = [self rangeForCurrentCommand];
  if (r.location == NSNotFound || r.location >= [string length]) {
    return nil;
  }
  
//  NSLog(@"Range %@", NSStringFromRange(r));
  NSString *word = [string substringWithRange:r];
//  NSLog(@"Current word %@", word);
  if ([word length] == 0) {
    return nil;
  }
  if ([word characterAtIndex:0] == '#') {
    return word;
  }
  
  return nil;
}



- (NSRange) rangeForCurrentWord
{
	NSRange curr = [self selectedRange];
	
	// edge cases:
	// 1) we are at the beginning of the word in which case the selection sometimes doesn't work
	// 2) We are at the end of a word (indicated by the next character being newline or whitespace)
	NSInteger loc = curr.location;
	if (loc-1>=0) {
		NSString *str = [self string];
		if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[str characterAtIndex:loc-1]]) {
			[self setSelectedRange:NSMakeRange(loc, 1)];
		}
		if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[str characterAtIndex:loc]]) {
			[self setSelectedRange:NSMakeRange(loc-1, 1)];
		}
	}
	
	[self selectWord:self];
	NSRange sel = [self selectedRange];
	[self setSelectedRange:curr];	
	return sel;
}


- (NSInteger) lengthOfLineUpToLocation:(NSUInteger)location
{
	NSAttributedString *astr = [self attributedString];
	NSUInteger idx = [astr lineBreakBeforeIndex:location withinRange:NSMakeRange(0, location)];
	return location-idx;
}

- (NSRange) rangeForCurrentParagraph
{	
	NSRange selRange = [self selectedRange];
	NSString *str = [self string];
	if ([str isEqual:@""]) {
		return NSMakeRange(0, 0);
	}
	
	// go back until we find an empty line
	// - what is an empty line? Just newline and whitespace
	NSInteger start = selRange.location;
  //	NSLog(@"Starting from %@", NSStringFromRange(selRange));
	// if we are starting at the end of a line, we can move backwards
	if (start>0 && start < [str length] && [newLineCharacterSet characterIsMember:[str characterAtIndex:start]]) {
		start--;
	}
	
	// if we are starting from the end of the document
	if (start>0 && start == [str length])
		start--;
	
  //	NSLog(@"Starting search");
	while(start>=0 && start < [str length]) {		
		if ([newLineCharacterSet characterIsMember:[str characterAtIndex:start]]) {
      //      NSLog(@"Found new line at %d", start);
			// this means we are at the end of a line. 
			// Was the last line empty?
			NSRange lr = [str lineRangeForRange:NSMakeRange(start+1, 0)];
      //      NSLog(@"Line range: %@", NSStringFromRange(lr));
			NSString *lstr = [str substringWithRange:lr];
			
			// now remove all newlines and whitespace characters
			lstr = [lstr stringByTrimmingCharactersInSet:whitespaceCharacterSet];
			lstr = [lstr stringByTrimmingCharactersInSet:newLineCharacterSet];
			if ([lstr length]==0) {
				// then that line is empty
				start += lr.length+1;
				break;
			}
		}		
		start--;
	}
	if (start<0)
		start = 0;
	
	
	// go forward until we find an empty line
	NSInteger end = start;
	while(end < [str length]) {
		
		if ([newLineCharacterSet characterIsMember:[str characterAtIndex:end]]) {
			
			// we are at the end of a line; was it an empty line?
			NSRange lr = [str lineRangeForRange:NSMakeRange(end, 0)];
			NSString *lstr = [str substringWithRange:lr];
			lstr = [lstr stringByTrimmingCharactersInSet:whitespaceCharacterSet];
			lstr = [lstr stringByTrimmingCharactersInSet:newLineCharacterSet];
			if ([lstr length]==0) {
				end--;
				break;
			}
		}		
		end++;
	}
	
	if (end >= [str length]) 
		end = [str length];
	
	if (end < start)
		end = start;
	
	return NSMakeRange(start, end-start);
	
}

- (NSInteger) locationOfLastWhitespaceLessThan:(NSInteger)lineWrapLength
{
	NSString *str = [[self textStorage] string];
	NSRange selRange = [self selectedRange];
	NSInteger loc = selRange.location;
	
	while (loc >= 0) {
		if ([self lengthOfLineUpToLocation:loc]<lineWrapLength &&
				[whitespaceCharacterSet characterIsMember:[str characterAtIndex:loc-1]]) {
      //			NSLog(@"Returning %d", loc-1);
			return loc-1;
		}
		if ([newLineCharacterSet characterIsMember:[str characterAtIndex:loc-1]]) {
      //			NSLog(@"Returning -1,1");
			return -1;
		}
		loc--;
	}
  //	NSLog(@"Returning -1,2");
	return -1;
}

- (NSString*) currentLineToCursor
{
	NSRange selRange = [self selectedRange];
	NSString*	str = [[self textStorage] string];
  //	NSLog(@"Checking string %@", str);
	NSInteger loc = selRange.location;
  
  //	NSLog(@"Staring scan at %d", loc-1);
	while (loc > 0) {
    //		NSLog(@"Checking character: '%c'", [str characterAtIndex:loc-1]);
		if ([newLineCharacterSet characterIsMember:[str characterAtIndex:loc-1]]) {
			break;
		}
		loc--;
	} 
	NSInteger len = selRange.location-loc;
  //	NSLog(@"loc %d, len %d", loc, len);
	return [str substringWithRange:NSMakeRange(loc, MAX(len,0))];
}

- (void) selectUpToCurrentLocation
{
	NSRange curr = [self selectedRange];
	NSInteger loc = curr.location-1;
	NSString *string = [self string];
	NSInteger start = -1;
	while (loc>=0) {
		unichar c = [string characterAtIndex:loc];
    //		NSLog(@"  checking '%c'", c);
		if ([whitespaceCharacterSet characterIsMember:c] || [newLineCharacterSet characterIsMember:c]) {
			start = loc+1;
			break;
		}
		
		// other possible word breaks include '~' '\,'
		if (c == '~') {
			start = loc+1;
			break;
		}
		
		if (loc > 1) {
			if (c == ',' && [string characterAtIndex:loc-1] == '\\') {
				start = loc+1;
				break;
			}
		}
		
		loc--;
	}
  //	NSLog(@"Word starts at %d", start);
	if (start >= 0) {
		NSRange wr = NSMakeRange(start, curr.location+curr.length-start);
		[self setSelectedRange:wr];
	}
}

- (NSRange) getVisibleRange
{
  NSScrollView *sv = [self enclosingScrollView];
  if(!sv) return NSMakeRange(0,0);
  NSLayoutManager *lm = [self layoutManager];
  NSRect visRect = [self visibleRect];
  
  NSPoint tco = [self textContainerOrigin];
  visRect.origin.x -= tco.x;
  visRect.origin.y -= tco.y;
  
  NSRange glyphRange = [lm glyphRangeForBoundingRect:visRect                        
                                     inTextContainer:[self textContainer]];
  NSRange charRange = [lm characterRangeForGlyphRange:glyphRange                       
                                     actualGlyphRange:NULL];
  return charRange;
}

// Returns a rectangle suitable for highlighting a background rectangle for the given text range.
- (NSRect) highlightRectForRange:(NSRange)aRange
{
//  NSLog(@"Getting highlight range for range %@", NSStringFromRange(aRange));
  NSRange r = aRange;
  NSRange startLineRange = [[self string] lineRangeForRange:NSMakeRange(r.location, 0)];
//  NSLog(@"Start line range %@", NSStringFromRange(startLineRange));
  NSInteger er = NSMaxRange(r)-1;
  NSString *text = [self string];
  
  if (er >= [text length]) {
//    NSLog(@"Out of range");
    return NSZeroRect;
  }
  if (er < r.location) {
    er = r.location;
  }
  
  NSRange endLineRange = [[self string] lineRangeForRange:NSMakeRange(er, 0)];
//  NSLog(@"End line range %@", NSStringFromRange(endLineRange));
  
  NSRange gr = [[self layoutManager] glyphRangeForCharacterRange:NSMakeRange(startLineRange.location, NSMaxRange(endLineRange)-startLineRange.location-1)
                                            actualCharacterRange:NULL];
  NSRect br = [[self layoutManager] boundingRectForGlyphRange:gr inTextContainer:[self textContainer]];
  
  NSRect b = [self bounds];
  CGFloat h = br.size.height;
  CGFloat w = b.size.width;
  CGFloat y = br.origin.y;
  
  NSPoint containerOrigin = [self textContainerOrigin];
  
  NSRect aRect = NSMakeRect(0, y, w, h);
//  NSLog(@"Highlight rect: %@", NSStringFromRect(aRect));
  // Convert from view coordinates to container coordinates
  aRect = NSOffsetRect(aRect, containerOrigin.x, containerOrigin.y);
  return aRect;
}


- (void) handleSelectionChanged:(NSNotification*)aNote
{
  
  [self setNeedsDisplay:YES];
  [self updateEditorRuler];
  NSRange r = [self selectedRange];
  [[NSNotificationCenter defaultCenter] postNotificationName:TECursorPositionDidChangeNotification
                                                      object:self
                                                    userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInteger:r.location] forKey:@"index"]];
  
  [self colorVisibleText];
  [self setTypingAttributes:[NSDictionary currentTypingAttributes]];

  [self highlightMatchingWords];
}

- (void) highlightMatchingWords
{  
//  if (self.wordHighlightRanges == nil) {
//    self.wordHighlightRanges = [NSMutableArray array];
//  }
  
  NSRange r = [self selectedRange];
  NSRange vr = [self getVisibleRange];
  //  NSLog(@"Visible range %@", NSStringFromRange(vr));
  
  
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if ([[defaults valueForKey:TEHighlightMatchingWords] boolValue]) {
    [[self layoutManager] removeTemporaryAttribute:NSBackgroundColorAttributeName forCharacterRange:vr];
    
    // remove existing word highlights
//    for (NSString *rangeString in self.wordHighlightRanges) {
//      NSRange r = NSRangeFromString(rangeString);
//      [[self layoutManager] removeTemporaryAttribute:NSBackgroundColorAttributeName forCharacterRange:r];
//    }
//    [self.wordHighlightRanges removeAllObjects];
    
    NSString *string = [self string];
    if (r.length > 0 && NSMaxRange(r)<[string length]) {
      NSString *word = [[[self string] substringWithRange:r] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
      word = [word stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
      if (word && [word length]>1) {
        NSString *textToSearch = [[self string] substringWithRange:vr];
        NSArray *matches = [textToSearch rangesOfString:word];
        
        NSColor *highlightColor = [[defaults valueForKey:TEHighlightMatchingWordsColor] colorValue];
        for (NSValue *match in matches) {
          NSRange r = [match rangeValue];
          r.location += vr.location;
          [[self layoutManager] addTemporaryAttribute:NSBackgroundColorAttributeName value:highlightColor forCharacterRange:r];
//          [self.wordHighlightRanges addObject:NSStringFromRange(r)];
//          NSLog(@"+ Added range %@", NSStringFromRange(r));
        }
      }      
    }
  }}

- (void) clearHighlight
{
  self.highlightRange = nil;
  [self setNeedsDisplay:YES];
}

#pragma mark -
#pragma mark NSTextView overrides

- (void) paste:(id)sender
{
  // check pboard type
  NSPasteboard *pboard = [NSPasteboard generalPasteboard];
  
  // check for an image type
  NSString *type = [pboard availableTypeFromArray:[NSImage imageTypes]];
  if (type) {
    [self pasteAsImage];
  } else {
    [self pasteAsPlainText:sender];
  }
  
  [self performSelector:@selector(colorWholeDocument) withObject:nil afterDelay:0];
}

- (void) insertTab:(id)sender
{
  //	[super insertTab:[self stringForTab]];
	BOOL spaces = [[[NSUserDefaults standardUserDefaults] valueForKey:TEInsertSpacesForTabs] boolValue];
	if (spaces) {
		int NSpaces = [[[NSUserDefaults standardUserDefaults] valueForKey:TENumSpacesForTab] intValue];
		NSMutableString *str = [NSMutableString string];
		for (int i=0;i<NSpaces;i++) {
			[str appendString:@" "];
		}
		[self insertText:str];		
	} else {
		[super insertTab:sender];
	}
	
}

- (void) insertNewline:(id)sender
{	
	// read the last line
	NSRange selRange = [self selectedRange];
	
	if (selRange.location == 0) {
		// now put in the requested newline
		[super insertNewline:sender];
    [self performSelector:@selector(colorVisibleText) withObject:nil afterDelay:0.1];
		return;
	}
	
	// using lineRangeForRange includes the line terminators so we do this by hand
	NSString *str = [self string];
	NSUInteger lineStart;
	NSUInteger lineEnd;
	[str getLineStart:&lineStart end:NULL contentsEnd:&lineEnd forRange:selRange];		
	NSRange lineRange = NSMakeRange(lineStart, lineEnd-lineStart); 
	NSString *previousLine = [[str substringWithRange:lineRange] 
														stringByTrimmingCharactersInSet:whitespaceCharacterSet];
	previousLine = [previousLine stringByTrimmingCharactersInSet:newLineCharacterSet];
	
	// Now let's do some special actions....
	//---- If the previous line was a \begin, we append the \end
	if ([previousLine hasPrefix:@"\\begin{"]) {			
		
		// don't complete if the shift key is on, just add the tab
		if (self.shiftKeyOn) {
			[super insertNewline:sender];
			[self insertTab:sender];
      [self performSelector:@selector(colorVisibleText) withObject:nil afterDelay:0.1];
			return;
		}		
		
		// if the current cursor location is not at the end of the \begin{} statement, we do nothing special			
		if (selRange.location == lineRange.location+lineRange.length) {
			int start = 0;
			int end   = 0;
			for (int kk=0; kk<[previousLine length]; kk++) {
				if ([previousLine characterAtIndex:kk]=='{') {
					start = kk+1;
					kk++;
				}
				if ([previousLine characterAtIndex:kk]=='}') {
					end = kk-1;
					break;
				}
			}
			
			NSString *insert = nil;
			if (start < end) {
				NSString *tag = [previousLine substringWithRange:NSMakeRange(start, end-start+1)];
				insert = [NSString stringWithFormat:@"\n\\end{%@}", tag];
			}
			
			if (insert) {
				// now put in the requested newline
				[super insertNewline:sender];
				
				// add the new \end
				[self insertTab:self];
				
				// record this location
				selRange = [self selectedRange];
				
				// add the new \end
				[self insertText:insert];
				
				// wind back the location of the cursor					
				[self setSelectedRange:selRange];
				
        [self performSelector:@selector(colorVisibleText) withObject:nil afterDelay:0.1];
				return;
			} // end if insert
		} // if we are at the end of the \begin statement			
    [super insertNewline:sender];    
	} // end if \begin
	else if ([self currentCommand])
  {
    [self expandCurrentCommand];
  } else {
    [super insertNewline:sender];    
  }
  
	// update line numbers
	[self updateEditorRuler];
	
}

- (void)setSpellingState:(NSInteger)value range:(NSRange)charRange
{
  // don't spell check commands
  if (charRange.location > 0) {
    if ([[self string] characterAtIndex:charRange.location-1] == '\\') {
      return;
    }
  }
  
  [super setSpellingState:value range:charRange];
}

- (IBAction)complete:(id)sender
{
	NSString *string = [self string];
	NSRange curr = [self selectedRange];
	[self selectUpToCurrentLocation];
	NSRange selectedRange = [self selectedRange];
  //	NSRange wr = 	[self rangeForCurrentWord];
	[self setSelectedRange:curr];
	
  
	NSString *word = [string substringWithRange:selectedRange];
	
	
  //  NSLog(@"Completing... %@", word);
	
	// If we are completing one of the special cases (ref, cite, include, input, ...)
	// then we use a custom popup list to present the options
	
	id delegate = [self delegate];
  //	NSLog(@"Delegate: %@", delegate);
	if ([word isEqual:@"\\include{"] || [word isEqual:@"\\input{"]) {
		if ([delegate respondsToSelector:@selector(listOfTeXFilesPrependedWith:)]) {
			NSArray *list = [delegate performSelector:@selector(listOfTeXFilesPrependedWith:) withObject:@""];
			[self insertFromList:list];			
		}
	} else if ([word beginsWith:@"\\ref{"]) {
		if ([delegate respondsToSelector:@selector(listOfReferences)]) {
			NSArray *list = [delegate performSelector:@selector(listOfReferences)];
      //			NSLog(@"List: %@", list);
			[self insertFromList:list];			
		}
	} else if ([word beginsWith:@"\\cite{"]) {
    //		NSLog(@"Checking for selector listOfCitations...");
		if ([delegate respondsToSelector:@selector(listOfCitations)]) {
			NSArray *list = [delegate performSelector:@selector(listOfCitations)];
			[self insertFromList:list];			
		}
	} else if ([word isEqual:@"\\begin{"]) {
		NSArray *list = self.beginList;
		[self insertFromList:list];			
	} else if ([word hasPrefix:@"\\"]) {
    NSArray *list = [NSMutableArray arrayWithArray:self.commandList];
    
    // get list of user defaults commands
    list = [list arrayByAddingObjectsFromArray:[self userDefaultCommands]];
    
    if ([delegate respondsToSelector:@selector(listOfCommands)]) {
      list = [list arrayByAddingObjectsFromArray:[delegate listOfCommands]];
    }
    if ([word length]>1) {
      NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF beginswith[c] %@", word];
      list = [list filteredArrayUsingPredicate:predicate];			
    }
    if ([list count]>0) {
      [self completeFromList:list];			
    } else {
      NSArray *list = [[NSSpellChecker sharedSpellChecker] completionsForPartialWordRange:NSMakeRange(0, [word length]) 
                                                                                 inString:word
                                                                                 language:nil
                                                                   inSpellDocumentWithTag:0];
      [self completeFromList:list];
      // otherwise we just call super
      //			[super complete:sender];
    }
	} else if ([word hasPrefix:@"#"]) {
    
    NSArray *possibleCommands = [self commandsBeginningWithPrefix:[self currentCommand]];
    [self completeFromList:possibleCommands];
    
	} else {
		// otherwise we just call super
		NSArray *list = [[NSSpellChecker sharedSpellChecker] completionsForPartialWordRange:NSMakeRange(0, [word length]) 
																																							 inString:word
																																							 language:nil
																																 inSpellDocumentWithTag:0];
		[self completeFromList:list];
    //		[super complete:sender];
		
    
		
	}
}

- (void)keyDown:(NSEvent *)theEvent
{
	if ([theEvent keyCode] == 36) {		
		if ([theEvent modifierFlags] & NSShiftKeyMask) {
      self.shiftKeyOn = YES;
		} else {
      self.shiftKeyOn = NO;
		}		
	}
  
	[super keyDown:theEvent];
}

- (void) mouseDown:(NSEvent *)theEvent
{
  [self clearHighlight];
	[self clearSpellingList];
	[super mouseDown:theEvent];
}

- (void)viewWillDraw
{
  [self.editorRuler setNeedsDisplay:YES];
	[super viewWillDraw];
}

- (void) drawViewBackgroundInRect:(NSRect)rect
{
	[super drawViewBackgroundInRect:rect];
  
  // additional highlight range
	if (self.highlightRange) {    
    NSRect aRect = [self highlightRectForRange:NSRangeFromString(self.highlightRange)];		
		[[[self backgroundColor] shadowWithLevel:0.2] set];
		[NSBezierPath fillRect:aRect];
	} else {
    [[self backgroundColor] set];
    [NSBezierPath fillRect:[self bounds]];
  }
  
  
  // highlight current line
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if ([[defaults valueForKey:TEHighlightCurrentLine] boolValue]) {
    NSRange sel = [self selectedRange];
    NSString *str = [self string];
    if (sel.location <= [str length]) {
      NSRange lineRange = [str lineRangeForRange:NSMakeRange(sel.location,0)];
      NSRect lineRect = [self highlightRectForRange:lineRange];
      NSColor *highlightColor = [[defaults valueForKey:TEHighlightCurrentLineColor] colorValue];
      [highlightColor set];
      [NSBezierPath fillRect:lineRect];
    }
  }
  
  
  // line width
  int wrapStyle = [[[NSUserDefaults standardUserDefaults] valueForKey:TELineWrapStyle] intValue];
  if (wrapStyle == TPHardWrap || wrapStyle == TPSoftWrap) {
    int wrapAt = [[[NSUserDefaults standardUserDefaults] valueForKey:TELineLength] intValue];
    CGFloat scale = [NSString averageCharacterWidthForCurrentFont];
    NSRect vr = [self visibleRect];
    NSRect r = NSMakeRect(scale*wrapAt+1, vr.origin.y, vr.size.width, vr.size.height);
    [[[self backgroundColor] shadowWithLevel:0.05] set];
    [NSBezierPath fillRect:r];
  }
  
}


- (void)insertText:(id)aString
{	
  
  // check if the next character or preceeding character was a text attachment
	NSRange selRange = [self selectedRange];
	NSRange effRange;
	NSAttributedString *string = [self attributedString];
	if ([string length] == 0) {
		[super insertText:aString];
		return;
	}
  
	if (selRange.location < [string length]) {
		NSTextAttachment *att = [string attribute:NSAttachmentAttributeName
																			atIndex:selRange.location
															 effectiveRange:&effRange];
		if (att) {
      if ([att isKindOfClass:[TPFoldedCodeSnippet class]]) {
        NSRange lineRange = [[self string] lineRangeForRange:selRange];
        [self unfoldAllInRange:lineRange max:10000];
        return;
      }
      
      if ([att isKindOfClass:[MHPlaceholderAttachment class]]) {
        [super replaceCharactersInRange:selRange withString:aString];
        return;
      }
		}
	}
  
  // setup typing attributes
  //  NSInteger start = [self locationOfLastWhitespaceLessThan:selRange.location]+1;  
  //  NSRange wordRange = NSMakeRange(start, selRange.location-start);
  //  NSString *word = [[self string] substringWithRange:wordRange];
  NSRange pRange = [self rangeForCurrentParagraph];  
  NSRange lineRange = [[self string] lineRangeForRange:selRange];  
  NSString *paragraph = [[self string] substringWithRange:pRange];
  paragraph = [paragraph stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  NSString *line = [[self string] substringWithRange:lineRange];
  line = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  if ([line isCommentLineBeforeIndex:selRange.location-pRange.location commentChar:[self commentChar]]) {
    [self setTypingColor:self.coloringEngine.commentColor];
  } else if ([paragraph isInArgumentAtIndex:selRange.location-pRange.location]) {
    [self setTypingColor:self.coloringEngine.argumentsColor];
  } else if ([line isCommandBeforeIndex:selRange.location-pRange.location]) {
    [self setTypingColor:self.coloringEngine.commandColor];
  } else {
    [self applyFontAndColor];
  }
  
  if ([aString isEqual:@"{"]) {
    // get selected text
    if (selRange.length > 0) {
      NSString *selected = [[string string] substringWithRange:selRange];
      [super replaceCharactersInRange:selRange withString:[NSString stringWithFormat:@"{%@}", selected]];
    } else {
      [super insertText:@"{}"];
      [self moveLeft:self];
    }
	} else 	if ([aString isEqual:@"["]) {
		NSRange r = [self selectedRange];
		r.location-=2;
		r.length+=2;
		[super insertText:@"[]"];
		[self moveLeft:self];
	} else 	if ([aString isEqual:@"("]) {
		NSRange r = [self selectedRange];
		r.location-=2;
		r.length+=2;
		[super insertText:@"()"];
		[self moveLeft:self];
	} else	if ([aString isEqual:@"}"]) {
		// will this be an extra closing bracket?
		NSRange r = [self selectedRange];
		if ([[self string] characterAtIndex:r.location] == '}') {
			// move right
			[self moveRight:self];
			return;
		}	else {
			[super insertText:aString];
			return;
		}	
	} else	if ([aString isEqual:@")"]) {
		// will this be an extra closing bracket?
		NSRange r = [self selectedRange];
		if ([[self string] characterAtIndex:r.location] == ')') {
			// move right
			[self moveRight:self];
			return;
		}	else {
			[super insertText:aString];
			return;
		}	
	} else	if ([aString isEqual:@"\""] && [[self fileExtension] isEqualToString:@"tex"]) {
		// do smart replacements
		NSRange r = [self selectedRange];
    if (r.location>0) {
      NSInteger loc = r.location-1;
      if ([whitespaceCharacterSet characterIsMember:[[self string] characterAtIndex:loc]]) {
        [self insertText:@"``"];        
      } else {
        [super insertText:aString];
      }
    } else {
      [super insertText:aString];
    }
	} else	if ([aString isEqual:@"]"]) {
		// will this be an extra closing bracket?
		NSRange r = [self selectedRange];
		if ([[self string] characterAtIndex:r.location] == ']') {
			// move right
			[self moveRight:self];
			return;
		}	else {
			[super insertText:aString];
			return;
		}	
	} else {
    
		[super insertText:aString];
    
    NSString *command = [self currentCommand];
    if (command != nil && [command length] > 0) {
      NSString *code = [self codeForCommand:command];
      if (code && [code length]>0) {
        NSRange commandRange = [self rangeForCurrentCommand];
        [[self layoutManager] addTemporaryAttribute:NSBackgroundColorAttributeName value:[NSColor yellowColor] forCharacterRange:commandRange];
      }
    }
    
  }
  
	[self wrapLine];
}

#pragma mark -
#pragma mark Text processing

- (NSString*) stringForTab
{
	NSMutableString *str = [NSMutableString string];
	BOOL spaces = [[[NSUserDefaults standardUserDefaults] valueForKey:TEInsertSpacesForTabs] boolValue];
	if (spaces) {
		int NSpaces = [[[NSUserDefaults standardUserDefaults] valueForKey:TENumSpacesForTab] intValue];
		for (int i=0;i<NSpaces;i++) {
			[str appendString:@" "];
		}
	} else {
		[str appendString:@"\t"];
	}
	return str;
}

- (NSString*)fileExtension
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(fileExtension)]) {
    return [self.delegate performSelector:@selector(fileExtension)];
  }
  return @"";
}

- (NSString*)commentChar
{
  if ([[self fileExtension] isEqualToString:@"tex"]) {
    return @"%";
  } 
  return @"#";
}



- (void) didSelectPopupListItem
{
}

- (void) didDismissPopupList
{
}




- (void) expandCurrentCommand
{
  NSString *currentCommand = [self currentCommand];
  if (currentCommand) {
    NSString *code = [self codeForCommand:currentCommand];
    if (code) {
      NSRange commandRange = [self rangeForCurrentCommand];
      [[self undoManager] beginUndoGrouping];
      [self shouldChangeTextInRange:commandRange replacementString:code];
      [self replaceCharactersInRange:commandRange withString:code];
      [self replacePlaceholdersInString:code range:commandRange];      
      [self didChangeText];
      [[self undoManager] endUndoGrouping];
      [self performSelector:@selector(colorVisibleText) withObject:nil afterDelay:0];
    }
  }
}

- (void) replacePlaceholdersInString:(NSString*)code range:(NSRange)commandRange
{
  // Replace placeholders
  NSString *regexp = [LibraryController placeholderRegexp];
  NSArray *placeholders = [code componentsMatchedByRegex:regexp];
  NSRange firstPlaceholder = NSMakeRange(NSNotFound, 0);
  for (NSString *placeholder in placeholders) {
    placeholder = [placeholder stringByTrimmingCharactersInSet:whitespaceCharacterSet];
    NSRange r = [code rangeOfString:placeholder];
    if (firstPlaceholder.location == NSNotFound) {
      firstPlaceholder = NSMakeRange(commandRange.location+r.location, 1);
    }
    // make attachment
    MHPlaceholderAttachment *placeholderAttachment = [[[MHPlaceholderAttachment alloc] initWithName:[placeholder substringWithRange:NSMakeRange(1, [placeholder length]-2)]] autorelease];
    
    NSAttributedString *attachment = [NSAttributedString attributedStringWithAttachment:placeholderAttachment];
    NSRange placeholderRange = NSMakeRange(commandRange.location+r.location, r.length);
    [self shouldChangeTextInRange:placeholderRange replacementString:@" "];
    [[self textStorage] replaceCharactersInRange:placeholderRange withAttributedString:attachment];
    [self didChangeText];
    // replace placeholder with blank just to make the counting right
    code = [code stringByReplacingCharactersInRange:r withString:@" "];
  }      
  
  // select the first placeholder
  if (firstPlaceholder.location != NSNotFound) {
    [self setSelectedRange:firstPlaceholder];
  }
  
}

- (IBAction)jumpToPreviousPlaceholder:(id)sender
{
  NSRange selRange = [self selectedRange];
  NSRange vr = [self getVisibleRange];
  NSInteger idx = selRange.location;
  if (idx>0)
    idx--;
  
  while (idx > vr.location) {
    
    NSRange effRange;
    NSTextAttachment *att = [[self attributedString] attribute:NSAttachmentAttributeName
                                                       atIndex:idx
                                                effectiveRange:&effRange];
    
    if (att && [att isKindOfClass:[MHPlaceholderAttachment class]]) {			
      [self setSelectedRange:NSMakeRange(idx, 1)];
      return;
    }
    idx--;
    
    if (idx == vr.location) {
      idx = NSMaxRange(vr);
    }
  }
  
}

- (IBAction)jumpToNextPlaceholder:(id)sender
{
  NSRange selRange = [self selectedRange];
  NSRange vr = [self getVisibleRange];
  NSInteger idx = NSMaxRange(selRange);
  
  while (idx < NSMaxRange(vr)) {
    
    NSRange effRange;
    NSTextAttachment *att = [[self attributedString] attribute:NSAttachmentAttributeName
                                                       atIndex:idx
                                                effectiveRange:&effRange];
    
    if (att && [att isKindOfClass:[MHPlaceholderAttachment class]]) {			
      [self setSelectedRange:NSMakeRange(idx, 1)];
      return;
    }
    idx++;
    
    if (idx == NSMaxRange(vr)) {
      idx = vr.location;
    }
  }
  
}


- (void) moveRight:(id)sender
{	
	[super moveRight:sender];
	
	// if we moved over an opening or closing bracket, look for the other one and flash it
	[self performSelector:@selector(checkForMatchingBracketAfterMovingRight)
						 withObject:nil
						 afterDelay:0];
	
}


- (void) moveLeft:(id)sender
{
	[super moveLeft:sender];
	// if we moved over an opening or closing bracket, look for the other one and flash it
	[self performSelector:@selector(checkForMatchingBracketAfterMovingLeft)
						 withObject:nil
						 afterDelay:0];	
}

- (void) checkForMatchingBracketAfterMovingLeft
{
	NSString *str = [self string];
	NSRange crange = [self selectedRange];
	
	if (crange.location < [str length]-1) {
		[self checkForMatchingBracket:[str characterAtIndex:crange.location]
											 offsetFrom:crange.location
															 by:0];
	}
}

- (void) checkForMatchingBracketAfterMovingRight
{
	NSString *str = [self string];
	NSRange crange = [self selectedRange];
	if (crange.location>0) {
		[self checkForMatchingBracket:[str characterAtIndex:crange.location-1]
											 offsetFrom:crange.location
															 by:-1];
	}	
}

- (void) checkForMatchingBracket:(unichar)aChar offsetFrom:(NSInteger)index by:(NSInteger)offset
{
	NSInteger match = [self findMatchingBracketOfType:aChar atIndex:index+offset];
	if (match != NSNotFound) {
		[self showFindIndicatorForRange:NSMakeRange(match, 1)];
	}	
}

- (NSInteger)searchBackwardsForChar:(unichar)openBracket matching:(unichar)closeBracket startingAt:(NSInteger)loc
{
  //	NSLog(@"Searching backwards for %C", openBracket);
	NSString *str = [self string];
	NSInteger bcount = 1;
	while (loc >= 0) {			
		if ([str characterAtIndex:loc] == closeBracket) {
			bcount++;
		}			
		if ([str characterAtIndex:loc] == openBracket) {
			bcount--;
		}			
		if (bcount == 0){
			return loc;			
		}
		loc--;
	}		
	return NSNotFound;
}

- (NSInteger)searchForwardsForChar:(unichar)closeBracket matching:(unichar)openBracket startingAt:(NSInteger)loc
{
  //	NSLog(@"Searching forwards for %C", closeBracket);
	NSString *str = [self string];
	NSInteger bcount = 1;
	while (loc < [str length]) {			
		if ([str characterAtIndex:loc] == openBracket) {
			bcount++;
		}			
		if ([str characterAtIndex:loc] == closeBracket) {
			bcount--;
		}			
		if (bcount == 0){
			return loc;			
		}
		loc++;
	}		
	return NSNotFound;
}

- (NSInteger)findMatchingBracketOfType:(unichar)aChar atIndex:(NSInteger)index
{
  //	NSLog(@"Matching %C", aChar);	
	if (aChar == '}') {	
		// go backwards in the text
		return [self searchBackwardsForChar:'{' matching:aChar startingAt:index-1];
	}
	if (aChar == '{') {	
		// go forwards in the text
		return [self searchForwardsForChar:'}' matching:aChar startingAt:index+1];
	}
	if (aChar == ')') {	
		// go backwards in the text
		return [self searchBackwardsForChar:'(' matching:aChar startingAt:index-1];
	}
	if (aChar == '(') {	
		// go forwards in the text
		return [self searchForwardsForChar:')' matching:aChar startingAt:index+1];
	}
	if (aChar == '[') {	
		// go forwards in the text
		return [self searchForwardsForChar:']' matching:aChar startingAt:index+1];
	}
	if (aChar == ']') {	
		// go backwards in the text
		return [self searchBackwardsForChar:'[' matching:aChar startingAt:index-1];
	}
	
	return NSNotFound;
}


- (void) wrapLine
{
	int wrapStyle = [[[NSUserDefaults standardUserDefaults] valueForKey:TELineWrapStyle] intValue];
	if (wrapStyle != TPHardWrap) 
		return;
  
	int lineWrapLength = [[[NSUserDefaults standardUserDefaults] valueForKey:TELineLength] intValue];
	// check the length of this line and insert newline if required
	// - we only do this if we are at the end of a line	
	NSString *str = [[self textStorage] string];
	NSRange selRange = [self selectedRange];
  //	NSRect selRect = [self visibleRect];
	
  //	NSLog(@"Checking character '%c'", [str characterAtIndex:selRange.location]);
	
	// is the next character a newline character, or are we at the end of the string?
  //	NSLog(@"Checking location %d against length %d", selRange.location, [str length]);
	NSUInteger strLen = [str length];
	if (selRange.location == strLen || 
			(selRange.location<strLen && 
			 [newLineCharacterSet characterIsMember:[str characterAtIndex:selRange.location]]
			 )
			) 
	{
		
		// then we are at the end of a line and we can do wrapping
		NSString*	lstr = [self currentLineToCursor];
    //		NSLog(@"Line: %@", lstr);
		if ([lstr length] > lineWrapLength) {
			
			// Do a proper search for the last whitespace because
			// we could be at the end of a command, for example.
			// Also we should move back to find the start of the word that is before the
			// line wrap length
			
			// get location of the last whitespace
			NSInteger lastWhitespace = [self locationOfLastWhitespaceLessThan:lineWrapLength];
      //			NSLog(@"Last ws: %d", lastWhitespace);
			if (lastWhitespace>=0) {
        //				NSLog(@"Inserting new line");
				[self setSelectedRange:NSMakeRange(lastWhitespace, 1)];
        //				[self insertText:lineBreakStr];
				[self insertNewline:self];
        //				[super insertLineBreak:self];
        //				selRange.location++;
				[self setSelectedRange:selRange];
        //				[self scrollRectToVisible:selRect];
			} else {
				
        //				NSLog(@"Last whitespace is not >0; %d", lastWhitespace);
			}
		} else {
      //			NSLog(@"Line length: %d", [lstr length]);
      //						NSLog(@"String not longer than lineWrap length");
		}
	} else {
    //				NSLog(@"Next character '%c' is not a newline", [str characterAtIndex:selRange.location]);
	}
	
	
	
}


- (NSInteger)cursorPosition
{
  NSRange sel = [self selectedRange];
  return sel.location;
}

- (NSInteger)lineNumberForRange:(NSRange)aRange
{
//  NSLog(@"Calculating line number");
  NSArray *lines = [self.editorRuler lineNumbersForTextRange:[self getVisibleRange]];
  //  NSLog(@"Got lines %@", lines);
  for (MHLineNumber *line in lines) {
    if (aRange.location >= line.range.location && aRange.location < NSMaxRange(line.range)) {
      return [[line valueForKey:@"number"] integerValue];
    }
    if (line.range.length == 0 && aRange.location == line.range.location) {
      return [[line valueForKey:@"number"] integerValue];
    }
  }
  return NSNotFound;
}

- (NSInteger)lineNumber
{
//  NSLog(@"Getting line number for %@, from %@", self, self.editorRuler);
  NSRange sel = [self selectedRange];
  NSString *str = [self string];
  if (NSMaxRange(sel)>= [str length]) {
    return NSNotFound;
  }
  NSRange lineRange = [str lineRangeForRange:sel];
  if (lineRange.location != _lastLineRange.location) {
    _lastLineRange = lineRange;
    _lastLineNumber = [self lineNumberForRange:sel];
  }
  return _lastLineNumber;
}


#pragma mark -
#pragma mark Formatting text

- (void) insertStringBeforeAllLinesInSelection:(NSString*)aStr
{
	NSRange				selRange = [self selectedRange];
	NSMutableString*	str = [[self textStorage] mutableString];
	
	// Get the range to edit
	NSRange r = [str paragraphRangeForRange:selRange];
	
	// Get a mutable string for this range
	NSMutableString *newString = [NSMutableString string];
	[newString appendString:[str substringWithRange:r]];
	
	int inserted = 0;
	[newString insertString:aStr atIndex:0];
	NSInteger slen = [aStr length];
	inserted+=slen;
	
	for (int ll=0; ll<[newString length]-1; ll++) {
		if ([newLineCharacterSet characterIsMember:[newString characterAtIndex:ll]]) {
			[newString insertString:aStr atIndex:ll+1];
			inserted+=slen;
		}
	}
	
	[self setSelectedRange:r];
	[self delete:self];
	[self insertText:newString];
	[self setSelectedRange:NSMakeRange(selRange.location+slen, selRange.length)];
}

- (IBAction) reformatParagraph:(id)sender
{
  //	NSLog(@"Reformat paragraph");
	
	NSRange pRange = [self rangeForCurrentParagraph];
	
  [self reformatRange:pRange];
	return;
}

- (IBAction) reformatRange:(NSRange)pRange
{
  //	NSLog(@"Reformat paragraph");
	
	int lineWrapLength = [[[NSUserDefaults standardUserDefaults] valueForKey:TELineLength] intValue];
	NSRange currRange = [self selectedRange];
//	NSRange pRange = [self rangeForCurrentParagraph];
	
	[self setSelectedRange:pRange];	
	NSString *oldStr = [[self string] substringWithRange:pRange];
	NSString *newString = [oldStr stringByReplacingOccurrencesOfRegex:@"[\n\r]+" withString:@" "];
  //	NSString *newString = [NSString stringWithControlsFilteredForString:oldStr];
	
	// Now go through and put in \n when we are past the linelength
  //	NSString *lineBreakStr = [NSString stringWithFormat:@" %C", NSLineSeparatorCharacter];
	NSString *lineBreakStr = [NSString stringWithFormat:@"\n", NSLineSeparatorCharacter];
	int loc = 0;
  NSInteger count = 0;
	while (loc < [newString length]) {
		if (count >= lineWrapLength) {
			if ([whitespaceCharacterSet characterIsMember:[newString characterAtIndex:loc]]) {
        // rewind to previous whitespace if we are past the line length
        if (count > lineWrapLength) {
          loc--;
          while (loc >= 0 
                 && ![whitespaceCharacterSet characterIsMember:[newString characterAtIndex:loc]] 
                 && ![newLineCharacterSet characterIsMember:[newString characterAtIndex:loc]]) {            
            loc--;
          }
        }
        
				newString = [newString stringByReplacingCharactersInRange:NSMakeRange(loc, 1)
																											 withString:lineBreakStr];
        count = 0;
			}
		}
    count++;
		loc++;
	}
  
	newString = [newString stringByTrimmingCharactersInSet:whitespaceCharacterSet];
	[self breakUndoCoalescing];
	[self setSelectedRange:pRange];
  [self shouldChangeTextInRange:pRange replacementString:newString];
  [[self textStorage] beginEditing];
  [[self textStorage] replaceCharactersInRange:pRange withString:newString];
  [[self textStorage] endEditing];
	[self setSelectedRange:currRange];
  [self performSelector:@selector(colorVisibleText) withObject:nil afterDelay:0.1];
	return;
}


- (IBAction) indentSelection:(id)sender
{	
	[self insertStringBeforeAllLinesInSelection:[self stringForTab]];
}


- (IBAction) unindentSelection:(id)sender
{
	NSRange				selRange = [self selectedRange];
	NSMutableString*	str = [[self textStorage] mutableString];
	
	// Get the range to edit
	NSRange r = [str paragraphRangeForRange:selRange];
	
	// Get a mutable string for this range
	NSMutableString *newString = [NSMutableString string];
	[newString appendString:[str substringWithRange:r]];
	
	NSString *iStr = [self stringForTab];
	NSInteger slen = [iStr length];
	int removed = 0;
	NSRange cr = NSMakeRange(0, slen);
	if ([[newString substringWithRange:cr] isEqual:iStr]) {
		[newString replaceCharactersInRange:cr withString:@""];
		removed += slen;
	}
	
	for (int ll=0; ll<[newString length]-1; ll++) {
		if ([newLineCharacterSet characterIsMember:[newString characterAtIndex:ll]]) {
			if (ll+1+slen < [newString length]) {
				cr = NSMakeRange(ll+1, slen);
				if ([[newString substringWithRange:cr] isEqual:iStr]) {
					[newString replaceCharactersInRange:cr withString:@""];
					removed += slen;
				}
			}			
		}
	}
	
	[self setSelectedRange:r];
	[self delete:self];
	[self insertText:newString];
  NSInteger diff = selRange.location-removed;
  if (diff>=0) {
    [self setSelectedRange:NSMakeRange(diff, selRange.length)];
  }
}

#pragma mark -
#pragma mark Drag and Drop

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard* pboard = [sender draggingPasteboard];
    
  NSPoint draggingLocation = [sender draggingLocation];
  draggingLocation = [self convertPoint:draggingLocation fromView:nil];
  NSUInteger characterIndex = [self characterIndexOfPoint:draggingLocation];
  
//	NSDragOperation sourceDragMask= [sender draggingSourceOperationMask];
	if ( [[pboard types] containsObject:NSFilenamesPboardType] )
	{
		NSArray* files = [pboard propertyListForType:NSFilenamesPboardType];
    for (NSString *file in files) {
      
      if ([[file pathExtension] isImage]) {
        [self insertImageBlockForFile:file atLocation:characterIndex];        
        return YES;
      }
      
      if ([[[file pathExtension] valueForKey:@"isText"] boolValue]) {
        [self insertIncludeForFile:file atLocation:characterIndex];        
        return YES;
      }
      
    }
	}
	
	return [super performDragOperation:sender];
}

- (NSUInteger)characterIndexOfPoint:(NSPoint)aPoint
{
  NSUInteger glyphIndex;
  NSLayoutManager *layoutManager = [self layoutManager];
  CGFloat fraction;
  NSRange range;
  
  range = [layoutManager glyphRangeForTextContainer:[self textContainer]];
  glyphIndex = [layoutManager glyphIndexForPoint:aPoint
                                 inTextContainer:[self textContainer]
                  fractionOfDistanceThroughGlyph:&fraction];
  
  if( fraction > 0.5 ) glyphIndex++;
  
  if( glyphIndex == NSMaxRange(range) ) 
    return  [[self textStorage] length];
  else 
    return [layoutManager characterIndexForGlyphAtIndex:glyphIndex];
  
}


- (void)concludeDragOperation:(id < NSDraggingInfo >)sender
{
//  NSLog(@"Drag concluded %@", sender);
  
  // perform some post drag corrections
  NSRange selRange = [self selectedRange];
  NSString *str = [[self string] substringWithRange:selRange];
  
  // replace placeholders
  [self replacePlaceholdersInString:str range:selRange];
  
  // make sure the right font is used
  NSDictionary *atts = [NSDictionary currentTypingAttributes];
  [[self textStorage] addAttributes:atts range:selRange];  
  
  // grab keyboard
  [[self window] makeFirstResponder:self];
  
  // color
  [self performSelector:@selector(colorVisibleText) withObject:nil afterDelay:0.1];
}

- (void) insertIncludeForFile:(NSString*)aFile atLocation:(NSUInteger)location
{
  id project = [[self delegate] performSelector:@selector(project)];
  NSString *projectFolder = [project valueForKey:@"folder"];
//  NSLog(@"Relative path: %@", [aFile relativePathTo:projectFolder]);

  NSString *file = [aFile ks_pathRelativeToDirectory:projectFolder];
  
  NSString *str = [NSString stringWithFormat:@"\\input{%@}", file];
  NSRange sel = NSMakeRange(location-1, 0);
  [self setSelectedRange:sel];
  [self insertText:str];
  [self colorVisibleText];
  
  NSRange insertRange = NSMakeRange(sel.location, [str length]);
  [self setSelectedRange:insertRange];
  [[self layoutManager] ensureLayoutForCharacterRange:insertRange];
}


- (void) insertImageBlockForFile:(NSString*)aFile atLocation:(NSUInteger)location
{
  id project = [[self delegate] performSelector:@selector(project)];
  NSString *projectFolder = [project valueForKey:@"folder"];
  NSString *file = [projectFolder relativePathTo:aFile];
  
//  NSLog(@"File %@", aFile);
//  NSLog(@"Project %@", projectFolder);
//  NSLog(@"computed path %@", file);
  
  NSString *name = [[file lastPathComponent] stringByDeletingPathExtension];
  NSString *str = [NSString stringWithFormat:@"\\begin{figure}[htbp]\n\\centering\n\\includegraphics[width=1.0\\textwidth]{%@}\n\\caption{My Nice Figure.}\n\\label{fig:%@}\n\\end{figure}\n", file, name];
  NSRange sel = NSMakeRange(location-1, 0);
  [self setSelectedRange:sel];
  [self insertText:str];
  [self colorVisibleText];
  
  NSRange insertRange = NSMakeRange(sel.location, [str length]);
  [self setSelectedRange:insertRange];
  [[self layoutManager] ensureLayoutForCharacterRange:insertRange];
}


- (void)pasteAsImage
{
  [NSApp sendAction:@selector(pasteAsImage:) to:nil from:self];  
}

- (IBAction) pasteTable:(id)sender
{
  NSMutableString *stringToPaste = [NSMutableString string];;
  NSPasteboard *pboard = [NSPasteboard generalPasteboard];
  if ( [[pboard types] containsObject:NSStringPboardType] ) {
    NSString *rawstring = [pboard stringForType:NSStringPboardType];
    NSArray *rows = [rawstring componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    
    // check max columns
    NSInteger columnCount = 0;
    for (NSString *r in rows){
      NSArray *cols = [r componentsSeparatedByString:@"\t"];
      if ([cols count] > columnCount) {
        columnCount = [cols count];
      }
    }
    
    // prepare table
    [stringToPaste appendFormat:@"\\begin{table}[htdp]\n"];
    [stringToPaste appendFormat:@"\\begin{center}\n"];
    [stringToPaste appendFormat:@"\\begin{tabular}{|"];
    for (int ii=0; ii<columnCount; ii++) {
      [stringToPaste appendFormat:@"c|"];
    }
    [stringToPaste appendFormat:@"} \\hline\n"];
    
    for (NSString *r in rows) {
      NSArray *cols = [r componentsSeparatedByString:@"\t"];
      for (int cc=0; cc<columnCount; cc++) {
        if (cc < [cols count]) {
          [stringToPaste appendFormat:@" %@ ", [[cols objectAtIndex:cc] texString]];
        }
        if (cc+1 < columnCount) {
          [stringToPaste appendFormat:@"&"];
        }
      }
      [stringToPaste appendFormat:@"\\\\ \\hline\n"];
    }
    
    [stringToPaste appendFormat:@"\\end{tabular}\n"];
    [stringToPaste appendFormat:@"\\end{center}\n"];
    [stringToPaste appendFormat:@"\\caption{Pasted Table}\n"];
    [stringToPaste appendFormat:@"\\label{tab:pastedTable}\n"];
    [stringToPaste appendFormat:@"\\end{table}\n"];
    
    [self insertText:stringToPaste];    
  }
  
  [self performSelector:@selector(colorWholeDocument) withObject:nil afterDelay:0];
}


- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	NSInteger tag = [menuItem tag];
  if (tag == 1060) {
    // paste as table. Check we have text on the pasteboard
    NSPasteboard *pboard = [NSPasteboard generalPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSRTFDPboardType, NSRTFPboardType, NSStringPboardType,nil]];
    if (type) {
      return YES;
    } else {
      return NO;
    }
  }
  
  if (tag == 1050) {
    NSPasteboard *pboard = [NSPasteboard generalPasteboard];
    NSString *type = [pboard availableTypeFromArray:[NSImage imageTypes]];
    if (type) {
      return YES;
    } else {
      
      type = [pboard availableTypeFromArray:[NSArray arrayWithObjects: NSRTFDPboardType, NSRTFPboardType, NSStringPboardType, nil]];
      if (type) {
        return YES;
      }
      
      return NO;
    }
  }
  
  return [super validateMenuItem:menuItem];
}

@end
