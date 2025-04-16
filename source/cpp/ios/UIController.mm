// UIController.mm - Full implementation of the executor UI
#include "UIController.h"
#include <iostream>
#include <chrono>
#include "ui/UIDesignSystem.h"

#ifdef __OBJC__
#import <UIKit/UIKit.h>
#endif

// Objective-C implementation needs to be outside the namespace
#ifdef __OBJC__
// Forward declarations
@class UIEditorView;
@class UIConsoleView;
@class UIScriptListView;
@class UISettingsView;

// Main UI container
@interface UIControllerImpl : NSObject

@property (nonatomic, strong) UIView* mainView;
@property (nonatomic, strong) UIView* tabBarView;
@property (nonatomic, strong) UIView* contentView;
@property (nonatomic, strong) UIEditorView* editorView;
@property (nonatomic, strong) UIConsoleView* consoleView;
@property (nonatomic, strong) UIScriptListView* scriptListView;
@property (nonatomic, strong) UISettingsView* settingsView;
@property (nonatomic, strong) NSArray<UIButton*>* tabButtons;
@property (nonatomic, strong) UIView* buttonHighlight;
@property (nonatomic, strong) UIView* dragHandle;

@property (nonatomic, assign) BOOL isVisible;
@property (nonatomic, assign) BOOL isDraggable;
@property (nonatomic, assign) CGFloat opacity;
@property (nonatomic, assign) NSInteger currentTabIndex;
@property (nonatomic, weak) UIViewController* rootViewController;
@property (nonatomic, assign) void* cppController;

- (instancetype)initWithController:(void*)controller;
- (void)setupUI;
- (void)switchToTab:(NSInteger)tabIndex;
- (void)setScriptContent:(NSString*)content;
- (NSString*)getScriptContent;
- (void)appendToConsole:(NSString*)text;
- (void)clearConsole;
- (NSString*)getConsoleText;
- (void)refreshScriptsList;
- (void)show;
- (void)hide;
- (void)updateLayout;
- (void)setOpacity:(CGFloat)opacity;
- (void)setDraggable:(BOOL)draggable;
- (void)setupLEDEffects;
- (void)pulseLEDEffect;
- (void)saveUIState;
- (void)loadUIState;

@end

// Editor view for script editing
@interface UIEditorView : UIView

@property (nonatomic, strong) UITextView* textView;
@property (nonatomic, strong) UIToolbar* toolbar;
@property (nonatomic, strong) UIButton* executeButton;
@property (nonatomic, strong) UIButton* saveButton;
@property (nonatomic, strong) UIButton* clearButton;
@property (nonatomic, weak) UIControllerImpl* controller;

- (instancetype)initWithFrame:(CGRect)frame controller:(UIControllerImpl*)controller;
- (void)setContent:(NSString*)content;
- (NSString*)getContent;
- (void)setupEditor;

@end

// Console view for output
@interface UIConsoleView : UIView

@property (nonatomic, strong) UITextView* textView;
@property (nonatomic, strong) UIToolbar* toolbar;
@property (nonatomic, strong) UIButton* clearButton;
@property (nonatomic, strong) UIButton* copyButton;
@property (nonatomic, weak) UIControllerImpl* controller;

- (instancetype)initWithFrame:(CGRect)frame controller:(UIControllerImpl*)controller;
- (void)appendText:(NSString*)text;
- (void)clear;
- (NSString*)getText;

@end

// Script list view for saved scripts
@interface UIScriptListView : UIView <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView* tableView;
@property (nonatomic, strong) UIToolbar* toolbar;
@property (nonatomic, strong) UIButton* addButton;
@property (nonatomic, strong) UIButton* importButton;
@property (nonatomic, strong) NSMutableArray<NSDictionary*>* scripts;
@property (nonatomic, weak) UIControllerImpl* controller;

- (instancetype)initWithFrame:(CGRect)frame controller:(UIControllerImpl*)controller;
- (void)refreshList;
- (void)setScripts:(NSArray<NSDictionary*>*)scripts;

@end

// Settings view for configuration
@interface UISettingsView : UIView <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView* tableView;
@property (nonatomic, strong) NSArray<NSString*>* sectionTitles;
@property (nonatomic, strong) NSArray<NSArray<NSDictionary*>*>* settings;
@property (nonatomic, weak) UIControllerImpl* controller;

- (instancetype)initWithFrame:(CGRect)frame controller:(UIControllerImpl*)controller;
- (void)setupSettings;

@end

// Implementation of UIControllerImpl
@implementation UIControllerImpl

- (instancetype)initWithController:(void*)controller {
    self = [super init];
    if (self) {
        _cppController = controller;
        _isVisible = NO;
        _isDraggable = YES;
        _opacity = 0.9;
        _currentTabIndex = 0;
        
        // Find the key window and root view controller
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene* scene in [[UIApplication sharedApplication] connectedScenes]) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    for (UIWindow* window in scene.windows) {
                        if (window.isKeyWindow) {
                            _rootViewController = window.rootViewController;
                            break;
                        }
                    }
                }
            }
        } else {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            _rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
            #pragma clang diagnostic pop
        }
        
        [self setupUI];
        [self loadUIState];
    }
    return self;
}

