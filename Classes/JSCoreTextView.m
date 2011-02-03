//
//  JSCoreTextView.m
//  CoreTextCells
//
//  Created by James Addyman on 16/12/2010.
//  Copyright 2010 JamSoft. All rights reserved.
//

#import "JSCoreTextView.h"
#import <CoreText/CoreText.h>
#import <QuartzCore/QuartzCore.h>
#import "AHHyperlinkScanner.h"

float const yAdjustmentFactor = 1.3;

@interface JSCoreTextView ()

- (void)createFramesetter;
- (void)drawInContext:(CGContextRef)ctx bounds:(CGRect)bounds;
- (CGPathRef)newPathForRoundedRect:(CGRect)rect radius:(CGFloat)radius;

@end

@implementation JSCoreTextView

@synthesize delegate = _delegate;

@synthesize text = _text; 
@synthesize textAlignment = _textAlignment;

@synthesize fontName = _fontName;
@synthesize fontSize = _fontSize;

@synthesize textColor = _textColor;
@synthesize linkColor = _linkColor;
@synthesize highlightedLinkColor = _highlightedLinkColor;
@synthesize highlightColor = _highlightColor;

@synthesize paddingTop = _paddingTop;
@synthesize paddingLeft = _paddingLeft;

@synthesize backgroundImage = _backgroundImage;
@synthesize bgImageTopStretchCap = _bgImageTopStretchCap;
@synthesize bgImageLeftStretchCap = _bgImageLeftStretchCap;

+ (CGFloat)measureFrameHeightForText:(NSString *)text 
							fontName:(NSString *)fontName 
							fontSize:(CGFloat)fontSize 
				  constrainedToWidth:(CGFloat)width 
						  paddingTop:(CGFloat)paddingTop 
						 paddingLeft:(CGFloat)paddingLeft
{
	if (![text length])
		return 0.0;
	
	CFMutableAttributedStringRef maString = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
	
	CFAttributedStringBeginEditing(maString);
	CFAttributedStringReplaceString(maString, CFRangeMake(0, 0), (CFStringRef)text);
	
	CTFontRef font = CTFontCreateWithName((CFStringRef)fontName, fontSize, NULL);
	
	CFAttributedStringSetAttribute(maString, CFRangeMake(0, CFAttributedStringGetLength(maString)), kCTFontAttributeName, font);
	
	CFAttributedStringEndEditing(maString);
	
	CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString(maString);
	
	CFRelease(font);
	
	CFRange fitRange = CFRangeMake(0,0);
	CGSize size = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, CFStringGetLength((CFStringRef)maString)), NULL, CGSizeMake(width,CGFLOAT_MAX), &fitRange);
	
	CFRelease(maString);
	CFRelease(framesetter);
	
	return size.height + paddingTop * 2;
}

#pragma mark -
#pragma mark Lifecycle

- (id)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame]))
	{
		_textAlignment = kCTLeftTextAlignment;
		_links = nil;
		
		self.backgroundImage = nil;
		self.bgImageTopStretchCap = 0.0;
		self.bgImageLeftStretchCap = 0.0;
		
		self.fontName = @"Helvetica";
		self.fontSize = 17.0;
		
		self.paddingTop = 0;
		self.paddingLeft = 0;
		
		self.textColor = [UIColor blackColor];
		self.linkColor = [UIColor blueColor];
		self.highlightedLinkColor = [UIColor blueColor];
		self.highlightColor = [UIColor grayColor];
	}
	
	return self;
}

- (void)dealloc
{
	self.text = nil;
	
	self.textColor = nil;
	self.linkColor = nil;
	self.highlightedLinkColor = nil;
	self.highlightColor = nil;
	
	self.backgroundImage = nil;
	
	[_links release], _links = nil;
	
	if (_framesetter)
	{
		CFRelease(_framesetter);
		_framesetter = NULL;
	}
	
	if (_frame)
	{
		CFRelease(_frame);
		_frame = NULL;
	}
	
	[super dealloc];
}

#pragma mark -
#pragma mark Properties

- (void)setText:(NSString *)text
{
	[_text release];
	_text = [text copy];
	
	[self detectLinks];
	
	[self setNeedsDisplay];
}

