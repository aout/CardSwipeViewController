//
//  ReminderActionViewController.m
//  Nimbly
//
//  Created by Guillaume CASTELLANA on 31/1/14.
//  Copyright (c) 2014 Guillaume CASTELLANA. All rights reserved.
//

#import "CardSwipeViewController.h"

@interface CardSwipeViewController ()

@property (nonatomic, strong) UIGestureRecognizer* pan;
@property (nonatomic, strong) UIDynamicAnimator* animator;
@property (nonatomic, strong) UIWindow* originalWindow;
@property (nonatomic, strong) UIWindow* controllerWindow;
//@property (nonatomic, strong) TransitionDelegate *transitionController;

@end

@implementation CardSwipeViewController

#pragma mark - UIViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
//        self.transitionController = [[TransitionDelegate alloc] init];
//        [self setTransitioningDelegate:self.transitionController];
//        self.modalPresentationStyle = UIModalPresentationCustom;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.viewToAnimate addGestureRecognizer:self.pan];
     self.animator = [[UIDynamicAnimator alloc] initWithReferenceView:self.view];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma ReminderActionViewController

- (void)handlePan:(UIPanGestureRecognizer *)gesture
{
    static UIAttachmentBehavior *attachment;
    static CGPoint               startCenter;
    
    // variables for calculating angular velocity
    
    static CFAbsoluteTime        lastTime;
    static CGFloat               lastAngle;
    static CGFloat               angularVelocity;
    
    if (gesture.state == UIGestureRecognizerStateBegan)
    {
        [self.animator removeAllBehaviors];
        
        startCenter = gesture.view.center;
        
        // calculate the center offset and anchor point
        
        CGPoint pointWithinAnimatedView = [gesture locationInView:gesture.view];
        
        UIOffset offset = UIOffsetMake(pointWithinAnimatedView.x - gesture.view.bounds.size.width / 2.0,
                                       pointWithinAnimatedView.y - gesture.view.bounds.size.height / 2.0);
        
        CGPoint anchor = [gesture locationInView:gesture.view.superview];
        
        // create attachment behavior
        
        attachment = [[UIAttachmentBehavior alloc] initWithItem:gesture.view
                                               offsetFromCenter:offset
                                               attachedToAnchor:anchor];
        
        // code to calculate angular velocity (seems curious that I have to calculate this myself, but I can if I have to)
        
        lastTime = CFAbsoluteTimeGetCurrent();
        lastAngle = [self angleOfView:gesture.view];
        
        attachment.action = ^{
            CFAbsoluteTime time = CFAbsoluteTimeGetCurrent();
            CGFloat angle = [self angleOfView:gesture.view];
            if (time > lastTime) {
                angularVelocity = (angle - lastAngle) / (time - lastTime);
                lastTime = time;
                lastAngle = angle;
            }
        };
        
        // add attachment behavior
        
        [self.animator addBehavior:attachment];
    }
    else if (gesture.state == UIGestureRecognizerStateChanged)
    {
        // as user makes gesture, update attachment behavior's anchor point, achieving drag 'n' rotate
        
        CGPoint anchor = [gesture locationInView:gesture.view.superview];
        attachment.anchorPoint = CGPointMake(attachment.anchorPoint.x, anchor.y);
    }
    else if (gesture.state == UIGestureRecognizerStateEnded)
    {
        [self.animator removeAllBehaviors];
        
        CGPoint velocity = [gesture velocityInView:gesture.view.superview];
        
        // if we aren't dragging it down, just snap it back and quit
        
        if (fabs(atan2(velocity.y, velocity.x) - M_PI_2) > M_PI_4) {
            UISnapBehavior *snap = [[UISnapBehavior alloc] initWithItem:gesture.view snapToPoint:startCenter];
            [self.animator addBehavior:snap];
            
            return;
        }
        
        // otherwise, create UIDynamicItemBehavior that carries on animation from where the gesture left off (notably linear and angular velocity)
        CGFloat center = gesture.view.center.y;
        CGFloat limit = self.view.frame.size.height*0.85;
        if (center > limit) {
            UIDynamicItemBehavior *dynamic = [[UIDynamicItemBehavior alloc] initWithItems:@[gesture.view]];
            [dynamic addLinearVelocity:velocity forItem:gesture.view];
            [dynamic addAngularVelocity:angularVelocity forItem:gesture.view];
            [dynamic setAngularResistance:2];
            
            // when the view no longer intersects with its superview, go ahead and remove it
            
            dynamic.action = ^{
                if (!CGRectIntersectsRect(gesture.view.superview.bounds, gesture.view.frame)) {
                    [self.animator removeAllBehaviors];
                    [gesture.view removeFromSuperview];
                }
            };
            [self.animator addBehavior:dynamic];
            
            // add a little gravity so it accelerates off the screen (in case user gesture was slow)
            
            UIGravityBehavior *gravity = [[UIGravityBehavior alloc] initWithItems:@[gesture.view]];
            gravity.magnitude = 0.7;
            [self.animator addBehavior:gravity];
        } else {
            UISnapBehavior *snap = [[UISnapBehavior alloc] initWithItem:gesture.view snapToPoint:startCenter];
            [self.animator addBehavior:snap];
        }
    }
}

- (CGFloat)angleOfView:(UIView *)view
{
    // http://stackoverflow.com/a/2051861/1271826
    
    return atan2(view.transform.b, view.transform.a);
}

- (void) show
{
    // Create a secondary window
    self.controllerWindow = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.controllerWindow.windowLevel = UIWindowLevelStatusBar;
    self.controllerWindow.hidden = NO;
    self.controllerWindow.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.7];
    // Make key and save the old one
    self.originalWindow = [[UIApplication sharedApplication] keyWindow];
    [self.controllerWindow makeKeyAndVisible];
    self.controllerWindow.rootViewController = self;
    
    // Animate
    self.view.alpha = 0;
    self.view.transform = CGAffineTransformMakeScale(2, 2);
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.view.transform = CGAffineTransformIdentity;
        self.view.alpha = 1;
    } completion:^(BOOL finished){
        // do something once the animation finishes, put it here
    }];
}

- (void) hide
{
    self.view.transform = CGAffineTransformIdentity;
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.view.transform = CGAffineTransformMakeScale(2, 2);
        self.view.alpha = 0;
    } completion:^(BOOL finished){
        self.view.hidden = YES;
        self.controllerWindow = Nil;
        [self.originalWindow makeKeyAndVisible];
    }];
}

@end
