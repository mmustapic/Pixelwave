/*
 *  _____                       ___                                            
 * /\  _ `\  __                /\_ \                                           
 * \ \ \L\ \/\_\   __  _    ___\//\ \    __  __  __    ___     __  __    ___   
 *  \ \  __/\/\ \ /\ \/ \  / __`\\ \ \  /\ \/\ \/\ \  / __`\  /\ \/\ \  / __`\ 
 *   \ \ \/  \ \ \\/>  </ /\  __/ \_\ \_\ \ \_/ \_/ \/\ \L\ \_\ \ \_/ |/\  __/ 
 *    \ \_\   \ \_\/\_/\_\\ \____\/\____\\ \___^___ /\ \__/|\_\\ \___/ \ \____\
 *     \/_/    \/_/\//\/_/ \/____/\/____/ \/__//__ /  \/__/\/_/ \/__/   \/____/
 *       
 *           www.pixelwave.org + www.spiralstormgames.com
 *                            ~;   
 *                           ,/|\.           
 *                         ,/  |\ \.                 Core Team: Oz Michaeli
 *                       ,/    | |  \                           John Lattin
 *                     ,/      | |   |
 *                   ,/        |/    |
 *                 ./__________|----'  .
 *            ,(   ___.....-,~-''-----/   ,(            ,~            ,(        
 * _.-~-.,.-'`  `_.\,.',.-'`  )_.-~-./.-'`  `_._,.',.-'`  )_.-~-.,.-'`  `_._._,.
 * 
 * Copyright (c) 2011 Spiralstorm Games http://www.spiralstormgames.com
 * 
 * This software is provided 'as-is', without any express or implied
 * warranty. In no event will the authors be held liable for any damages
 * arising from the use of this software.
 * 
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */

#import "Slider.h"
#import "PXMathUtils.h"

@interface Slider(Private)
- (void) updateSlider;

- (void) setHighlighted:(BOOL)highlighted;

- (void) onSliderPress:(PXTouchEvent *)event;
- (void) onSliderRelease:(PXTouchEvent *)event;
- (void) onSliderMove:(PXTouchEvent *)event;
@end

// This is a reusable slider component. It's built to behave correctly in a 
// multi-touch environment, and can be visually transformed without interaction
// issues.
// It's capable of having an arbitrary visual length and uses the delegate
// design pattern for interacting with its container.
// We decided on a delegate pattern over event dispatching because the slider
// doesn't require a one-to-many event model used by event dispatching, and
// the simpler one-to-one model used by delegates suffices
// (at least for the purposes of this demo). The event dispatching method can
// be easily changed if needed.

@implementation Slider

@synthesize length = barLength, value;
@synthesize delegate, selected;

// Since the slider must have a skin to function, we override the default
// init method to notify the user of this requirement.
- (id) init
{
	NSLog(@"Slider must be created using initWithSkin:");
	[self release];
	return nil;
}

- (id) initWithSkin:(PXTextureData *)skin
{
	if (!skin)
	{
		NSLog(@"Parameter 'skin' must be non-nil");
		[self release];
		return nil;
	}

	self = [super init];

	if (self)
	{
		delegate = nil;
		currentTouch = nil;

		// Create the parts of the slider bar. The bar is made of two end caps
		// and a body. The end caps are always the same size, while the body's
		// width can change

		barLeftCap = [PXTexture textureWithTextureData:skin];
		[self addChild:barLeftCap];

		barBody = [PXTexture textureWithTextureData:skin];
		[self addChild:barBody];

		barRightCap = [PXTexture textureWithTextureData:skin];
		[self addChild:barRightCap];
		barRightCap.scaleX = -1.0f;

		// Create the button that will actually slide around.
		// Note:	That we can't just use the sliderButtonTexture as the button
		//			because PXTextures can't handle touch events (as they don't
		//			extend PXInteractiveObject), but sprites sure can.

		sliderButtonTexture = [PXTexture textureWithTextureData:skin];
		sliderSprite = [PXSimpleSprite simpleSpriteWithChild:sliderButtonTexture];
		[self addChild:sliderSprite];

		// Uncomment these lines to smooth the textures (useful for rotations
		// and scaling)
		//BOOL smoothing = YES;
		//barLeftCap.smoothing = smoothing;
		//barRightCap.smoothing = smoothing;
		//barBody.smoothing = smoothing;
		//sliderButtonTexture.smoothing = smoothing;

		// Set up the touch event listeners

		[sliderSprite addEventListenerOfType:PXTouchEvent_TouchDown listener:PXListener(onSliderPress:)];
		[sliderSprite addEventListenerOfType:PXTouchEvent_TouchMove	listener:PXListener(onSliderMove:)];
		[sliderSprite addEventListenerOfType:PXTouchEvent_TouchUp listener:PXListener(onSliderRelease:)];
		[sliderSprite addEventListenerOfType:PXTouchEvent_TouchCancel listener:PXListener(onSliderRelease:)];

		// Set up the default slider values
		[self setHighlighted:NO];
		value = 0.0f;
		self.length = 100.0f;
	}

	return self;
}

