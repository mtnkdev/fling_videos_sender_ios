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

#import "FlingViewController.h"
#import "LocalPlayerViewController.h"
#import "AppDelegate.h"
#import "SimpleImageFetcher.h"
#import <Matchstick/Fling.h>


@interface FlingViewController () <VolumeChangeControllerDelegate> {
    NSTimeInterval _mediaStartTime;
    BOOL _currentlyDraggingSlider;
    BOOL _readyToShowInterface;
    BOOL _joinExistingSession;
    __weak MatchstickDeviceController *_matchstickController;
}
@property(strong, nonatomic) UIPopoverController *masterPopoverController;
@property IBOutlet UIImageView *thumbnailImage;
@property IBOutlet UILabel *flingingToLabel;
@property(weak, nonatomic) IBOutlet UILabel *mediaTitleLabel;
@property(weak, nonatomic) IBOutlet UIActivityIndicatorView *flingActivityIndicator;
@property(weak, nonatomic) NSTimer *updateStreamTimer;

@property(nonatomic) UIBarButtonItem *currTime;
@property(nonatomic) UIBarButtonItem *totalTime;
@property(nonatomic) UISlider *slider;
@property(nonatomic) NSArray *playToolbar;
@property(nonatomic) NSArray *pauseToolbar;
@property(nonatomic) NSArray *notHaveButtonBar;
@end

@implementation FlingViewController

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (self) {
        [self initControls];
    }

    return self;
}

- (void)dealloc {
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Store a reference to the controller.
    AppDelegate *delegate = (AppDelegate *) [UIApplication sharedApplication].delegate;
    _matchstickController = delegate.matchstickDeviceController;

    self.navigationItem.rightBarButtonItem = _matchstickController.matchstickBarButton;

    self.flingingToLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Flinging to %@", nil),
                                                          _matchstickController.deviceName];
    self.mediaTitleLabel.text = self.mediaToPlay.title;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Managing the detail item

- (void)setMediaToPlay:(Media *)newDetailItem {
    [self setMediaToPlay:newDetailItem withStartingTime:0];
}

- (void)setMediaToPlay:(Media *)newMedia withStartingTime:(NSTimeInterval)startTime {
    _mediaStartTime = startTime;
    if (_mediaToPlay != newMedia) {
        _mediaToPlay = newMedia;

        // Update the view.
        [self configureView];
    }
}

- (void)resetInterfaceElements {
    self.totalTime.title = @"";
    self.currTime.title = @"";
    [self.slider setValue:0];
    [self.flingActivityIndicator startAnimating];
    _currentlyDraggingSlider = NO;
    self.navigationController.toolbarHidden = YES;
    _readyToShowInterface = NO;
}

- (void)mediaNowPlaying {
    _readyToShowInterface = YES;
    [self updateInterfaceFromFling:nil];
    self.navigationController.toolbarHidden = NO;
}

- (void)updateInterfaceFromFling:(NSTimer *)timer {
    [_matchstickController updateStatsFromDevice];

    if (!_readyToShowInterface)
        return;

    if (_matchstickController.playerState != MSFKMediaPlayerStateBuffering) {
        [self.flingActivityIndicator stopAnimating];
    } else {
        [self.flingActivityIndicator startAnimating];
    }

    if (_matchstickController.streamDuration > 0 && !_currentlyDraggingSlider) {
        self.currTime.title = [self getFormattedTime:_matchstickController.streamPosition];
        self.totalTime.title = [self getFormattedTime:_matchstickController.streamDuration];
        [self.slider
                setValue:(_matchstickController.streamPosition / _matchstickController.streamDuration)
                animated:YES];
    }
//    if (_matchstickController.playerState == MSFKMediaPlayerStatePaused) {
//        self.toolbarItems = self.playToolbar;
//    } else if (_matchstickController.playerState == MSFKMediaPlayerStatePlaying ||
//            _matchstickController.playerState == MSFKMediaPlayerStateBuffering) {
//        self.toolbarItems = self.pauseToolbar;
//    } else if(_matchstickController.playerState == MSFKMediaPlayerStateUnknown || _matchstickController.playerState == MSFKMediaPlayerStateIdle){
//        self.toolbarItems = self.notHaveButtonBar;
//    }
    
    if (_matchstickController.playerState == MSFKMediaPlayerStatePaused ||
        _matchstickController.playerState == MSFKMediaPlayerStateIdle) {
        self.toolbarItems = self.playToolbar;
    } else if (_matchstickController.playerState == MSFKMediaPlayerStatePlaying ||
               _matchstickController.playerState == MSFKMediaPlayerStateBuffering) {
        self.toolbarItems = self.pauseToolbar;
    }
}