- (void)setTextAlignment:(CTTextAlignment)textAlignment
{
	_textAlignment = textAlignment;
	
	[self setNeedsDisplay];
}

- (void)setFontName:(NSString *)fontName
{
	[_fontName release];
	_fontName = [fontName copy];
	
	[self setNeedsDisplay];
}

- (void)setFontSize:(CGFloat)fontSize
{
	_fontSize = fontSize;
	
	[self setNeedsDisplay];
}

- (void)setPaddingTop:(CGFloat)paddingTop
{
	_paddingTop = paddingTop;
	
	[self setNeedsDisplay];
}

- (void)setPaddingLeft:(CGFloat)paddingLeft
{
	_paddingLeft = paddingLeft;
	
	[self setNeedsDisplay];
}

- (void)setBackgroundImage:(UIImage *)backgroundImage
{
	[_backgroundImage release];
	_backgroundImage = [backgroundImage retain];
	
	[self setNeedsDisplay];
}

- (void)setBgImageTopStretchCap:(CGFloat)topStretchCap
{
	_bgImageTopStretchCap = topStretchCap;
	
	[self setNeedsDisplay];
}

- (void)setBgImageLeftStretchCapLeft:(CGFloat)leftStretchCap
{
	_bgImageLeftStretchCap = leftStretchCap;
	
	[self setNeedsDisplay];	
}


- (void)setTextColor:(UIColor *)textColor
{
	[_textColor release];
	_textColor = [textColor retain];
	
	[self setNeedsDisplay];
}

- (void)setLinkColor:(UIColor *)linkColor
{
	[_linkColor release];
	_linkColor = [linkColor retain];
	
	[self setNeedsDisplay];
}

- (void)setHighlightedLinkColor:(UIColor *)highlightedLinkColor
{
	[_highlightedLinkColor release];
	_highlightedLinkColor = [highlightedLinkColor retain];
	
	[self setNeedsDisplay];
}

- (void)setHighlightColor:(UIColor *)highlightColor
{
	[_highlightColor release];
	_highlightColor = [highlightColor retain];
	
	[self setNeedsDisplay];
}

#pragma mark -
#pragma mark Link Detection

- (void)detectLinks
{
	if (_links)
	{
		[_links release];
	}
	
	AHHyperlinkScanner *scanner = [AHHyperlinkScanner hyperlinkScannerWithString:self.text];
	_links = [[scanner allURIs] copy];
}

#pragma mark -
#pragma mark Touch Handling

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	UITouch *touch = [touches anyObject];
	CGPoint location = [touch locationInView:self];
