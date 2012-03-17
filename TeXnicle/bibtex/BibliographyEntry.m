//
//  BibliographyEntry.m
//  TeXnicle
//
//  Created by Martin Hewitson on 22/3/10.
//  Copyright 2010 AEI Hannover . All rights reserved.
//

#import "BibliographyEntry.h"
#import "NSMutableAttributedString+BibFieldDisplay.h"

@implementation BibliographyEntry


@synthesize tag;
@synthesize author;
@synthesize title;
@synthesize publishedDate;


- (id)init
{
	self = [super init];
	
	if (self) {
	
		[self setTag:@"Entry"];
		[self setAuthor:@"Unknown"];
		[self setTitle:@"Unknown"];
		[self setPublishedDate:@"Unknown"];
		
		
	}
	
	return self;
}

- (id) initWithString:(NSString*)content
{
  self = [self init];
  if (self) {
    
    [self parseContentFromString:content];
    
  }
  return self;
}

- (id) initWithDictionary:(NSDictionary*)entryData
{
	self = [super init];
	
	if (self) {
		
		[self setTag:@"Entry"];
		[self setAuthor:@"Unknown"];
		[self setTitle:@"Unknown"];
		[self setPublishedDate:@"Unknown"];
		
		NSString *str = [entryData valueForKey:@"Tag"];
		if (str)	
			[self setTag:str];
		
		str = [entryData valueForKey:@"Author"];
		if (str)
			[self setAuthor:str];

		str = [entryData valueForKey:@"Title"];
		if (str) 
			[self setTitle:str];
		
		str = [entryData valueForKey:@"Year"];
		if (str) 
			[self setPublishedDate:str];

		[self observeKeys];
		
	}
	
	return self;
}

+ (NSArray*)bibtexEntriesFromString:(NSString*)aString
{
  NSMutableArray *entries = [NSMutableArray array];
  NSInteger idx = 0;
  NSInteger strLen = [aString length];
  
  while( idx < strLen ) {
    
    if ([aString characterAtIndex:idx] == '@') {
      
      // parse out an entry
      
      NSInteger start = idx;
      // scan forward until we find a {
      idx++;
      while (idx < strLen) {
        if ([aString characterAtIndex:idx] == '{') {          
          break;
        }
        idx++;
      }
      NSInteger bracketCount = 1;
      idx++;
      while( idx < strLen) {
        if ([aString characterAtIndex:idx] == '{') {
          bracketCount++;
        }
        if ([aString characterAtIndex:idx] == '}') {
          bracketCount--;
        }
        if (bracketCount == 0) {
          break;
        }
        idx++;
      }
      
      NSString *entryString = [[aString substringWithRange:NSMakeRange(start, idx-start+1)] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
      BibliographyEntry *entry = [[[BibliographyEntry alloc] initWithString:entryString] autorelease];
      [entries addObject:entry];
      
    } // end found a @
    
    idx++;
  }
  
  return entries;
}

- (void) parseContentFromString:(NSString*)content
{
//  NSLog(@"Parsing from %@", content);
  
  // get tag 
  NSInteger idx = 0;
  NSInteger strLen = [content length];
  NSInteger start = 0;
  NSInteger end   = 0;
  while (idx < strLen) {
    if ([content characterAtIndex:idx] == '{'){
      start = idx+1;
      break;
    }
    idx++;
  }
  while (idx < strLen) {
    if ([content characterAtIndex:idx] == ','){
      end = idx;
      break;
    }
    idx++;
  }
  
  if (start < end && start > 0) {
    self.tag = [content substringWithRange:NSMakeRange(start, end-start)];
  }
  
  // get author
  self.author = [self parseBibtexField:@"author" fromString:content];
  
  // get title
  self.title = [self parseBibtexField:@"title" fromString:content];  
}

- (NSAttributedString*)attributedString
{
  NSAttributedString *comma = [[[NSAttributedString alloc] initWithString:@", "] autorelease];
  NSMutableAttributedString *att = [[[NSMutableAttributedString alloc] initWithString:@""] autorelease];
  
  if ([self.title length] > 0) {
    NSMutableAttributedString *titleString = [[[NSMutableAttributedString alloc] initWithString:self.title] autorelease];
    [titleString addAttribute:NSForegroundColorAttributeName value:[NSColor blackColor] range:NSMakeRange(0, [self.title length])];
    [att appendAttributedString:titleString];
    
  }
  
  if ([self.author length] > 0) {
    if ([att length]>0){
      [att appendAttributedString:comma];    
    }
    NSMutableAttributedString *authorString = [[[NSMutableAttributedString alloc] initWithString:self.author] autorelease];
    [authorString addAttribute:NSForegroundColorAttributeName value:[NSColor darkGrayColor] range:NSMakeRange(0, [self.author length])];
    [att appendAttributedString:authorString];
  }
  
  // if we don't have an author or title, use the tag
  if ([att length]==0) {    
    NSMutableAttributedString *tagString = [[[NSMutableAttributedString alloc] initWithString:self.tag] autorelease];
    [tagString addAttribute:NSFontAttributeName value:[NSFont boldSystemFontOfSize:12.0] range:NSMakeRange(0, [self.tag length])];  
    [att appendAttributedString:tagString];
  }
  
  return att;
}

- (NSString*)parseBibtexField:(NSString*)field fromString:(NSString*)content
{
  NSInteger idx = 0;
  NSInteger start = 0;
  NSInteger end = 0;
  NSInteger strLen = [content length];
  NSScanner *scanner = [NSScanner scannerWithString:content];
  [scanner setCaseSensitive:NO];
  if([scanner scanUpToString:field intoString:NULL]) {
    if ([scanner scanLocation]<strLen){
      idx = [scanner scanLocation];
      while (idx < strLen) {
        if ([content characterAtIndex:idx] == '{') {
          start = idx+1;
        }
        if ([content characterAtIndex:idx] == '}') {
          end = idx;
          break;
        }
        idx++;
      }
      
      return [content substringWithRange:NSMakeRange(start, end-start)];
      
    }
  }
  
  return @"";
}

- (void) dealloc
{
	[self stopObserving];
	[super dealloc];
}

- (void) setPropertiesFromEntry:(BibliographyEntry*)anEntry
{
	[self setTag:[anEntry tag]];
	[self setAuthor:[anEntry author]];
	[self setTitle:[anEntry title]];
	[self setPublishedDate:[anEntry publishedDate]];
}


#pragma mark -
#pragma mark KVO 

- (void)observeKeys
{
	for (NSString *key in [self observingKeys]) {
		[self addObserver:self 
					 forKeyPath:key
							options:NSKeyValueObservingOptionNew 
							context:NULL];
	}	
	isObservingKeys = YES;
}

- (void)observeValueForKeyPath:(NSString *)keyPath 
											ofObject:(id)object
												change:(NSDictionary *)change 
											 context:(void *)context
{
//	[[NSNotificationCenter defaultCenter] postNotificationName:TPBibliographyChangedNotification object:self];
}

- (void) stopObserving
{
	if (isObservingKeys) {
		for (NSString *key in [self observingKeys]) {
			[self removeObserver:self forKeyPath:key];
		}	
		isObservingKeys = NO;
	}
}

- (NSArray*) observingKeys
{
	return [NSArray arrayWithObjects:@"tag", @"author", @"title", @"publishedDate", @"category", nil];
}

#pragma mark -
#pragma mark Encoding/decoding

- (id)initWithCoder:(NSCoder *)coder
{
//	NSLog(@"InitWithCoder: BibliographyEntry");
	[super init];
	tag = [[coder decodeObjectForKey:@"tag"] retain];
	author = [[coder decodeObjectForKey:@"author"] retain];
	title = [[coder decodeObjectForKey:@"title"] retain];
	publishedDate = [[coder decodeObjectForKey:@"publishedDate"] retain];
//	NSLog(@"Loaded entry %@, %@, %@", author, title, publishedDate);
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:tag forKey:@"tag"];
	[coder encodeObject:author forKey:@"author"];
	[coder encodeObject:title forKey:@"title"];
	[coder encodeObject:publishedDate forKey:@"publishedDate"];
}

