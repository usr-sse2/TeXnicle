//
//  TPSupportedFilesEditor.m
//  TeXnicle
//
//  Created by Martin Hewitson on 06/01/12.
//  Copyright (c) 2012 bobsoft. All rights reserved.
//

#import "TPSupportedFilesEditor.h"
#import "TPSupportedFilesManager.h"

@implementation TPSupportedFilesEditor

@synthesize tableView;
@synthesize addButton;
@synthesize removeButton;

- (id)init
{
  self = [super initWithNibName:@"TPSupportedFilesEditor" bundle:nil];
  if (self) {
    // Initialization code here.
  }
  
  return self;
}

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)anItem
{
  
  if (anItem == self.addButton) {
    return YES;
  }
  
  if (anItem == self.removeButton) {
    TPSupportedFile *file = [self selectedFile];
    if (file != nil) {
      if ([file isBuiltIn]) {
        return NO;
      }
    } else {
      return NO;
    }
  }
  
  return YES;
}

- (TPSupportedFile*)selectedFile
{
  TPSupportedFilesManager *sfm = [TPSupportedFilesManager sharedSupportedFilesManager];
  NSInteger row = [self.tableView selectedRow];
  if (row >=0 && row < [sfm fileCount]) {
    return [sfm fileAtIndex:row];
  }
  
  return nil;
}

- (IBAction)addFileType:(id)sender
{
  TPSupportedFilesManager *sfm = [TPSupportedFilesManager sharedSupportedFilesManager];
  TPSupportedFile *newFile = [TPSupportedFile supportedFileWithName:@"New File Type" extension:@"ext"];
  [sfm addSupportedFileType:newFile];
  NSInteger index = [sfm indexOfFileType:newFile];
  [self.tableView reloadData];
  [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
}

- (IBAction)removeFileType:(id)sender
{
  TPSupportedFilesManager *sfm = [TPSupportedFilesManager sharedSupportedFilesManager];
  TPSupportedFile *file = [self selectedFile];
  [sfm removeSupportedFileType:file];
  [self.tableView reloadData];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
  TPSupportedFilesManager *sfm = [TPSupportedFilesManager sharedSupportedFilesManager];
  return [sfm fileCount];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
  TPSupportedFilesManager *sfm = [TPSupportedFilesManager sharedSupportedFilesManager];
  TPSupportedFile *file = [sfm fileAtIndex:row];
  
  if ([[tableColumn identifier] isEqualToString:@"ExtensionColumn"]) {
    return file.ext;
  } else if ([[tableColumn identifier] isEqualToString:@"NameColumn"]) {
    return file.name;
  } else if ([[tableColumn identifier] isEqualToString:@"HighlightColumn"]) {
    return [NSNumber numberWithBool:file.syntaxHighlight];
  } else {
    return nil;
  }
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
  TPSupportedFilesManager *sfm = [TPSupportedFilesManager sharedSupportedFilesManager];
  TPSupportedFile *file = [sfm fileAtIndex:row];
  
  if ([[tableColumn identifier] isEqualToString:@"ExtensionColumn"]) {
    file.ext = object;
  } else if ([[tableColumn identifier] isEqualToString:@"NameColumn"]) {
    file.name = object;
  } else if ([[tableColumn identifier] isEqualToString:@"HighlightColumn"]) {
    file.syntaxHighlight = [object boolValue];
  } else {
    // do nothing
  }
 
  [sfm saveTypes];
}

- (BOOL) tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
  TPSupportedFilesManager *sfm = [TPSupportedFilesManager sharedSupportedFilesManager];
  TPSupportedFile *file = [sfm fileAtIndex:row];
  if (file.isBuiltIn) {
    return NO;
  }
  
  return YES;
}

- (void) tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
  TPSupportedFilesManager *sfm = [TPSupportedFilesManager sharedSupportedFilesManager];
  TPSupportedFile *file = [sfm fileAtIndex:row];
  
  if ([[tableColumn identifier] isEqualToString:@"ExtensionColumn"]) {
    if ([file isBuiltIn]) {
      [cell setTextColor:[NSColor disabledControlTextColor]];
    } else {
      [cell setTextColor:[NSColor controlTextColor]];
    }
  } else if ([[tableColumn identifier] isEqualToString:@"NameColumn"]) {
    if ([file isBuiltIn]) {
      [cell setTextColor:[NSColor disabledControlTextColor]];
    } else {
      [cell setTextColor:[NSColor controlTextColor]];
    }
  } else if ([[tableColumn identifier] isEqualToString:@"HighlightColumn"]) {
    if ([file isBuiltIn]) {
      [cell setEnabled:NO];
    } else {
      [cell setEnabled:YES];
    }
  } else {
  }
  
  
}

@end