//
//  DTCoreTextLayoutFrame.m
//  CoreTextExtensions
//
//  Created by Oliver Drobnik on 1/24/11.
//  Copyright 2011 Drobnik.com. All rights reserved.
//

#import "DTCoreTextLayoutFrame.h"
#import "DTCoreTextLayouter.h"
#import "DTCoreTextLayoutLine.h"

#import "DTTextAttachment.h"

@interface DTCoreTextLayoutFrame ()

@property (nonatomic, retain) NSArray *lines;

@end


static BOOL _DTCoreTextLayoutFramesShouldDrawDebugFrames = NO;


@implementation DTCoreTextLayoutFrame

+ (void)setShouldDrawDebugFrames:(BOOL)debugFrames
{
    _DTCoreTextLayoutFramesShouldDrawDebugFrames = debugFrames;
}

// makes a frame for a specific part of the attributed string of the layouter
- (id)initWithFrame:(CGRect)frame layouter:(DTCoreTextLayouter *)layouter range:(NSRange)range
{
    self = [super init];
    
	if (self)
	{
		_frame = frame;
		
		_layouter = [layouter retain];
		
		CGMutablePathRef path = CGPathCreateMutable();
		CGPathAddRect(path, NULL, frame);
		
		CFRange cfRange = CFRangeMake(range.location, range.length);
        _framesetter = layouter.framesetter;
        CFRetain(_framesetter);
        
        if (_framesetter)
        {
            _textFrame = CTFramesetterCreateFrame(_framesetter, cfRange, path, NULL);
        }
        else
        {
            NSLog(@"Strange, should have gotten a valid framesetter");
        }
            
		CGPathRelease(path);
	}
	
	return self;
}

// makes a frame for the entire attributed string of the layouter
- (id)initWithFrame:(CGRect)frame layouter:(DTCoreTextLayouter *)layouter
{
	return [self initWithFrame:frame layouter:layouter range:NSMakeRange(0, 0)];
}

- (void)dealloc
{
	if (_textFrame)
	{
		CFRelease(_textFrame);
        _textFrame = NULL;
	}
	[_lines release];
    [_layouter release];
    
    if (_framesetter)
    {
        CFRelease(_framesetter);
        _framesetter = NULL;
    }
	
	[super dealloc];
}

- (NSString *)description
{
	return [self.lines description];
}

- (NSArray *)lines
{
	if (!_lines)
	{
		// get lines
		CFArrayRef lines = CTFrameGetLines(_textFrame);
		
		if (!lines)
		{
			// probably no string set
			return nil;
		}
		
		CGPoint *origins = malloc(sizeof(CGPoint)*[(NSArray *)lines count]);
		CTFrameGetLineOrigins(_textFrame, CFRangeMake(0, 0), origins);
		
		NSMutableArray *tmpLines = [[NSMutableArray alloc] initWithCapacity:CFArrayGetCount(lines)];;
		
		NSInteger lineIndex = 0;
		
		for (id oneLine in (NSArray *)lines)
		{
			CGPoint lineOrigin = origins[lineIndex];
			lineOrigin.y = _frame.size.height - lineOrigin.y + self.frame.origin.y;
			lineOrigin.x += self.frame.origin.x;

			DTCoreTextLayoutLine *newLine = [[DTCoreTextLayoutLine alloc] initWithLine:(CTLineRef)oneLine layoutFrame:self origin:lineOrigin];
			[tmpLines addObject:newLine];
			[newLine release];
			
			lineIndex++;
		}
		
		_lines = tmpLines;
		
		free(origins);
	}
	
	return _lines;
}

- (CGPathRef)path
{
	return CTFrameGetPath(_textFrame);
}