- (void)setupUI {
    // Create main container view
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    CGFloat width = screenBounds.size.width * 0.85;
    CGFloat height = screenBounds.size.height * 0.75;
    CGRect frame = CGRectMake((screenBounds.size.width - width) / 2, 
                             (screenBounds.size.height - height) / 2,
                             width, height);
    
    self.mainView = [[UIView alloc] initWithFrame:frame];
    self.mainView.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.12 alpha:0.95];
    self.mainView.layer.cornerRadius = 12.0;
    self.mainView.clipsToBounds = YES;
    self.mainView.alpha = self.opacity;
    self.mainView.hidden = YES;
    
    // Add shadow
    self.mainView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.mainView.layer.shadowOffset = CGSizeMake(0, 4);
    self.mainView.layer.shadowRadius = 10;
    self.mainView.layer.shadowOpacity = 0.5;
    
    // Setup tab bar
    CGFloat tabBarHeight = 44.0;
    self.tabBarView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, tabBarHeight)];
    self.tabBarView.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.1 alpha:1.0];
    [self.mainView addSubview:self.tabBarView];
    
    // Setup content view
    self.contentView = [[UIView alloc] initWithFrame:CGRectMake(0, tabBarHeight, width, height - tabBarHeight)];
    [self.mainView addSubview:self.contentView];
    
    // Create tab buttons
    NSArray<NSString*>* tabTitles = @[@"Editor", @"Scripts", @"Console", @"Settings"];
    NSMutableArray<UIButton*>* buttons = [NSMutableArray arrayWithCapacity:tabTitles.count];
    CGFloat buttonWidth = width / tabTitles.count;
    
    for (NSInteger i = 0; i < tabTitles.count; i++) {
        UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.frame = CGRectMake(i * buttonWidth, 0, buttonWidth, tabBarHeight);
        [button setTitle:tabTitles[i] forState:UIControlStateNormal];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        button.tag = i;
        [button addTarget:self action:@selector(tabButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.tabBarView addSubview:button];
        [buttons addObject:button];
    }
    self.tabButtons = buttons;
    
    // Add LED highlight under the active tab
    self.buttonHighlight = [[UIView alloc] initWithFrame:CGRectMake(0, tabBarHeight - 2, buttonWidth, 2)];
    self.buttonHighlight.backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0];
    
    // Add glow effect to highlight
    self.buttonHighlight.layer.shadowColor = self.buttonHighlight.backgroundColor.CGColor;
    self.buttonHighlight.layer.shadowOffset = CGSizeMake(0, 0);
    self.buttonHighlight.layer.shadowRadius = 5.0;
    self.buttonHighlight.layer.shadowOpacity = 0.8;
    [self.tabBarView addSubview:self.buttonHighlight];
    
    // Create the content views for each tab
    CGRect contentFrame = self.contentView.bounds;
    
    // Editor view
    self.editorView = [[UIEditorView alloc] initWithFrame:contentFrame controller:self];
    [self.contentView addSubview:self.editorView];
    
    // Script list view
    self.scriptListView = [[UIScriptListView alloc] initWithFrame:contentFrame controller:self];
    self.scriptListView.hidden = YES;
    [self.contentView addSubview:self.scriptListView];
    
    // Console view
    self.consoleView = [[UIConsoleView alloc] initWithFrame:contentFrame controller:self];
    self.consoleView.hidden = YES;
    [self.contentView addSubview:self.consoleView];
    
    // Settings view
    self.settingsView = [[UISettingsView alloc] initWithFrame:contentFrame controller:self];
    self.settingsView.hidden = YES;
    [self.contentView addSubview:self.settingsView];
    
    // Add drag handle if draggable
    if (self.isDraggable) {
        CGFloat handleWidth = 40.0;
        CGFloat handleHeight = 5.0;
        self.dragHandle = [[UIView alloc] initWithFrame:CGRectMake((width - handleWidth) / 2, 5, handleWidth, handleHeight)];
        self.dragHandle.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.3];
        self.dragHandle.layer.cornerRadius = handleHeight / 2;
        [self.tabBarView addSubview:self.dragHandle];
        
        // Add pan gesture recognizer
        UIPanGestureRecognizer* panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self.mainView addGestureRecognizer:panGesture];
    }
    
    // Add to root view controller's view
    if (self.rootViewController) {
        [self.rootViewController.view addSubview:self.mainView];
    }
    
    // Setup LED effects
    [self setupLEDEffects];
    
    // Switch to the first tab
    [self switchToTab:0];
}

