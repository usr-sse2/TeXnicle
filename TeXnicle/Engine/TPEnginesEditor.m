//
//  TPEnginesEditor.m
//  TeXnicle
//
//  Created by Martin Hewitson on 27/08/11.
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

#import "TPEnginesEditor.h"
#import "TPEngine.h"

NSString * const TPEngineListDidChangeNotification = @"TPEngineListDidChangeNotification";

@interface TPEnginesEditor ()

@property (unsafe_unretained) IBOutlet NSTableView *tableView;

@property (unsafe_unretained) IBOutlet HHValidatedButton *editButton;
@property (unsafe_unretained) IBOutlet HHValidatedButton *duplicateButton;
@property (unsafe_unretained) IBOutlet HHValidatedButton *addEngineButton;
@property (unsafe_unretained) IBOutlet HHValidatedButton *deleteButton;
@property (unsafe_unretained) IBOutlet HHValidatedButton *revealButton;

@end

@implementation TPEnginesEditor


- (id)init
{
  self = [super initWithNibName:@"TPEnginesEditor" bundle:nil];
  if (self) {
    // Initialization code here.
    self.engineManager = [[TPEngineManager alloc] initWithDelegate:self];
  }
  
  return self;
}

- (void) awakeFromNib
{

}

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)anItem
{
  TPEngine *engine = [self selectedEngine];
  
  if (anItem == self.editButton) {
    // check selected engine
    if (engine.isBuiltIn) {
      return NO;
    }
    if (engine==nil) {
      return NO;
    }
  }
  
  if (anItem == self.duplicateButton) {
    // check selected engine
    if (engine==nil) {
      return NO;
    }
  }  
  
  if (anItem == self.deleteButton) {
    if (engine == nil) {
      return NO;
    }
    if (engine.isBuiltIn) {
      return NO;
    }
  }
  
  if (anItem == self.revealButton) {
    if (engine == nil) {
      return NO;
    }
  }
  
  
  return YES;
}

- (TPEngine*)engineAtRow:(NSInteger)aRow
{
  if (aRow < 0) {
    return nil;
  }
  
  // get the selected engine name
  NSString *name = [self.engineManager registeredEngineNames][aRow];
  
  // get the engine
  TPEngine *engine = [self.engineManager engineNamed:name];
  return engine;
}

- (TPEngine*)selectedEngine
{
  NSInteger row = [self.tableView selectedRow];
  return [self engineAtRow:row];
}

#pragma mark -
#pragma mark control

- (IBAction)editSelectedEngine:(id)sender
{
  // get the engine
  TPEngine *engine = [self selectedEngine];
  
  if (engine.isBuiltIn) {
    
    // do nothing
    
  } else {
    // get the path
    NSString *path = engine.path;
    
    // make new document
    NSError *error = nil;
    id doc = [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[NSURL fileURLWithPath:path] display:YES error:&error];
    if (doc == nil) {
      [NSApp presentError:error];
    }
  }
}

- (IBAction)duplicateSelectedEngine:(id)sender
{
  // get engine
  TPEngine *engine = [self selectedEngine];
  if (!engine) {
    return;
  }
  
  // get path
  NSString *path = engine.path;
  
  // make new path
  NSString *newName = [engine.name stringByAppendingString:@"_copy"];
  NSString *newPath = [[[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:newName] stringByAppendingPathExtension:@"engine"];
  
  // copy the file
  NSFileManager *fm = [NSFileManager defaultManager];
  NSError *error = nil;
  BOOL success = [fm copyItemAtPath:path toPath:newPath error:&error];
  if (success == NO) {
    [NSApp presentError:error];
  }
  
  // reload engines
  [self.engineManager loadEngines];
  
  // reload table
  [self.tableView reloadData];
  
  // select the new engine
  [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[self.engineManager indexOfEngineNamed:newName]]
              byExtendingSelection:NO];
  
  // post notification
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc postNotificationName:TPEngineListDidChangeNotification object:self];
}

