//
//  GrainBirds.m
//  ExampleProject
//
//  Created by Adam Boulanger on 6/21/12.
//  Copyright (c) 2012 Hear For Yourself. All rights reserved.
//

#import "GrainBirds.h"
#import "OCSGrain.h"
#import "OCSAudio.h"

@implementation GrainBirds
@synthesize grainDensity;
@synthesize grainDuration;
@synthesize pitchClass;
@synthesize pitchOffsetStartValue;
@synthesize pitchOffsetFirstTarget;
@synthesize reverbSend;
@synthesize auxilliaryOutput;

- (id)init
{
    self = [super init];
    if (self) {
        // INPUTS AND CONTROLS =================================================
        
        grainDensity            = [[OCSProperty alloc] init];
        grainDuration           = [[OCSProperty alloc] init];
        pitchClass              = [[OCSProperty alloc] init];
        pitchOffsetStartValue   = [[OCSProperty alloc] init];
        pitchOffsetFirstTarget  = [[OCSProperty alloc] init];
        reverbSend              = [[OCSProperty alloc] init];
        
        [grainDensity           setControl: [OCSParamControl  paramWithString:@"GrainDensity"]]; 
        [grainDuration          setControl: [OCSParamControl  paramWithString:@"GrainDuration"]];
        [pitchClass             setControl: [OCSParamControl  paramWithString:@"PitchClass"]]; 
        [pitchOffsetStartValue  setConstant:[OCSParamConstant paramWithString:@"PitchOffsetStartValue"]]; 
        [pitchOffsetFirstTarget setConstant:[OCSParamConstant paramWithString:@"PitchOffsetFirstTarget"]]; 
        [reverbSend             setConstant:[OCSParamConstant paramWithString:@"ReverbSend"]];
        
        [self addProperty:grainDensity];
        [self addProperty:grainDuration];
        [self addProperty:pitchClass];
        [self addProperty:pitchOffsetStartValue];
        [self addProperty:pitchOffsetFirstTarget];
        [self addProperty:reverbSend];
        
        // FUNCTIONS ===========================================================

        NSString * file = [[NSBundle mainBundle] pathForResource:@"a50" ofType:@"aif"];
        OCSSoundFileTable *fiftyHzSine = [[OCSSoundFileTable alloc] initWithFilename:file];
        [self addFunctionTable:fiftyHzSine];
        
        OCSWindowsTable *hanning = [[OCSWindowsTable alloc] initWithSize:4097 WindowType:kWindowHanning];
        [self addFunctionTable:hanning];
        
        // INSTRUMENT DEFINITION ===============================================
        
        // Useful times
        OCSParamConstant * tenthOfDuration = [OCSParamConstant paramWithFormat:@"%@ * 0.1", duration];
        OCSParamConstant * halfOfDuration  = [OCSParamConstant paramWithFormat:@"%@ * 0.5", duration];
        OCSParamConstant * sixthOfDuration = [OCSParamConstant paramWithFormat:@"%@ * 0.6", duration];
        
        
        OCSParamArray * amplitudeBreakpoints = [OCSParamArray paramArrayFromParams:sixthOfDuration, ocsp(6000), nil];

        OCSLineSegmentWithRelease * amplitude = 
        [[OCSLineSegmentWithRelease alloc] initWithFirstSegmentStartValue:ocsp(0.00001f)
                                                  FirstSegmentTargetValue:ocsp(3000)
                                                     FirstSegmentDuration:tenthOfDuration
                                                       DurationValuePairs:amplitudeBreakpoints 
                                                          ReleaseDuration:tenthOfDuration
                                                               FinalValue:ocsp(0)];
        [self addOpcode:amplitude];
        
        OCSPitchClassToFreq * cpspch = [[OCSPitchClassToFreq alloc] initWithPitch:[pitchClass control]];
        [self addOpcode:cpspch];
        
        OCSParamArray *pitchOffsetBreakpoints = [OCSParamArray paramArrayFromParams:
                                                 [OCSParamConstant paramWithFormat:@"%@ * 0.45", duration], 
                                                 ocsp(40), nil];
                                                  
        OCSLineSegmentWithRelease *pitchOffset;
        pitchOffset = [[OCSLineSegmentWithRelease alloc] initWithFirstSegmentStartValue:[pitchOffsetStartValue constant] 
                                                                FirstSegmentTargetValue:[pitchOffsetFirstTarget constant] 
                                                                   FirstSegmentDuration:halfOfDuration
                                                                     DurationValuePairs:pitchOffsetBreakpoints 
                                                                        ReleaseDuration:tenthOfDuration
                                                                             FinalValue:ocsp(0)];
        [self addOpcode:pitchOffset];         
        
        OCSGrain *grain = [[OCSGrain alloc] initWithGrainFunction:fiftyHzSine  
                                                   WindowFunction:hanning 
                                                 MaxGrainDuration:ocsp(0.1)
                                                        Amplitude:[amplitude output] 
                                                       GrainPitch:[cpspch output] 
                                                     GrainDensity:[grainDensity control] 
                                                    GrainDuration:[grainDuration control] 
                                            MaxAmplitudeDeviation:ocsp(1000)
                                                MaxPitchDeviation:[pitchOffset output]];
        [self addOpcode:grain];
        
        OCSFilterLowPassButterworth *butterlp = [[OCSFilterLowPassButterworth alloc] initWithInput:[grain output] 
                                                                                   CutoffFrequency:ocsp(500)];
        [self addOpcode:butterlp];
        
        // AUDIO OUTPUT ========================================================
        
        OCSAudio *stereoOutput = [[OCSAudio alloc] initWithMonoInput:[butterlp output]];
        [self addOpcode:stereoOutput];
        
        // EXTERNAL OUTPUTS ====================================================        
        // After your instrument is set up, define outputs available to others
        auxilliaryOutput = [OCSParam paramWithString:@"ToReverb"];
        [self assignOutput:auxilliaryOutput To:[OCSParam paramWithFormat:@"%@ + (%@ * %@)",
         auxilliaryOutput, [butterlp output], [reverbSend constant]]];
        
    }
    return self;
}

@end