- (void)setupLEDEffects {
    // Create LED effect for button highlight
    CAGradientLayer* gradientLayer = [CAGradientLayer layer];
    gradientLayer.frame = self.buttonHighlight.bounds;
    gradientLayer.colors = @[
        (id)[UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:0.2].CGColor,
        (id)[UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:0.8].CGColor,
        (id)[UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:0.2].CGColor
    ];
    gradientLayer.startPoint = CGPointMake(0.0, 0.5);
    gradientLayer.endPoint = CGPointMake(1.0, 0.5);
    
    // Add breathing animation
    CABasicAnimation* breathingAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    breathingAnimation.fromValue = @(0.8);
    breathingAnimation.toValue = @(1.0);
    breathingAnimation.duration = 1.5;
    breathingAnimation.autoreverses = YES;
    breathingAnimation.repeatCount = INFINITY;
    [gradientLayer addAnimation:breathingAnimation forKey:@"breathing"];
    
    [self.buttonHighlight.layer insertSublayer:gradientLayer atIndex:0];
}

- (void)pulseLEDEffect {
    // Create a pulse animation for the button highlight
    CABasicAnimation* pulseAnimation = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
    pulseAnimation.fromValue = @(0.8);
    pulseAnimation.toValue = @(1.0);
    pulseAnimation.duration = 0.3;
    pulseAnimation.autoreverses = YES;
    pulseAnimation.repeatCount = 2;
    [self.buttonHighlight.layer addAnimation:pulseAnimation forKey:@"pulse"];
}

- (void)tabButtonTapped:(UIButton*)sender {
    [self switchToTab:sender.tag];
}

- (void)switchToTab:(NSInteger)tabIndex {
    // Update button highlight position
    CGRect highlightFrame = self.buttonHighlight.frame;
    CGFloat buttonWidth = self.tabBarView.bounds.size.width / self.tabButtons.count;
    highlightFrame.origin.x = tabIndex * buttonWidth;
    highlightFrame.size.width = buttonWidth;
    
    [UIView animateWithDuration:0.3
                          delay:0
         usingSpringWithDamping:0.7
          initialSpringVelocity:0.5
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         self.buttonHighlight.frame = highlightFrame;
                     }
                     completion:nil];
    
    // Hide all content views
    self.editorView.hidden = YES;
    self.scriptListView.hidden = YES;
    self.consoleView.hidden = YES;
    self.settingsView.hidden = YES;
    
    // Show the selected content view
    switch (tabIndex) {
        case 0:
            self.editorView.hidden = NO;
            break;
        case 1:
            self.scriptListView.hidden = NO;
            [self.scriptListView refreshList];
            break;
        case 2:
            self.consoleView.hidden = NO;
            break;
        case 3:
            self.settingsView.hidden = NO;
            break;
    }
    
    // Update current tab index
    self.currentTabIndex = tabIndex;
    
    // Pulse LED effect
    [self pulseLEDEffect];
}

- (void)setScriptContent:(NSString*)content {
    [self.editorView setContent:content];
}

- (NSString*)getScriptContent {
    return [self.editorView getContent];
}

- (void)appendToConsole:(NSString*)text {
    [self.consoleView appendText:text];
}

- (void)clearConsole {
    [self.consoleView clear];
}

- (NSString*)getConsoleText {
    return [self.consoleView getText];
}

- (void)refreshScriptsList {
    [self.scriptListView refreshList];
}

- (void)show {
    if (self.isVisible) return;
    
    self.mainView.hidden = NO;
    self.mainView.alpha = 0.0;
    
    [UIView animateWithDuration:0.3
                     animations:^{
                         self.mainView.alpha = self.opacity;
                     }
                     completion:^(BOOL finished) {
                         self.isVisible = YES;
                     }];
}

- (void)hide {
    if (!self.isVisible) return;
    
    [UIView animateWithDuration:0.3
                     animations:^{
                         self.mainView.alpha = 0.0;
                     }
                     completion:^(BOOL finished) {
                         self.mainView.hidden = YES;
                         self.isVisible = NO;
                     }];
}

- (void)updateLayout {
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    CGFloat width = screenBounds.size.width * 0.85;
    CGFloat height = screenBounds.size.height * 0.75;
    
    [UIView animateWithDuration:0.3
                     animations:^{
                         self.mainView.frame = CGRectMake((screenBounds.size.width - width) / 2,
                                                        (screenBounds.size.height - height) / 2,
                                                        width, height);
                         
                         // Update tab bar
                         self.tabBarView.frame = CGRectMake(0, 0, width, self.tabBarView.frame.size.height);
                         
                         // Update content view
                         self.contentView.frame = CGRectMake(0, self.tabBarView.frame.size.height,
                                                          width, height - self.tabBarView.frame.size.height);
                         
                         // Update tab buttons
                         CGFloat buttonWidth = width / self.tabButtons.count;
                         for (NSInteger i = 0; i < self.tabButtons.count; i++) {
                             UIButton* button = self.tabButtons[i];
                             button.frame = CGRectMake(i * buttonWidth, 0, buttonWidth, self.tabBarView.frame.size.height);
                         }
                         
                         // Update button highlight
                         CGRect highlightFrame = self.buttonHighlight.frame;
                         highlightFrame.origin.x = self.currentTabIndex * buttonWidth;
                         highlightFrame.size.width = buttonWidth;
                         self.buttonHighlight.frame = highlightFrame;
                         
                         // Update content views
                         CGRect contentFrame = self.contentView.bounds;
                         self.editorView.frame = contentFrame;
                         self.scriptListView.frame = contentFrame;
                         self.consoleView.frame = contentFrame;
                         self.settingsView.frame = contentFrame;
                     }];
}