- (void) dealloc
{
	// We must remove all the event listeners on deallocation to prevent nasty
	// crashes. These crashes could occur if an event gets triggered on a
	// listener that wasn't removed before being deallocated (also known as a
	// "Zombie Listener" .. ooooohhahaha).

	[sliderSprite removeEventListenerOfType:PXTouchEvent_TouchDown listener:PXListener(onSliderPress:)];
	[sliderSprite removeEventListenerOfType:PXTouchEvent_TouchMove	listener:PXListener(onSliderMove:)];
	[sliderSprite removeEventListenerOfType:PXTouchEvent_TouchUp listener:PXListener(onSliderRelease:)];
	[sliderSprite removeEventListenerOfType:PXTouchEvent_TouchCancel listener:PXListener(onSliderRelease:)];

	// Usual cleaning up operations
	currentTouch = nil;

	[super dealloc];
}

/////////////
// Setters //
/////////////

- (void) setValue:(float)val
{
	// Clamp the value passed in to something between 0.0 and 1.0
	if(val < 0.0f)
		val = 0.0f;
	if(val > 1.0f)
		val = 1.0f;

	value = val;

	// Update the graphical representation of the slider
	[self updateSlider];
}

// Sets the visual length of the slider bar
- (void) setLength:(float)val
{
	barLength = val;

	float capWidth = barLeftCap.width;
	float realLen = PXMathMax(capWidth * 2.0 + 1.0, barLength);
	float barBodyWidth = realLen - capWidth*2.0f;

	barLeftCap.x = 0.0f;
	barLeftCap.y = 0.0f;

	barBody.x = barLeftCap.x + capWidth;
	barBody.y = barLeftCap.y;

	barBody.width = barBodyWidth;

	barRightCap.x = barBody.x + barBodyWidth;
	barRightCap.y = 0.0f;

	// Update the position of the button along the bar
	[self updateSlider];
}

// Override
// Makes sure that the button is always facing the right way
- (void) setRotation:(float)val
{
	super.rotation = val;

	sliderSprite.rotation = -val;
}

///////////////////////
// 'Private' Methods //
///////////////////////

// Positions the slider button in the correct visual position along the bar
- (void) updateSlider
{
	float percent = value;

	float startX = barBody.x;
	float endX = barBody.x + barBody.width;

	sliderSprite.y = 4.5f;
	sliderSprite.x = PXMathLerpf(startX, endX, percent);
}

// Tells all the textures which coordinates to use from the skin texture
// depending on whether the slider needs to be highlighted or not
- (void) setHighlighted:(BOOL)highlighted
{
	selected = highlighted;

	if (!highlighted)
	{
		// Set up the texture coordinates to use the gray color scheme
		[barLeftCap setClipRectWithX:24 y:4 width:5 height:8];
		[barRightCap setClipRectWithX:24 y:4 width:5 height:8];
		[barRightCap setAnchorWithX:1.0f y:0.0f];
		[barBody setClipRectWithX:35 y:4 width:4 height:8];
		[sliderButtonTexture setClipRectWithX:48 y:9 width:42 height:42];
		[sliderButtonTexture setAnchorWithPointX:17.5f pointY:17.5f];
		sliderSprite.alpha = 1.0f;
	}
	else
	{
		// Set up the texture coordinates to use the blue color scheme
		[barLeftCap setClipRectWithX:4 y:4 width:5 height:8];
		[barRightCap setClipRectWithX:4 y:4 width:5 height:8];
		[barRightCap setAnchorWithX:1.0f y:0.0f];
		[barBody setClipRectWithX:15 y:4 width:4 height:8];
		[sliderButtonTexture setClipRectWithX:4 y:17 width:42 height:42];
		[sliderButtonTexture setAnchorWithPointX:17.6 pointY:17.5];
		sliderSprite.alpha = 0.5f;
	}
}

/////////////////////
// Event Listeners //
/////////////////////

// Once the slider button gets pressed, this function is called.
- (void) onSliderPress:(PXTouchEvent *)event
{
	// If this slider is already being dragged, ignore the touch
	if (currentTouch)
		return;

	currentTouch = event.nativeTouch;

	// Make the slider blue
	[self setHighlighted:YES];
	// Tell my delegate that the user started dragging the slider
	[delegate sliderDidBeginDrag:self];
}

// This event will only be dispatched while a finger is moving anywhere on the
// stage after the slider button was pressed, but before it was released
- (void) onSliderMove:(PXTouchEvent *)event
{
	// Only move the slider if the touch that initiated the drag was moving
	if (event.nativeTouch != currentTouch)
		return;

	// Calculate the new value of the slider given the position of the touch.
	// We convert the touch's coordinates into local space first. This is what
	// allows the bar to be rotated and skewed with no interactivity issues
	PXPoint *globalPos = [PXPoint pointWithX:event.stageX y:event.stageY];
	PXPoint *localPos = [self globalToLocal:globalPos];

	self.value = (localPos.x - barBody.x) / barBody.width;

	// Tell our delegate that the slider has been moved
	[delegate slider:self didChangeValue:value];
}

// This event will only get dispatched when a touch was released after the
// sliding began. We then check to see if the touch is the same one that started
// the dragging. If so we proceed.
- (void) onSliderRelease:(PXTouchEvent *)event
{
	// Only stop sliding if the touch that initiated the drag was released
	if (event.nativeTouch != currentTouch)
		return;

	currentTouch = nil;
	
	[self setHighlighted:NO];
	[delegate sliderDidEndDrag:self];
}

/////////////////////
// Utility Methods //
/////////////////////

// Just a utility method to quickly create a skinned slider
+ (Slider *)sliderWithSkin:(PXTextureData *)skin
{
	return [[[Slider alloc] initWithSkin:skin] autorelease];
}

@end