//	location.y += JSCoreTextView_y_adjustment;
//	location.y += self.paddingTop;
	location.y += (self.fontSize / yAdjustmentFactor);
	location.x -= self.paddingLeft;
	
	CFArrayRef lines = CTFrameGetLines(_frame);
	
	CGPoint origins[CFArrayGetCount(lines)];
	CTFrameGetLineOrigins(_frame, CFRangeMake(0, 0), origins);
	
	CTLineRef line = NULL;
	CGPoint lineOrigin = CGPointZero;
	for (int i= 0; i < CFArrayGetCount(lines); i++)
	{
		CGPoint origin = origins[i];
//		NSLog(@"Line %d origin: %@", i, NSStringFromCGPoint(origin));
		CGPathRef path = CTFrameGetPath(_frame);
		CGRect rect = CGPathGetBoundingBox(path);
		
		CGFloat y = rect.origin.y + rect.size.height - origin.y;

		if ((location.y >= y) && (location.x >= origin.x))
		{
			line = CFArrayGetValueAtIndex(lines, i);
			lineOrigin = origin;
		}
	}
	
	location.x -= lineOrigin.x;
	CFIndex index = CTLineGetStringIndexForPosition(line, location);
	
	for (AHMarkedHyperlink *link in _links)
	{
		if (((index >= [link range].location) && (index <= ([link range].length + [link range].location))))
		{
			_touchedLink = link;
			[self setNeedsDisplay];
		}
	}
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{	
	[super touchesMoved:touches withEvent:event];
	
	UITouch *touch = [touches anyObject];
	CGPoint location = [touch locationInView:self];	
	location.y += (self.fontSize / yAdjustmentFactor);
	location.x -= self.paddingLeft;
	
	CFArrayRef lines = CTFrameGetLines(_frame);
	
	CGPoint origins[CFArrayGetCount(lines)];
	CTFrameGetLineOrigins(_frame, CFRangeMake(0, 0), origins);
	
	CTLineRef line = NULL;
	CGPoint lineOrigin = CGPointZero;
	for (int i= 0; i < CFArrayGetCount(lines); i++)
	{
		CGPoint origin = origins[i];
		//		NSLog(@"Line %d origin: %@", i, NSStringFromCGPoint(origin));
		CGPathRef path = CTFrameGetPath(_frame);
		CGRect rect = CGPathGetBoundingBox(path);
		
		CGFloat y = rect.origin.y + rect.size.height - origin.y;
		
		if ((location.y >= y) && (location.x >= origin.x))
		{
			line = CFArrayGetValueAtIndex(lines, i);
			lineOrigin = origin;
		}
	}
	
	location.x -= lineOrigin.x;
	CFIndex index = CTLineGetStringIndexForPosition(line, location);
	
	_touchedLink = nil;
	
	for (AHMarkedHyperlink *link in _links)
	{
		if (((index >= [link range].location) && (index <= ([link range].length + [link range].location))))
		{
			_touchedLink = link;
		}
	}
	
	[self setNeedsDisplay];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	_touchedLink = nil;
	[self setNeedsDisplay];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{	
	if (_touchedLink)
	{
		if ([self.delegate respondsToSelector:@selector(textView:linkTapped:)])
		{
			[self.delegate textView:self linkTapped:[[_touchedLink retain] autorelease]];
		}
	}
	
	_touchedLink = nil;
	[self setNeedsDisplay];
}

#pragma mark -
#pragma mark Drawing / Layout

- (void)createFramesetter
{
	if (_framesetter)
	{
		CFRelease(_framesetter);
		_framesetter = NULL;
	}
	
	CFMutableAttributedStringRef maString = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);

	CFAttributedStringBeginEditing(maString);
	CFAttributedStringReplaceString(maString, CFRangeMake(0, 0), (CFStringRef)self.text);
	
	CFIndex length = CFAttributedStringGetLength(maString);
	
	CTFontRef font = CTFontCreateWithName((CFStringRef)self.fontName, self.fontSize, NULL);
	CFAttributedStringSetAttribute(maString, CFRangeMake(0, length), kCTFontAttributeName, font);
	CFAttributedStringSetAttribute(maString, CFRangeMake(0, length), kCTForegroundColorAttributeName, [self.textColor CGColor]);
	
	CTTextAlignment alignment = _textAlignment;
	CTParagraphStyleSetting _settings[] = {{kCTParagraphStyleSpecifierAlignment, sizeof(alignment), &alignment}};
	CTParagraphStyleRef paragraphStyle = CTParagraphStyleCreate(_settings, sizeof(_settings) / sizeof(_settings[0]));
	CFAttributedStringSetAttribute(maString, CFRangeMake(0, length), kCTParagraphStyleAttributeName, paragraphStyle);
	CFRelease(paragraphStyle);
	
	for (AHMarkedHyperlink *link in _links)
	{
		NSRange linkRange = [link range];
		CFRange range = CFRangeMake(linkRange.location, linkRange.length);
		
		if ([self.linkColor isEqual:self.textColor] == NO)
		{
			CFAttributedStringSetAttribute(maString, range, kCTForegroundColorAttributeName, [self.linkColor CGColor]);
		}
				
		if ([link isEqual:_touchedLink])
		{
			CFAttributedStringSetAttribute(maString, range, kCTForegroundColorAttributeName, [self.highlightedLinkColor CGColor]);
		}
	}
	
//	if (self.selected)
//	{
//		CFAttributedStringSetAttribute(maString, CFRangeMake(0, length), kCTForegroundColorAttributeName, [[UIColor whiteColor] CGColor]);
//	}
	
	CFAttributedStringEndEditing(maString);
	
	_framesetter = CTFramesetterCreateWithAttributedString(maString);
	
	CFRelease(maString);
	CFRelease(font);
}