- (void)setOpacity:(CGFloat)opacity {
    self.opacity = opacity;
    self.mainView.alpha = self.isVisible ? opacity : 0.0;
}

- (void)setDraggable:(BOOL)draggable {
    self.isDraggable = draggable;
    self.dragHandle.hidden = !draggable;
    
    // Enable/disable pan gesture
    for (UIGestureRecognizer* gesture in self.mainView.gestureRecognizers) {
        if ([gesture isKindOfClass:[UIPanGestureRecognizer class]]) {
            gesture.enabled = draggable;
        }
    }
}

- (void)handlePan:(UIPanGestureRecognizer*)gesture {
    CGPoint translation = [gesture translationInView:self.rootViewController.view];
    
    if (gesture.state == UIGestureRecognizerStateChanged) {
        // Move the view
        CGRect frame = self.mainView.frame;
        frame.origin.x += translation.x;
        frame.origin.y += translation.y;
        self.mainView.frame = frame;
        
        // Reset translation
        [gesture setTranslation:CGPointZero inView:self.rootViewController.view];
    } else if (gesture.state == UIGestureRecognizerStateEnded || 
              gesture.state == UIGestureRecognizerStateCancelled) {
        // Ensure the view stays within the screen bounds
        CGRect frame = self.mainView.frame;
        CGRect screenBounds = [[UIScreen mainScreen] bounds];
        
        // Constrain to screen edges
        if (frame.origin.x < 0) {
            frame.origin.x = 0;
        } else if (frame.origin.x + frame.size.width > screenBounds.size.width) {
            frame.origin.x = screenBounds.size.width - frame.size.width;
        }
        
        if (frame.origin.y < 0) {
            frame.origin.y = 0;
        } else if (frame.origin.y + frame.size.height > screenBounds.size.height) {
            frame.origin.y = screenBounds.size.height - frame.size.height;
        }
        
        // Animate to constrained position
        [UIView animateWithDuration:0.3
                         animations:^{
                             self.mainView.frame = frame;
                         }];
    }
}

- (void)saveUIState {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:self.currentTabIndex forKey:@"UIController_CurrentTab"];
    [defaults setFloat:self.opacity forKey:@"UIController_Opacity"];
    [defaults setBool:self.isDraggable forKey:@"UIController_Draggable"];
    [defaults setBool:self.isVisible forKey:@"UIController_Visible"];
    
    // Save position
    CGRect frame = self.mainView.frame;
    [defaults setFloat:frame.origin.x forKey:@"UIController_X"];
    [defaults setFloat:frame.origin.y forKey:@"UIController_Y"];
    
    [defaults synchronize];
}

- (void)loadUIState {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    // Load tab
    if ([defaults objectForKey:@"UIController_CurrentTab"]) {
        NSInteger tabIndex = [defaults integerForKey:@"UIController_CurrentTab"];
        [self switchToTab:tabIndex];
    }
    
    // Load opacity
    if ([defaults objectForKey:@"UIController_Opacity"]) {
        CGFloat opacity = [defaults floatForKey:@"UIController_Opacity"];
        [self setOpacity:opacity];
    }
    
    // Load draggable
    if ([defaults objectForKey:@"UIController_Draggable"]) {
        BOOL draggable = [defaults boolForKey:@"UIController_Draggable"];
        [self setDraggable:draggable];
    }
    
    // Load position
    if ([defaults objectForKey:@"UIController_X"] && [defaults objectForKey:@"UIController_Y"]) {
        CGFloat x = [defaults floatForKey:@"UIController_X"];
        CGFloat y = [defaults floatForKey:@"UIController_Y"];
        CGRect frame = self.mainView.frame;
        frame.origin.x = x;
        frame.origin.y = y;
        self.mainView.frame = frame;
    }
    
    // Load visibility
    if ([defaults objectForKey:@"UIController_Visible"]) {
        BOOL visible = [defaults boolForKey:@"UIController_Visible"];
        if (visible) {
            [self show];
        }
    }
}

@end

// Basic editor view implementation
@implementation UIEditorView

- (instancetype)initWithFrame:(CGRect)frame controller:(UIControllerImpl*)controller {
    self = [super initWithFrame:frame];
    if (self) {
        self.controller = controller;
        [self setupEditor];
    }
    return self;
}

