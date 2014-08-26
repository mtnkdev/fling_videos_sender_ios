// Copyright (C) 2013-2014, Infthink (Beijing) Technology Co., Ltd.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>
#import "Media.h"

/// Holds an array of media objects.
@interface MediaListModel : NSObject

/// Top level title of the list of media: ex: Videos
@property(strong, nonatomic) NSString* mediaTitle;

/// Loads all media from static URL and calls the supplied callback on completion.
- (void)loadMedia:(void (^)(void))callbackBlock;

/// The number of media objects in the array.
- (int)numberOfMediaLoaded;

/// Returns the media object at index.
- (Media*)mediaAtIndex:(int)index;
@end