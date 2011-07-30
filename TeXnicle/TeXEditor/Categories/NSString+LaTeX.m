//
//  NSString+LaTeX.m
//  TeXnicle
//
//  Created by Martin Hewitson on 28/2/10.
//  Copyright 2010 bobsoft. All rights reserved.
//

#import "RegexKitLite.h"
#import "NSString+LaTeX.h"
#import "NSString+Comparisons.h"

@implementation NSString (LaTeX) 

- (NSArray*) referenceLabels
{	
	// scan string for all \label{something} and return the list of 'something's.
	NSArray *labels = [self componentsMatchedByRegex:@"\\\\label\\{.*?\\}"];
	
//	NSLog(@"Scanning %@", self);
//	NSLog(@"Found: %@",labels);
	NSMutableArray *tags = [NSMutableArray arrayWithCapacity:[labels count]];
	
	for (NSString *label in labels) {
		
		NSString *tag = [label stringByReplacingOccurrencesOfString:@"\\label{" withString:@""];
		tag = [tag stringByReplacingOccurrencesOfString:@"}" withString:@""];
		tag = [tag stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		[tags addObject:tag];
		
	}
	
	
	return tags;
}


- (NSArray*) citations
{
	NSMutableArray *cites = [NSMutableArray array];
	
	// First standard \bibitem commands
	NSArray *labels = [self componentsMatchedByRegex:@"\\\\bibitem[\\[[0-9]+\\]]*\\{.*\\}"];
	for (NSString *label in labels) {
		
		// get the range between { and }
		int start = -1;
		int end   = -1;
		for (int kk=0; kk<[label length]; kk++) {
			if ([label characterAtIndex:kk]=='{') {
				start = kk+1;
			}
			if ([label characterAtIndex:kk]=='}' && start >= 0) {				
				end = kk-1;
				break;
			}
		}
		if (start>=0 && end>start) {
			NSString *tag = [label substringWithRange:NSMakeRange(start, end-start+1)];
//			tag = [@"cite{" stringByAppendingString:tag];
			[cites addObject:tag];
		}
	}
	
	// now look for bibtex commands
	NSArray *bibtypes = [NSArray arrayWithObjects:@"article", @"book", @"booklet", 
											 @"commented", @"conference", @"glossdef", 
											 @"inbook", @"incollection", @"inproceedings", 
											 @"jurthesis", @"manual", @"mastersthesis", 
											 @"misc", @"periodical", @"phdthesis", 
											 @"proceedings", @"techreport", @"unpublished", 
											 @"url", @"electronic", @"webpage", nil];
	
	for (NSString *type in bibtypes) {
		NSString *pretag = [NSString stringWithFormat:@"\\@%@\\{", type];
		NSString *search = [pretag  stringByAppendingString:@".*,"];
		NSArray *entries = [self componentsMatchedByRegex:search];
		
		NSString *replace = [NSString stringWithFormat:@"@%@{", type];
		for (NSString *entry in entries) {
			
			// remove the @thing{ and the end ','
			NSString *tag = [[entry stringByReplacingOccurrencesOfString:replace withString:@""] 
											 stringByReplacingOccurrencesOfString:@"," withString:@""];																																															 
											 
//			tag = [@"cite{" stringByAppendingString:tag];
			[cites addObject:tag];
		}
		
	}
	
	
	return cites;
}

- (NSString *)nextWordStartingAtLocation:(NSUInteger*)loc
{
	NSCharacterSet *ws = [NSCharacterSet whitespaceCharacterSet];
	NSCharacterSet *ns = [NSCharacterSet newlineCharacterSet];
	
	NSUInteger start = (*loc)++;
	while (*loc < [self length]) {
		
		if ([ws characterIsMember:[self characterAtIndex:*loc]] ||
				[ns characterIsMember:[self characterAtIndex:*loc]]) {
			NSString *s = [[self substringWithRange:NSMakeRange(start, *loc-start)] stringByTrimmingCharactersInSet:ws];
			(*loc)--;
			return s;
		}
		
		(*loc)++;
	}
	return nil;
}

+ (NSString *)stringWithControlsFilteredForString:(NSString *)str 
{  
  if (str == nil) return nil;
  
  NSCharacterSet *filterChars = nil;
	
	// make a character set of control characters (but not whitespace/newline
	// characters), and keep a static immutable copy to use for filtering
	// strings
//	NSCharacterSet *ctrlChars = [NSCharacterSet controlCharacterSet];
	NSCharacterSet *newLineChars = [NSCharacterSet newlineCharacterSet];
//	NSCharacterSet *newlineWsChars = [NSCharacterSet whitespaceAndNewlineCharacterSet];
//	NSCharacterSet *nonNewlineWsChars = [newlineWsChars invertedSet];
	
	NSMutableCharacterSet *mutableChars = [[newLineChars mutableCopy] autorelease];
//	[mutableChars formIntersectionWithCharacterSet:nonNewlineWsChars];
//	[mutableChars formUnionWithCharacterSet:ctrlChars];
//	[mutableChars addCharactersInRange:NSMakeRange(0x0B, 2)]; // filter vt, ff
	[mutableChars addCharactersInRange:NSMakeRange(0x2028, 2)]; // filter vt, ff
//	[mutableChars addCharactersInRange:NSMakeRange(0x000b, 2)]; 
	
	filterChars = [mutableChars copy];
  
  // look for any invalid characters
  NSRange range = [str rangeOfCharacterFromSet:filterChars]; 
  if (range.location != NSNotFound) {
    
    // copy the string to a mutable, and remove null and non-whitespace 
    // control characters
    NSMutableString *mutableStr = [NSMutableString stringWithString:str];  
    while (range.location != NSNotFound) {
      
      [mutableStr deleteCharactersInRange:range];
//			[mutableStr replaceCharactersInRange:range withString:@" "];
      
      range = [mutableStr rangeOfCharacterFromSet:filterChars]; 
    }
   
		[filterChars release];
    return mutableStr;
  }
  
	[filterChars release];
  return [[str copy] autorelease];
}



@end