- (IBAction)newEngine:(id)sender
{
  NSString *engineDir = [TPEngineManager engineDir];
  
  // make name (checking existing names)
  NSString *name = @"new_engine";
  NSString *testName = [NSString stringWithString:name];
  NSInteger counter = 1;
  NSFileManager *fm = [NSFileManager defaultManager];
  while ([fm fileExistsAtPath:[[engineDir stringByAppendingPathComponent:testName] stringByAppendingPathExtension:@"engine"]]) {
    testName = [name stringByAppendingFormat:@"_%ld", counter];
    counter++;
  }
  
  // make new path
  NSString *newEnginePath = [[engineDir stringByAppendingPathComponent:testName] stringByAppendingPathExtension:@"engine"];
  
  // copy template to new path
  NSString *template = [[NSBundle mainBundle] pathForResource:@"template" ofType:@"engine"];
  NSError *error = nil;
  BOOL success = [fm copyItemAtPath:template toPath:newEnginePath error:&error];
  if (success == NO) {
    [NSApp presentError:error];
  }
    
  // reload engines
  [self.engineManager loadEngines];
  
  // reload table
  [self.tableView reloadData];
  
  // select the new engine
  [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[self.engineManager indexOfEngineNamed:testName]]
              byExtendingSelection:NO];  
  
  // post notification
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc postNotificationName:TPEngineListDidChangeNotification object:self];
}

- (IBAction)deleteSelectedEngine:(id)sender
{
  // get engine
  TPEngine *engine = [self selectedEngine];
  if (!engine) {
    return;
  }
  
  // prompt user
  NSAlert *alert = [NSAlert alertWithMessageText:@"Delete Engine?" 
                                   defaultButton:@"Delete" 
                                 alternateButton:@"Cancel" 
                                     otherButton:nil
                       informativeTextWithFormat:@"Are you sure you want to delete engine %@?", engine.name];
  
  NSInteger result = [alert runModal];
  
  if (result == NSAlertAlternateReturn) {
    return;
  }
  
  // move path on disk to trash
  NSString *source = [engine.path stringByDeletingLastPathComponent];
  NSString *file = [engine.path lastPathComponent];
  

  [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation
                                               source:source 
                                          destination:@""
                                                files:@[file] 
                                                  tag:nil];
  
  // reload engines
  [self.engineManager loadEngines];
  
  // reload table
  [self.tableView reloadData];
  
  // post notification
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc postNotificationName:TPEngineListDidChangeNotification object:self];
}

- (IBAction)revealSelectedEngine:(id)sender
{
  // get engine
  TPEngine *engine = [self selectedEngine];
  if (!engine) {
    return;
  }
  
  // get path
  NSString *path = engine.path;
  
  NSWorkspace *ws = [NSWorkspace sharedWorkspace];
  [ws selectFile:path inFileViewerRootedAtPath:[path stringByDeletingLastPathComponent]];
}

#pragma mark -
#pragma mark Data Source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
  return [[self.engineManager registeredEngineNames] count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
  return [self.engineManager registeredEngineNames][row];
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
  NSString *newName = (NSString*)object;
  
  // get engine
  TPEngine *engine = [self engineAtRow:row];
  
  // get path
  NSString *oldPath = engine.path;
  
  // get new path
  NSString *newPath = [[[oldPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:newName] stringByAppendingPathExtension:@"engine"];
  
  // move the file
  NSFileManager *fm = [NSFileManager defaultManager];
  NSError *error = nil;
  BOOL success = [fm moveItemAtPath:oldPath toPath:newPath error:&error];
  if (success == NO) {
    [NSApp presentError:error];
  }
  
  // reload engines
  [self.engineManager loadEngines];
  
  // reload table
  [self.tableView reloadData];
  
  // select the new engine
  [self performSelector:@selector(selectEngineNamed:) withObject:newName afterDelay:0];
}

- (void) selectEngineNamed:(NSString*)aName
{
  NSInteger index = [self.engineManager indexOfEngineNamed:aName];
  if (index >= 0 && index != NSNotFound) {
    [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index]
                byExtendingSelection:NO];
  }
}

#pragma mark -
#pragma mark Table view Delegate

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
  TPEngine *engine = [self engineAtRow:row];
  if (engine == nil) {
    return NO;
  }
  
  if (engine.isBuiltIn) {
    return NO;
  }
  
  return YES;
}

@end