- (void)setupEditor {
    // Create toolbar
    CGFloat toolbarHeight = 44.0;
    self.toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, self.bounds.size.height - toolbarHeight, self.bounds.size.width, toolbarHeight)];
    self.toolbar.barStyle = UIBarStyleBlack;
    self.toolbar.translucent = YES;
    [self addSubview:self.toolbar];
    
    // Create text view
    self.textView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height - toolbarHeight)];
    self.textView.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:1.0];
    self.textView.textColor = [UIColor whiteColor];
    self.textView.font = [UIFont fontWithName:@"Menlo" size:14.0];
    self.textView.autocorrectionType = UITextAutocorrectionTypeNo;
    self.textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.textView.keyboardAppearance = UIKeyboardAppearanceDark;
    self.textView.text = @"-- Enter your script here\n\nprint(\"Hello, Roblox!\")\n";
    [self addSubview:self.textView];
    
    // Create toolbar buttons
    CGFloat buttonWidth = 70.0;
    CGFloat buttonHeight = 30.0;
    CGFloat buttonMargin = 10.0;
    CGFloat y = (toolbarHeight - buttonHeight) / 2;
    CGFloat x = buttonMargin;
    
    // Execute button
    self.executeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.executeButton.frame = CGRectMake(x, y, buttonWidth, buttonHeight);
    [self.executeButton setTitle:@"Execute" forState:UIControlStateNormal];
    [self.executeButton setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
    self.executeButton.layer.borderColor = [UIColor greenColor].CGColor;
    self.executeButton.layer.borderWidth = 1.0;
    self.executeButton.layer.cornerRadius = 5.0;
    [self.executeButton addTarget:self action:@selector(executeButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.toolbar addSubview:self.executeButton];
    
    // Add glow effect
    self.executeButton.layer.shadowColor = [UIColor greenColor].CGColor;
    self.executeButton.layer.shadowOffset = CGSizeMake(0, 0);
    self.executeButton.layer.shadowRadius = 5.0;
    self.executeButton.layer.shadowOpacity = 0.5;
    
    x += buttonWidth + buttonMargin;
    
    // Save button
    self.saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.saveButton.frame = CGRectMake(x, y, buttonWidth, buttonHeight);
    [self.saveButton setTitle:@"Save" forState:UIControlStateNormal];
    [self.saveButton setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
    self.saveButton.layer.borderColor = [UIColor cyanColor].CGColor;
    self.saveButton.layer.borderWidth = 1.0;
    self.saveButton.layer.cornerRadius = 5.0;
    [self.saveButton addTarget:self action:@selector(saveButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.toolbar addSubview:self.saveButton];
    
    // Add glow effect
    self.saveButton.layer.shadowColor = [UIColor cyanColor].CGColor;
    self.saveButton.layer.shadowOffset = CGSizeMake(0, 0);
    self.saveButton.layer.shadowRadius = 5.0;
    self.saveButton.layer.shadowOpacity = 0.5;
    
    x += buttonWidth + buttonMargin;
    
    // Clear button
    self.clearButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.clearButton.frame = CGRectMake(x, y, buttonWidth, buttonHeight);
    [self.clearButton setTitle:@"Clear" forState:UIControlStateNormal];
    [self.clearButton setTitleColor:[UIColor orangeColor] forState:UIControlStateNormal];
    self.clearButton.layer.borderColor = [UIColor orangeColor].CGColor;
    self.clearButton.layer.borderWidth = 1.0;
    self.clearButton.layer.cornerRadius = 5.0;
    [self.clearButton addTarget:self action:@selector(clearButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.toolbar addSubview:self.clearButton];
    
    // Add glow effect
    self.clearButton.layer.shadowColor = [UIColor orangeColor].CGColor;
    self.clearButton.layer.shadowOffset = CGSizeMake(0, 0);
    self.clearButton.layer.shadowRadius = 5.0;
    self.clearButton.layer.shadowOpacity = 0.5;
}

- (void)executeButtonTapped {
    // Flash the execute button
    [UIView animateWithDuration:0.1 animations:^{
        self.executeButton.alpha = 0.5;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.1 animations:^{
            self.executeButton.alpha = 1.0;
        }];
    }];
    
    // Execute the script (call back to C++ controller)
    NSString* script = [self getContent];
    if (script.length > 0) {
        iOS::UIController* cppController = (iOS::UIController*)self.controller.cppController;
        cppController->ExecuteCurrentScript();
    }
}

- (void)saveButtonTapped {
    // Flash the save button
    [UIView animateWithDuration:0.1 animations:^{
        self.saveButton.alpha = 0.5;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.1 animations:^{
            self.saveButton.alpha = 1.0;
        }];
    }];
    
    // Show a popup to name the script
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Save Script"
                                                                   message:@"Enter a name for the script"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField* textField) {
        textField.placeholder = @"Script Name";
    }];
    
    UIAlertAction* saveAction = [UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
        NSString* scriptName = alert.textFields.firstObject.text;
        if (scriptName.length > 0) {
            iOS::UIController* cppController = (iOS::UIController*)self.controller.cppController;
            cppController->SaveCurrentScript(std::string([scriptName UTF8String]));
        }
    }];
    
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    
    [alert addAction:saveAction];
    [alert addAction:cancelAction];
    
    [self.controller.rootViewController presentViewController:alert animated:YES completion:nil];
}