- (void)drawInContext:(CGContextRef)ctx bounds:(CGRect)bounds
{	
	[self createFramesetter];
	
	CGRect frameRect = bounds;
	CGMutablePathRef path = NULL;
	
	frameRect.size.height = FLT_MAX;
	
	frameRect.size.height = [[self class] measureFrameHeightForText:self.text 
														   fontName:self.fontName 
														   fontSize:self.fontSize 
												 constrainedToWidth:frameRect.size.width 
														 paddingTop:self.paddingTop 
														paddingLeft:self.paddingLeft];
	
	frameRect.origin.y = CGRectGetMaxY(bounds) - frameRect.size.height;
	
	path = CGPathCreateMutable();
	CGPathAddRect(path, NULL, frameRect);
	
	if (_frame)
	{
		CFRelease(_frame);
		_frame = NULL;
	}
	
	_frame = CTFramesetterCreateFrame(_framesetter, CFRangeMake(0, 0), path, NULL);
	CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
	
	// highlight the link
	if (_touchedLink)
	{
		// get the lines
		CFArrayRef lines = CTFrameGetLines(_frame);
		
		// for each line
		for (int i = 0; i < CFArrayGetCount(lines); i++)
		{
			CTLineRef line = CFArrayGetValueAtIndex(lines, i);
			CFArrayRef runs = CTLineGetGlyphRuns(line);
			
			// fo each glyph run in the line
			for (int j = 0; j < CFArrayGetCount(runs); j++)
			{
				CTRunRef run = CFArrayGetValueAtIndex(runs, j);
				
				CFRange runRange = CTRunGetStringRange(run);
				
				// if the range of the glyph run falls within the range of the link to be highlighted
				if ((((runRange.location >= [_touchedLink range].location) && (runRange.location < [_touchedLink range].location + [_touchedLink range].length)) &&
					 ((runRange.location + runRange.length) <= ([_touchedLink range].location + [_touchedLink range].length))))
				{
					
					//NSLog(@"Link substring: : %@", [self.text substringWithRange:NSMakeRange(runRange.location, runRange.length)]);
					
					//runRange is within the link range
					
					CGRect runBounds = CGRectZero;
					
					// work out the bounding rect for the glyph run (this doesn't include the origin)
					CGFloat ascent, descent, leading;
					CGFloat width = CTRunGetTypographicBounds(run, CFRangeMake(0, 0), &ascent, &descent, &leading);
					runBounds.size.width = width;
					runBounds.size.height = ascent + fabsf(descent) + leading;
					
					// get the origin of the glyph run (this is relative to the origin of the line)
					const CGPoint *positions = CTRunGetPositionsPtr(run);
					//NSLog(@"positions: %@", NSStringFromCGPoint(positions[0]));
					
					// get the origins of the lines
					CGPoint lineOrigins[CFArrayGetCount(lines)];
					CTFrameGetLineOrigins(_frame, CFRangeMake(0, 0), lineOrigins);
					
					CGRect rect = CGPathGetBoundingBox(path);
					CGPoint origin = lineOrigins[i];
					//NSLog(@"Line Origin: %@", NSStringFromCGPoint(origin));
					
					// set the x position for the glyph run
					runBounds.origin.x += positions[0].x;
					if (_textAlignment == kCTRightTextAlignment)
					{
						runBounds.origin.x += origin.x;
					}
					
					runBounds.origin.x += self.paddingLeft;
					
					// flip the y coordinate from core text coordinate system to work in the native coordinate system (this always confuses the hell out of me)
					CGFloat y = rect.origin.y + rect.size.height - origin.y;
					//runBounds.origin.y += y - JSCoreTextView_y_adjustment;
					//runBounds.origin.y += y - self.paddingTop;
					runBounds.origin.y += y - (self.fontSize / yAdjustmentFactor);
					
					// adjust the rect to be slightly bigger than the text

//					runBounds.origin.x -= runBounds.size.width * 0.03;
//					runBounds.size.width += runBounds.size.width * 0.06;      // this works but gives rects that are too wide for longer lines and too much variation
//					runBounds.origin.y -= runBounds.size.height * 0.2;
//					runBounds.size.height += runBounds.size.height * 0.3;
					
					runBounds.origin.x -= self.fontSize / 4;
					runBounds.size.width += self.fontSize / 2;
					runBounds.origin.y -= self.fontSize / 8;                // this is more favourable
					runBounds.size.height += self.fontSize / 4;
					
					//NSLog(@"RunBounds: %@", NSStringFromCGRect(runBounds));
					
					// Finally, create a rounded rect with a nice shadow and fill.
					CGContextSetFillColorWithColor(ctx, [self.highlightColor CGColor]);
					CGPathRef highlightPath = [self newPathForRoundedRect:runBounds radius:(runBounds.size.height / 6)];
					CGContextSetShadow(ctx, CGSizeMake(2, 2), 1.0);
					CGContextAddPath(ctx, highlightPath);
					CGContextFillPath(ctx);
					CGPathRelease(highlightPath);
					CGContextSetShadowWithColor(ctx, CGSizeZero, 0.0, NULL); // turn off shadowing
				}
			}
		}
		
	}
	
	// flip the coordinate system so that core text doesn't plough forward and draw the text upside down
	CGContextTranslateCTM(ctx, 0.0, bounds.size.height);
	CGContextScaleCTM(ctx, 1.0, -1.0);
	
	// draw the CTFrame
	CTFrameDraw(_frame, ctx);
	
	CGPathRelease(path);
}

