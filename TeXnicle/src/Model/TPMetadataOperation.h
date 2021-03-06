//
//  TPMetadataOperation.h
//  TeXnicle
//
//  Created by Martin Hewitson on 16/7/12.
//  Copyright (c) 2012 bobsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TPFileMetaData.h"

@interface TPMetadataOperation : NSOperation

//@property (copy, nonatomic) NSString *text;

// inputs
@property (strong, nonatomic) TPFileMetadata *file;

// metadata
@property (strong, nonatomic) NSArray *environments;
@property (strong, nonatomic) NSArray *commands;
@property (strong, nonatomic) NSArray *citations;
@property (strong, nonatomic) NSArray *syntaxErrors;
@property (strong, nonatomic) NSArray *labels;
@property (strong, nonatomic) NSArray *toDos;

- (id) initWithFile:(TPFileMetadata*)aFile;

@end