- (void)clearButtonTapped {
    // Flash the clear button
    [UIView animateWithDuration:0.1 animations:^{
        self.clearButton.alpha = 0.5;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.1 animations:^{
            self.clearButton.alpha = 1.0;
        }];
    }];
    
    // Confirm clear
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Clear Editor"
                                                                   message:@"Are you sure you want to clear the editor?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* clearAction = [UIAlertAction actionWithTitle:@"Clear" style:UIAlertActionStyleDestructive handler:^(UIAlertAction* action) {
        self.textView.text = @"";
    }];
    
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    
    [alert addAction:clearAction];
    [alert addAction:cancelAction];
    
    [self.controller.rootViewController presentViewController:alert animated:YES completion:nil];
}

- (void)setContent:(NSString*)content {
    self.textView.text = content;
}

- (NSString*)getContent {
    return self.textView.text;
}

@end

// Basic console view implementation
@implementation UIConsoleView

- (instancetype)initWithFrame:(CGRect)frame controller:(UIControllerImpl*)controller {
    self = [super initWithFrame:frame];
    if (self) {
        self.controller = controller;
        
        // Create text view for console output
        self.textView = [[UITextView alloc] initWithFrame:self.bounds];
        self.textView.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.07 alpha:1.0];
        self.textView.textColor = [UIColor greenColor];
        self.textView.font = [UIFont fontWithName:@"Menlo" size:12.0];
        self.textView.editable = NO;
        self.textView.text = @"Console output will appear here.\n";
        [self addSubview:self.textView];
    }
    return self;
}

- (void)appendText:(NSString*)text {
    // Append text to console
    NSAttributedString* attrString = [[NSAttributedString alloc] initWithString:text attributes:@{
        NSForegroundColorAttributeName: [UIColor greenColor],
        NSFontAttributeName: [UIFont fontWithName:@"Menlo" size:12.0]
    }];
    
    NSMutableAttributedString* currentText = [[NSMutableAttributedString alloc] initWithAttributedString:self.textView.attributedText];
    [currentText appendAttributedString:attrString];
    
    self.textView.attributedText = currentText;
    
    // Scroll to end
    [self.textView scrollRangeToVisible:NSMakeRange(self.textView.text.length, 0)];
}

- (void)clear {
    self.textView.text = @"";
}

- (NSString*)getText {
    return self.textView.text;
}

@end

// Script list view implementation (minimal)
@implementation UIScriptListView

- (instancetype)initWithFrame:(CGRect)frame controller:(UIControllerImpl*)controller {
    self = [super initWithFrame:frame];
    if (self) {
        self.controller = controller;
        self.scripts = [NSMutableArray array];
        
        // Create table view
        self.tableView = [[UITableView alloc] initWithFrame:self.bounds style:UITableViewStylePlain];
        self.tableView.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:1.0];
        self.tableView.delegate = self;
        self.tableView.dataSource = self;
        [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"ScriptCell"];
        [self addSubview:self.tableView];
    }
    return self;
}

- (void)refreshList {
    // Reload the table view
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
    return self.scripts.count;
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath {
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"ScriptCell" forIndexPath:indexPath];
    
    if (indexPath.row < self.scripts.count) {
        NSDictionary* script = self.scripts[indexPath.row];
        cell.textLabel.text = script[@"name"];
        cell.textLabel.textColor = [UIColor whiteColor];
    }
    
    return cell;
}

- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
    if (indexPath.row < self.scripts.count) {
        // Load the selected script
        NSDictionary* script = self.scripts[indexPath.row];
        [self.controller setScriptContent:script[@"content"]];
        [self.controller switchToTab:0]; // Switch to editor
    }
}

@end

// Settings view implementation (minimal)
@implementation UISettingsView

- (instancetype)initWithFrame:(CGRect)frame controller:(UIControllerImpl*)controller {
    self = [super initWithFrame:frame];
    if (self) {
        self.controller = controller;
        [self setupSettings];
    }
    return self;
}