- (void)drawRect:(CGRect)rect
{
	CGRect bounds = self.bounds;
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	
	CGContextSetRGBFillColor(ctx, 1.0, 1.0, 1.0, 1.0);
	CGContextFillRect(ctx, bounds);
	
	if (self.backgroundImage)
	{
		UIImage *bg = self.backgroundImage;
		
		if (self.bgImageTopStretchCap > 0 || self.bgImageLeftStretchCap > 0)
		{
			bg = [self.backgroundImage stretchableImageWithLeftCapWidth:self.bgImageLeftStretchCap topCapHeight:self.bgImageTopStretchCap];
		}
		
		[bg drawInRect:rect]; // Using 'bounds' here causes the bubble to be drawn with a white line near the stretching point.
		                      // Using 'rect' fixes it... no idea why.
	}
	
	bounds.size.width -= self.paddingLeft * 2;
	bounds.origin.x += self.paddingLeft;
	bounds.size.height += self.paddingTop * 2;
	bounds.origin.y -= self.paddingTop;
	
	[self drawInContext:ctx bounds:bounds];
}

- (CGPathRef)newPathForRoundedRect:(CGRect)rect radius:(CGFloat)radius
{
	CGMutablePathRef retPath = CGPathCreateMutable();
	
	CGRect innerRect = CGRectInset(rect, radius, radius);
	
	CGFloat inside_right = innerRect.origin.x + innerRect.size.width;
	CGFloat outside_right = rect.origin.x + rect.size.width;
	CGFloat inside_bottom = innerRect.origin.y + innerRect.size.height;
	CGFloat outside_bottom = rect.origin.y + rect.size.height;
	
	CGFloat inside_top = innerRect.origin.y;
	CGFloat outside_top = rect.origin.y;
	CGFloat outside_left = rect.origin.x;
	
	CGPathMoveToPoint(retPath, NULL, innerRect.origin.x, outside_top);
	
	CGPathAddLineToPoint(retPath, NULL, inside_right, outside_top);
	CGPathAddArcToPoint(retPath, NULL, outside_right, outside_top, outside_right, inside_top, radius);
	CGPathAddLineToPoint(retPath, NULL, outside_right, inside_bottom);
	CGPathAddArcToPoint(retPath, NULL,  outside_right, outside_bottom, inside_right, outside_bottom, radius);
	
	CGPathAddLineToPoint(retPath, NULL, innerRect.origin.x, outside_bottom);
	CGPathAddArcToPoint(retPath, NULL,  outside_left, outside_bottom, outside_left, inside_bottom, radius);
	CGPathAddLineToPoint(retPath, NULL, outside_left, inside_top);
	CGPathAddArcToPoint(retPath, NULL,  outside_left, outside_top, innerRect.origin.x, outside_top, radius);
	
	CGPathCloseSubpath(retPath);
	
	return retPath;
}

@end
