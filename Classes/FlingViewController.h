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

#import <UIKit/UIKit.h>
#import "Media.h"
#import "MatchstickDeviceController.h"

/**
 * A view that shows the media thumbnail and controls for media playing on the
 * Matchstick device.
 */
@interface FlingViewController : UIViewController <MatchstickControllerDelegate>

/** The media object being played on dongle. Set this before presenting the view. */
@property(strong, nonatomic) Media *mediaToPlay;

/** The media object and when to start playing on dongle. Set this before presenting the view. */
- (void)setMediaToPlay:(Media *)newMedia withStartingTime:(NSTimeInterval)startTime;

@end