- (void)setupSettings {
    // Create settings table view
    self.tableView = [[UITableView alloc] initWithFrame:self.bounds style:UITableViewStyleGrouped];
    self.tableView.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:1.0];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self addSubview:self.tableView];
    
    // Set up sections
    self.sectionTitles = @[@"Appearance", @"Behavior", @"About"];
    
    // Set up settings
    NSMutableArray* appearanceSettings = [NSMutableArray array];
    [appearanceSettings addObject:@{@"title": @"UI Opacity", @"type": @"slider"}];
    [appearanceSettings addObject:@{@"title": @"LED Effects", @"type": @"switch"}];
    
    NSMutableArray* behaviorSettings = [NSMutableArray array];
    [behaviorSettings addObject:@{@"title": @"Draggable UI", @"type": @"switch"}];
    [behaviorSettings addObject:@{@"title": @"Auto-Hide", @"type": @"switch"}];
    
    NSMutableArray* aboutSettings = [NSMutableArray array];
    [aboutSettings addObject:@{@"title": @"Version", @"type": @"label", @"value": @"1.0.0"}];
    
    self.settings = @[appearanceSettings, behaviorSettings, aboutSettings];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView {
    return self.sectionTitles.count;
}

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.settings[section] count];
}

- (NSString*)tableView:(UITableView*)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sectionTitles[section];
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath {
    static NSString* cellIdentifier = @"SettingCell";
    
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.textColor = [UIColor whiteColor];
    }
    
    // Configure cell
    NSDictionary* setting = self.settings[indexPath.section][indexPath.row];
    cell.textLabel.text = setting[@"title"];
    
    return cell;
}

@end
#endif

namespace iOS {
    // Constructor
    UIController::UIController()
        : m_uiView(nullptr), m_isVisible(false), m_currentTab(TabType::Editor),
          m_opacity(0.9f), m_isDraggable(true), m_currentScript("") {
        
        std::cout << "UIController: Initializing" << std::endl;
        
        // Create floating button
        m_floatingButton = std::make_unique<FloatingButtonController>();
        m_floatingButton->SetTapCallback([this]() {
            Toggle();
        });
    }
    
    // Destructor
    UIController::~UIController() {
        if (m_uiView) {
#ifdef __OBJC__
            UIControllerImpl* impl = (__bridge_transfer UIControllerImpl*)m_uiView;
            // The bridge_transfer will release the object
            m_uiView = nullptr;
#endif
        }
    }
    
    // Initialize the UI
    bool UIController::Initialize() {
        std::cout << "UIController: Initialize called" << std::endl;
        
        // Create the UI implementation
#ifdef __OBJC__
        UIControllerImpl* impl = [[UIControllerImpl alloc] initWithController:this];
        m_uiView = (__bridge_retained void*)impl;
#endif
        
        // Initialize the floating button
        m_floatingButton->Show();
        
        return true;
    }
    
    // Show the UI
    void UIController::Show() {
        if (m_isVisible) return;
        
#ifdef __OBJC__
        // Show the UI via Objective-C implementation
        if (m_uiView) {
            UIControllerImpl* impl = (__bridge UIControllerImpl*)m_uiView;
            [impl show];
            m_isVisible = true;
        }
#endif
        
        std::cout << "UIController: Show called" << std::endl;
    }
    
    // Hide the UI
    void UIController::Hide() {
        if (!m_isVisible) return;
        
#ifdef __OBJC__
        // Hide the UI via Objective-C implementation
        if (m_uiView) {
            UIControllerImpl* impl = (__bridge UIControllerImpl*)m_uiView;
            [impl hide];
            m_isVisible = false;
        }
#endif
        
        std::cout << "UIController: Hide called" << std::endl;
    }
    
    // Toggle UI visibility
    bool UIController::Toggle() {
        if (m_isVisible) {
            Hide();
        } else {
            Show();
        }
        return m_isVisible;
    }
    
    // Check if UI is visible
    bool UIController::IsVisible() const {
        return m_isVisible;
    }
    
    // Switch to a specific tab
    void UIController::SwitchTab(TabType tab) {
#ifdef __OBJC__
        if (m_uiView) {
            UIControllerImpl* impl = (__bridge UIControllerImpl*)m_uiView;
            [impl switchToTab:(NSInteger)tab];
            m_currentTab = tab;
        }
#endif
    }
    
    // Get current tab
    UIController::TabType UIController::GetCurrentTab() const {
        return m_currentTab;
    }
    
    // Set UI opacity
    void UIController::SetOpacity(float opacity) {
        m_opacity = opacity;
#ifdef __OBJC__
        if (m_uiView) {
            UIControllerImpl* impl = (__bridge UIControllerImpl*)m_uiView;
            [impl setOpacity:opacity];
        }
#endif
    }
    
    // Get UI opacity
    float UIController::GetOpacity() const {
        return m_opacity;
    }
    
    // Enable/disable UI dragging
    void UIController::SetDraggable(bool enabled) {
        m_isDraggable = enabled;
#ifdef __OBJC__
        if (m_uiView) {
            UIControllerImpl* impl = (__bridge UIControllerImpl*)m_uiView;
            [impl setDraggable:enabled];
        }
#endif
    }
    
    // Check if UI is draggable
    bool UIController::IsDraggable() const {
        return m_isDraggable;
    }
    