// Little formatting option here

- (NSString *)getFormattedTime:(NSTimeInterval)timeInSeconds {
    NSInteger seconds = (NSInteger) round(timeInSeconds);
    NSInteger hours = seconds / (60 * 60);
    seconds %= (60 * 60);

    NSInteger minutes = seconds / 60;
    seconds %= 60;

    if (hours > 0) {
        return [NSString stringWithFormat:@"%d:%02d:%02d", hours, minutes, seconds];
    } else {
        return [NSString stringWithFormat:@"%d:%02d", minutes, seconds];
    }
}

- (void)configureView {
    if (self.mediaToPlay && _matchstickController.isConnected) {
        NSURL *url = self.mediaToPlay.URL;
        self.flingingToLabel.text =
                [NSString stringWithFormat:@"Flinging to %@", _matchstickController.deviceName];
        self.mediaTitleLabel.text = self.mediaToPlay.title;
        NSLog(@"Flinging movie %@ at starting time %f", url, _mediaStartTime);

        //Loading thumbnail async
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            UIImage *image = [UIImage
                    imageWithData:[SimpleImageFetcher getDataFromImageURL:self.mediaToPlay.posterURL]];

            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"Loaded thumbnail image");
                self.thumbnailImage.image = image;
                [self.view setNeedsLayout];
            });
        });

        // If the newMedia is already playing, join the existing session.
        if (![self.mediaToPlay.title isEqualToString:[_matchstickController.mediaInformation.metadata
                stringForKey:kMSFKMetadataKeyTitle]]) {
            //Fling the movie!!
            [_matchstickController loadMedia:url
                                thumbnailURL:self.mediaToPlay.thumbnailURL
                                       title:self.mediaToPlay.title
                                    subtitle:self.mediaToPlay.subtitle
                                    mimeType:self.mediaToPlay.mimeType
                                   startTime:_mediaStartTime
                                    autoPlay:YES];
            _joinExistingSession = NO;
        } else {
            _joinExistingSession = YES;
            [self mediaNowPlaying];
        }

        // Start the timer
        if (self.updateStreamTimer) {
            [self.updateStreamTimer invalidate];
            self.updateStreamTimer = nil;
        }

        self.updateStreamTimer =
                [NSTimer scheduledTimerWithTimeInterval:1.0
                                                 target:self
                                               selector:@selector(updateInterfaceFromFling:)
                                               userInfo:nil
                                                repeats:YES];

    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (!_matchstickController.isConnected) {
        return;
    }

    // Assign ourselves as delegate ONLY in viewWillAppear of a view controller.
    _matchstickController.delegate = self;

    // Make the navigation bar transparent.
    [self.navigationController.navigationBar setBackgroundImage:[UIImage new]
                                                  forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.shadowImage = [UIImage new];

    // We want a transparent toolbar.
    [self.navigationController.toolbar setBackgroundImage:[UIImage new]
                                       forToolbarPosition:UIBarPositionBottom
                                               barMetrics:UIBarMetricsDefault];
    [self.navigationController.toolbar setShadowImage:[UIImage new]
                                   forToolbarPosition:UIBarPositionBottom];
    self.navigationController.toolbarHidden = YES;
    self.toolbarItems = self.playToolbar;

    [self resetInterfaceElements];

    if (_joinExistingSession == YES) {
        [self mediaNowPlaying];
    }

    [self configureView];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    // I think we can safely stop the timer here
    [self.updateStreamTimer invalidate];
    self.updateStreamTimer = nil;

    [self.navigationController.navigationBar setBackgroundImage:nil
                                                  forBarMetrics:UIBarMetricsDefault];
    [self.navigationController.toolbar setBackgroundImage:nil
                                       forToolbarPosition:UIBarPositionBottom
                                               barMetrics:UIBarMetricsDefault];
}

#pragma mark - On - screen UI elements
- (IBAction)pauseButtonClicked:(id)sender {
    [_matchstickController pauseFlingMedia:YES];
}

- (IBAction)playButtonClicked:(id)sender {
    [_matchstickController pauseFlingMedia:NO];
}

