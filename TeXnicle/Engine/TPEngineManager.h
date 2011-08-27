//
//  TPEngineManager.h
//  TeXnicle
//
//  Created by Martin Hewitson on 24/08/11.
//  Copyright 2011 bobsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TPEngine.h"

extern NSString * const TPEngineCompilingCompletedNotification;

@protocol TPEngineManagerDelegate <NSObject>
-(NSString*)engineName;
-(NSNumber*)doBibtex;
-(NSNumber*)doPS2PDF;
-(NSNumber*)openConsole;
-(NSNumber*)nCompile;
-(NSString*)documentToCompile;
-(NSString*)workingDirectory;
@end

@interface TPEngineManager : NSObject <TPEngineDelegate>

@property (assign) id<TPEngineManagerDelegate> delegate;
@property (retain) NSMutableArray *engines;

- (id)initWithDelegate:(id<TPEngineManagerDelegate>)aDelegate;
+ (TPEngineManager*)engineManagerWithDelegate:(id<TPEngineManagerDelegate>)aDelegate;
- (void)loadEngines;

+ (NSString*)engineDir;
+ (void) installEngines;

- (TPEngine*)engineNamed:(NSString*)name;
- (NSArray*)registeredEngineNames;

- (void) compile;
- (void) trashAuxFiles;

@end