- (NSString*) description
{
	return [NSString stringWithFormat:@"[%@], [%@], [%@], [%@]", tag, author, title, publishedDate];
}

- (NSAttributedString*) displayString
{
	NSMutableAttributedString *str = [[[NSMutableAttributedString alloc] init] autorelease];
	// TAG
	NSString *vstr = [self tag];
	if (!vstr)
		vstr = @"";
	[str addString:vstr withTag:@"Tag:"];
	
	// Author
	vstr = [self author];
	if (!vstr)
		vstr = @"";
	[str addString:vstr withTag:@"Author:"];
	
	// Title
	vstr = [self title];
	if (!vstr)
		vstr = @"";
	[str addString:vstr withTag:@"Title:"];
	
	// Published Date
	vstr = [self publishedDate];
	if (!vstr)
		vstr = @"";
	[str addString:vstr withTag:@"Published:"];
	
	return str;
}

#pragma mark -
#pragma mark Control 

- (id)copyWithZone:(NSZone *)zone
{
	BibliographyEntry *copy = [[[self class] allocWithZone: zone] init];

	[copy setTag:[self tag]];
	[copy setAuthor:[self author]];
	[copy setTitle:[self title]];
	[copy setPublishedDate:[self publishedDate]];
			
	return copy;
}


- (NSString*) bibtexEntry
{
	NSMutableString *str = [NSMutableString stringWithString:@"@unpublished{"];
	
	// add tag
	[str appendFormat:@"%@,\n", [self tag]];
	
	// add author
	[str appendFormat:@"\tAuthor={%@},\n", [self author]];
	
	// add title 
	NSString *vstr = [self title];
	if (!vstr)
		vstr = @"";
	[str appendFormat:@"\tTitle={%@},\n", vstr];
	
	// add published
	vstr = [self publishedDate];
	if (!vstr)
		vstr = @"";
	[str appendFormat:@"\tYear={%@}", vstr];
	
	[str appendFormat:@"}"];
	
	return [NSString stringWithString:str];
}

@end