    // Set script content in editor
    void UIController::SetScriptContent(const std::string& script) {
        m_currentScript = script;
#ifdef __OBJC__
        if (m_uiView) {
            UIControllerImpl* impl = (__bridge UIControllerImpl*)m_uiView;
            NSString* nsScript = [NSString stringWithUTF8String:script.c_str()];
            [impl setScriptContent:nsScript];
        }
#endif
    }
    
    // Get script content from editor
    std::string UIController::GetScriptContent() const {
#ifdef __OBJC__
        if (m_uiView) {
            UIControllerImpl* impl = (__bridge UIControllerImpl*)m_uiView;
            NSString* content = [impl getScriptContent];
            return [content UTF8String];
        }
#endif
        return m_currentScript;
    }
    
    // Execute current script in editor
    bool UIController::ExecuteCurrentScript() {
        std::string script = GetScriptContent();
        
        if (script.empty()) {
            std::cerr << "UIController: Empty script, nothing to execute" << std::endl;
            return false;
        }
        
        // Execute the script using the callback
        if (m_executeCallback) {
            bool success = m_executeCallback(script);
            
            // Add to console
            std::string consoleMsg = "Executing script...\n" + script + "\n";
            consoleMsg += success ? "Execution succeeded.\n" : "Execution failed.\n";
            AppendToConsole(consoleMsg);
            
            return success;
        } else {
            std::cerr << "UIController: No execute callback set" << std::endl;
            return false;
        }
    }
    
    // Save current script in editor
    bool UIController::SaveCurrentScript(const std::string& name) {
        std::string script = GetScriptContent();
        
        if (script.empty()) {
            std::cerr << "UIController: Empty script, nothing to save" << std::endl;
            return false;
        }
        
        // Create a script info structure
        ScriptInfo scriptInfo(name.empty() ? "Unnamed Script" : name, script, 
                            std::chrono::duration_cast<std::chrono::milliseconds>(
                                std::chrono::system_clock::now().time_since_epoch()).count());
        
        // Save the script using the callback
        if (m_saveScriptCallback) {
            bool success = m_saveScriptCallback(scriptInfo);
            
            // Add to saved scripts list
            if (success) {
                m_savedScripts.push_back(scriptInfo);
                RefreshScriptsList();
            }
            
            return success;
        } else {
            std::cerr << "UIController: No save script callback set" << std::endl;
            return false;
        }
    }
    
    // Append text to console
    void UIController::AppendToConsole(const std::string& text) {
        m_consoleText += text;
        
#ifdef __OBJC__
        if (m_uiView) {
            UIControllerImpl* impl = (__bridge UIControllerImpl*)m_uiView;
            NSString* nsText = [NSString stringWithUTF8String:text.c_str()];
            [impl appendToConsole:nsText];
        }
#endif
    }
    
    // Clear the console
    void UIController::ClearConsole() {
        m_consoleText.clear();
        
#ifdef __OBJC__
        if (m_uiView) {
            UIControllerImpl* impl = (__bridge UIControllerImpl*)m_uiView;
            [impl clearConsole];
        }
#endif
    }
    
    // Get console text
    std::string UIController::GetConsoleText() const {
        return m_consoleText;
    }
    
    // Refresh scripts list
    void UIController::RefreshScriptsList() {
#ifdef __OBJC__
        if (m_uiView) {
            UIControllerImpl* impl = (__bridge UIControllerImpl*)m_uiView;
            [impl refreshScriptsList];
        }
#endif
    }
    
    // Set execute callback
    void UIController::SetExecuteCallback(ExecuteCallback callback) {
        m_executeCallback = callback;
    }
    
    // Set save script callback
    void UIController::SetSaveScriptCallback(SaveScriptCallback callback) {
        m_saveScriptCallback = callback;
    }
    
    // Set load scripts callback
    void UIController::SetLoadScriptsCallback(LoadScriptsCallback callback) {
        m_loadScriptsCallback = callback;
        
        // Load scripts immediately if callback is provided
        if (m_loadScriptsCallback) {
            m_savedScripts = m_loadScriptsCallback();
            RefreshScriptsList();
        }
    }
    
    // Check if button is visible
    bool UIController::IsButtonVisible() const {
        return m_floatingButton && m_floatingButton->IsVisible();
    }
    
    // Show/hide floating button
    void UIController::SetButtonVisible(bool visible) {
        if (m_floatingButton) {
            if (visible) {
                m_floatingButton->Show();
            } else {
                m_floatingButton->Hide();
            }
        }
    }
    
    // Load a script
    bool UIController::LoadScript(const ScriptInfo& scriptInfo) {
        SetScriptContent(scriptInfo.m_content);
        return true;
    }
    
    // Delete a script
    bool UIController::DeleteScript(const std::string& name) {
        auto it = std::find_if(m_savedScripts.begin(), m_savedScripts.end(),
                            [&name](const ScriptInfo& info) {
                                return info.m_name == name;
                            });
        
        if (it != m_savedScripts.end()) {
            m_savedScripts.erase(it);
            RefreshScriptsList();
            return true;
        }
        
        return false;
    }
}