// Unsed, but if you wanted a stop, as opposed to a pause button, this is probably
// what you would call
- (IBAction)stopButtonClicked:(id)sender {
    [_matchstickController stopFlingMedia];
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (IBAction)onTouchDown:(id)sender {
    _currentlyDraggingSlider = YES;
}

// This is continuous, so we can update the current/end time labels
- (IBAction)onSliderValueChanged:(id)sender {
    float pctThrough = [self.slider value];
    if (_matchstickController.streamDuration > 0) {
        self.currTime.title =
                [self getFormattedTime:(pctThrough * _matchstickController.streamDuration)];
    }
}

// This is called only on one of the two touch up events
- (void)touchIsFinished {
    [_matchstickController setPlaybackPercent:[self.slider value]];
    _currentlyDraggingSlider = NO;
}

- (IBAction)onTouchUpInside:(id)sender {
    NSLog(@"Touch up inside");
    [self touchIsFinished];

}

- (IBAction)onTouchUpOutside:(id)sender {
    NSLog(@"Touch up outside");
    [self touchIsFinished];
}

#pragma mark - MatchstickControllerDelegate

/**
 * Called when connection to the device was closed.
 */
- (void)didDisconnect {
    [self.navigationController popViewControllerAnimated:YES];
}

/**
 * Called when the playback state of media on the device changes.
 */
- (void)didReceiveMediaStateChange {
    _readyToShowInterface = YES;
    self.navigationController.toolbarHidden = NO;

    if (_matchstickController.playerState == MSFKMediaPlayerStateIdle) {
//        [self.navigationController popViewControllerAnimated:YES];
    }
}

/**
 * Called to display the modal device view controller from the fling icon.
 */
- (void)shouldDisplayModalDeviceController {
    [self performSegueWithIdentifier:@"listDevices" sender:self];
}

#pragma mark - implementation.
- (void)initControls {
    UIBarButtonItem *playButton =
            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay
                                                          target:self
                                                          action:@selector(playButtonClicked:)];
    playButton.tintColor = [UIColor whiteColor];
    UIBarButtonItem *pauseButton =
            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPause
                                                          target:self
                                                          action:@selector(pauseButtonClicked:)];
    pauseButton.tintColor = [UIColor whiteColor];
    self.currTime = [[UIBarButtonItem alloc] initWithTitle:@"00:00"
                                                     style:UIBarButtonItemStylePlain
                                                    target:nil
                                                    action:nil];
    self.currTime.tintColor = [UIColor whiteColor];
    self.totalTime = [[UIBarButtonItem alloc] initWithTitle:@"100:00"
                                                      style:UIBarButtonItemStylePlain
                                                     target:nil
                                                     action:nil];
    self.totalTime.tintColor = [UIColor whiteColor];
    UIBarButtonItem *flexibleSpace =
            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                          target:nil
                                                          action:nil];
    UIBarButtonItem *flexibleSpace2 =
            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                          target:nil
                                                          action:nil];
    UIBarButtonItem *flexibleSpace3 =
            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                          target:nil
                                                          action:nil];

    self.slider = [[UISlider alloc] init];
    [self.slider addTarget:self
                    action:@selector(onSliderValueChanged:)
          forControlEvents:UIControlEventValueChanged];
    [self.slider addTarget:self
                    action:@selector(onTouchDown:)
          forControlEvents:UIControlEventTouchDown];
    [self.slider addTarget:self
                    action:@selector(onTouchUpInside:)
          forControlEvents:UIControlEventTouchUpInside];
    [self.slider addTarget:self
                    action:@selector(onTouchUpOutside:)
          forControlEvents:UIControlEventTouchUpOutside];
    self.slider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UIBarButtonItem *sliderItem = [[UIBarButtonItem alloc] initWithCustomView:self.slider];
    sliderItem.tintColor = [UIColor yellowColor];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        sliderItem.width = 500;
    }

    self.playToolbar = [NSArray arrayWithObjects:flexibleSpace,
                                                 playButton, flexibleSpace2, self.currTime, sliderItem, self.totalTime, flexibleSpace3, nil];
    self.pauseToolbar = [NSArray arrayWithObjects:flexibleSpace,
                                                  pauseButton, flexibleSpace2, self.currTime, sliderItem, self.totalTime, flexibleSpace3, nil];
    self.notHaveButtonBar = [NSArray arrayWithObjects:flexibleSpace,
                          flexibleSpace2, self.currTime, sliderItem, self.totalTime, flexibleSpace3, nil];
}


@end