- (void)drawInContext:(CGContextRef)context
{
    CGRect rect = CGContextGetClipBoundingBox(context);
    
	if (!_textFrame || !context)
	{
		return;
	}
	
    CFRetain(_textFrame);
	//CTFrameDraw(_textFrame, context);
    
    UIGraphicsPushContext(context);
    
    [self retain];
    [_layouter retain];
    
	//CGContextRef context = UIGraphicsGetCurrentContext();
	
	// TODO: do all these settings make sense?
    //	CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    //	CGContextSetAllowsAntialiasing(context, YES);
    //	CGContextSetShouldAntialias(context, YES);
    //	
    //	CGContextSetAllowsFontSubpixelQuantization(context, YES);
    //	CGContextSetShouldSubpixelQuantizeFonts(context, YES);
    //	
    //	CGContextSetShouldSmoothFonts(context, YES);
    //	CGContextSetAllowsFontSmoothing(context, YES);
    //	
    //	CGContextSetShouldSubpixelPositionFonts(context,YES);
    //	CGContextSetAllowsFontSubpixelPositioning(context, YES);
	
	
	if (_DTCoreTextLayoutFramesShouldDrawDebugFrames)
	{
		CGFloat dashes[] = {10.0, 2.0};
		CGContextSetLineDash(context, 0, dashes, 2);
		
		CGPathRef framePath = [self path];
		CGContextAddPath(context, framePath);
		CGContextStrokePath(context);
	}
	
	for (DTCoreTextLayoutLine *oneLine in self.lines)
	{
        [oneLine retain];
        
        if (CGRectIntersectsRect(rect, oneLine.frame))
        {
            if (_DTCoreTextLayoutFramesShouldDrawDebugFrames)
            {
                [[UIColor blueColor] set];
                
                CGContextSetLineDash(context, 0, NULL, 0);
                CGContextStrokeRect(context, oneLine.frame);
                
                CGContextMoveToPoint(context, oneLine.baselineOrigin.x-5.0, oneLine.baselineOrigin.y);
                CGContextAddLineToPoint(context, oneLine.baselineOrigin.x + oneLine.frame.size.width + 5.0, oneLine.baselineOrigin.y);
                CGContextStrokePath(context);
                
                CGContextSetRGBFillColor(context, 0, 0, 1, 0.1);
                
            }
            
            NSInteger runIndex = 0;
            
            for (DTCoreTextGlyphRun *oneRun in oneLine.glyphRuns)
            {
                [oneRun retain];
                
                if (_DTCoreTextLayoutFramesShouldDrawDebugFrames)
                {
                    if (runIndex%2)
                    {
                        CGContextSetRGBFillColor(context, 1, 0, 0, 0.2);
                    }
                    else 
                    {
                        CGContextSetRGBFillColor(context, 0, 1, 0, 0.2);
                    }
                    
                    CGContextFillRect(context, oneRun.frame);
                    runIndex ++;
                }
                
                
                // -------------- Draw Embedded Images
                DTTextAttachment *attachment = [oneRun.attributes objectForKey:@"DTTextAttachment"];
                
                if (attachment)
                {
                    if ([attachment.contents isKindOfClass:[UIImage class]])
                    {
                        UIImage *image = (id)attachment.contents;
                        
                        CGRect imageBounds = CGRectMake(roundf(oneRun.frame.origin.x), roundf(oneRun.baselineOrigin.y - attachment.size.height), 
                                                        attachment.size.width, attachment.size.height);
                        
                        
                        [image drawInRect:imageBounds];
                    }
                }
                
                
                // -------------- Line-Out
                
                CGRect runImageBounds = [oneRun imageBoundsInContext:context];
                
                // whitespace glyph at EOL has zero width, we don't want to stroke that
                if (runImageBounds.size.width>0)
                {
                    if ([[oneRun.attributes objectForKey:@"_StrikeOut"] boolValue])
                    {
                        CGRect runStrokeBounds = oneRun.frame;
                        
                        runStrokeBounds.origin.y += roundf(oneRun.frame.size.height/2.0);
                        
                        // get text color or use black
                        id color = [oneRun.attributes objectForKey:(id)kCTForegroundColorAttributeName];
                        
                        if (color)
                        {
                            CGContextSetStrokeColorWithColor(context, (CGColorRef)color);
                        }
                        else
                        {
                            CGContextSetGrayStrokeColor(context, 0, 1.0);
                        }
                        
                        CGContextSetLineDash(context, 0, NULL, 0);
                        CGContextSetLineWidth(context, 1);
                        
                        CGContextMoveToPoint(context, runStrokeBounds.origin.x, runStrokeBounds.origin.y);
                        CGContextAddLineToPoint(context, runStrokeBounds.origin.x + runStrokeBounds.size.width, runStrokeBounds.origin.y);
                        
                        CGContextStrokePath(context);
                    }
                }
                [oneRun release];
            }
        }
        
        [oneLine release];
	}
	
	// Flip the coordinate system
	CGContextSetTextMatrix(context, CGAffineTransformIdentity);
	CGContextScaleCTM(context, 1.0, -1.0);
	CGContextTranslateCTM(context, 0, -self.frame.size.height);
    
	// instead of using the convenience method to draw the entire frame, we draw individual glyph runs
    
    BOOL earlyBreakArmed = NO; 
    
	for (DTCoreTextLayoutLine *oneLine in self.lines)
	{
        if (CGRectIntersectsRect(rect, oneLine.frame))
        {
            for (DTCoreTextGlyphRun *oneRun in oneLine.glyphRuns)
            {
                earlyBreakArmed = YES;
                
                CGContextSaveGState(context);
                
                CGContextSetTextPosition(context, oneLine.frame.origin.x, self.frame.size.height - oneRun.frame.origin.y - oneRun.ascent);
                
                
                NSArray *shadows = [oneRun.attributes objectForKey:@"_Shadows"];
                
                if (shadows)
                {
                    for (NSDictionary *shadowDict in shadows)
                    {
                        UIColor *color = [shadowDict objectForKey:@"Color"];
                        CGSize offset = [[shadowDict objectForKey:@"Offset"] CGSizeValue];
                        CGFloat blur = [[shadowDict objectForKey:@"Blur"] floatValue];
                        
                        CGFloat scaleFactor = 1.0;
                        if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)])
                        {
                            scaleFactor = [[UIScreen mainScreen] scale];
                        }
                        
                        
                        // workaround for scale 1: strangely offset (1,1) with blur 0 does not draw any shadow, (1.01,1.01) does
                        if (scaleFactor==1.0)
                        {
                            if (fabs(offset.width)==1.0)
                            {
                                offset.width *= 1.50;
                            }
                            
                            if (fabs(offset.height)==1.0)
                            {
                                offset.height *= 1.50;
                            }
                        }
                        
                        CGContextSetShadowWithColor(context, offset, blur, color.CGColor);
                        
                        // draw once per shadow
                        [oneRun drawInContext:context];
                        
                    }
                }
                else
                {
                    [oneRun drawInContext:context];
                }
                
                CGContextRestoreGState(context);
                
            }
		}
        else
        {
            if (earlyBreakArmed)
            {
                break;
            }
        }
	}
	
    UIGraphicsPopContext();
    [self release];
    [_layouter release];

    if (_textFrame)
    {
        CFRelease(_textFrame);
    }
}

- (NSRange)visibleStringRange
{
	CFRange range = CTFrameGetVisibleStringRange(_textFrame);
	
	return NSMakeRange(range.location, range.length);
}


#pragma mark Calculations
- (NSInteger)lineIndexForGlyphIndex:(NSInteger)index
{
	NSInteger retIndex = 0;
	for (DTCoreTextLayoutLine *oneLine in self.lines)
	{
		NSInteger count = [oneLine numberOfGlyphs];
		if (index >= count)
		{
			index -= count;
		}
		else 
		{
			return retIndex;
		}
		
		retIndex++;
	}
	
	return retIndex; //NSIntegerMax;
}

- (CGRect)frameOfGlyphAtIndex:(NSInteger)index
{
	for (DTCoreTextLayoutLine *oneLine in self.lines)
	{
		NSInteger count = [oneLine numberOfGlyphs];
		if (index >= count)
		{
			index -= count;
		}
		else 
		{
			return [oneLine frameOfGlyphAtIndex:index];
		}
	}
	
	return CGRectZero;
}

#pragma mark Properties
@synthesize frame = _frame;
@synthesize layouter = _layouter;
@synthesize lines = _lines;
@synthesize tag;

@end
