// Written in the D programming language.

/**
    This module implements an RGB _color type.

    Authors:    Manu Evans
    Copyright:  Copyright (c) 2015, Manu Evans.
    License:    $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Source:     $(PHOBOSSRC std/experimental/color/package.d)
*/
module std.experimental.color.rgb;

import std.experimental.color;
import std.experimental.color.conv: convertColor;

import std.traits: isInstanceOf, isNumeric, isIntegral, isFloatingPoint, isSigned, isSomeChar, Unqual;
import std.typetuple: TypeTuple;
import std.typecons: tuple;

@safe: pure: nothrow: @nogc:

enum isValidComponentType(T) = isIntegral!T || isFloatingPoint!T;


/**
Detect whether $(D T) is an RGB color.
*/
enum isRGB(T) = isInstanceOf!(RGB, T);


// DEBATE: which should it be?
template defaultAlpha(T)
{
/+
    enum defaultAlpha = isFloatingPoint!T ? T(1) : T.max;
+/
    enum defaultAlpha = T(0);
}


/**
Enum of RGB color spaces.
*/
enum RGBColorSpace
{
    /** sRGB, HDTV (ITU-R BT.709) */
    sRGB,
    /** sRGB with gamma 2.2 */
    sRGB_Gamma2_2,

/+ TODO: these all need testing
    AdobeRGB,
    AppleRGB,
    BestRGB,
    BetaRGB,
    BruceRGB,
    CIE_RGB,
    ColorMatchRGB,
    DonRGB4,
//    ECI_RGB_v2,
    EktaSpacePS5,
    NTSC_RGB,
    PAL_SECAM_RGB,
    ProPhotoRGB,
    SMPTE_C_RGB,
    WideGamutRGB
+/

    // custom color space will disable automatic color spoace conversions
    custom = -1
}


/**
An RGB color, parameterised with components, component type, and colour space specification.

Params: components_ = Components that shall be available. Struct is populated with components in the order specified.
                      Valid components are:
                        "r" = red
                        "g" = green
                        "b" = blue
                        "a" = alpha
                        "l" = luminance
                        "x" = placeholder/padding (no significant value)
        ComponentType_ = Type for the color channels. May be a basic integer or floating point type.
        linear_ = Color is stored with linear luminance.
        colorSpace_ = Color will be within the specified color space.
*/
struct RGB(string components_, ComponentType_, bool linear_ = false, RGBColorSpace colorSpace_ = RGBColorSpace.sRGB) if(isValidComponentType!ComponentType_)
{
@safe: pure: nothrow: @nogc:

    // RGB colors may only contain components 'rgb', or 'l' (luminance)
    // They may also optionally contain an 'a' (alpha) component, and 'x' (unused) components
    static assert(allIn!("rgblax", components), "Invalid Color component '"d ~ notIn!("rgblax", components) ~ "'. RGB colors may only contain components: r, g, b, l, a, x"d);
    static assert(anyIn!("rgbal", components), "RGB colors must contain at least one component of r, g, b, l, a.");
    static assert(!canFind!(components, 'l') || !anyIn!("rgb", components), "RGB colors may not contain rgb AND luminance components together.");

    // create members for some useful information
    /** Type of the color components. */
    alias ComponentType = ComponentType_;
    /** The color components that were specified. */
    enum string components = components_;
    /** The color space specified. */
    enum RGBColorSpace colorSpace = colorSpace_;
    /** If the color is stored linearly (without gamma applied). */
    enum bool linear = linear_;


    // mixin will emit members for components
    template Components(string components)
    {
        static if(components.length == 0)
            enum Components = "";
        else
            enum Components = ComponentType.stringof ~ ' ' ~ components[0] ~ " = 0;\n" ~ Components!(components[1..$]);
    }
    mixin(Components!components);

    /** Test if a particular component is present. */
    enum bool hasComponent(char c) = mixin("is(typeof(this."~c~"))");
    /** If the color has alpha. */
    enum bool hasAlpha = hasComponent!'a';


    // functions that return the color channels as a tuple
    /** Return the RGB tristimulus values as a tuple.
        These will always be ordered (R, G, B).
        Any color channels not present will be 0. */
    @property auto tristimulus() const
    {
        static if(hasComponent!'l')
        {
            return tuple(l, l, l);
        }
        else
        {
            static if(!hasComponent!'r')
                enum r = ComponentType(0);
            static if(!hasComponent!'g')
                enum g = ComponentType(0);
            static if(!hasComponent!'b')
                enum b = ComponentType(0);
            return tuple(r, g, b);
        }
    }
    /** Return the RGB tristimulus values + alpha as a tuple.
        These will always be ordered (R, G, B, A). */
    @property auto tristimulusWithAlpha() const
    {
        static if(!hasAlpha)
            enum a = defaultAlpha!ComponentType;
        return tuple(tristimulus.expand, a);
    }

    // RGB/A initialiser
    /** Construct a color from RGB and optional alpha values. */
    this(ComponentType r, ComponentType g, ComponentType b, ComponentType a = defaultAlpha!ComponentType)
    {
        foreach(c; TypeTuple!("r","g","b","a"))
            mixin(ComponentExpression!("this._ = _;", c, null));
        static if(canFind!(components, 'l'))
            this.l = toGrayscale!colorSpace(r, g, b); // ** Contentious? I this this is most useful
    }

    // L/A initialiser
    /** Construct a color from a luminance and optional alpha value. */
    this(ComponentType l, ComponentType a = defaultAlpha!ComponentType)
    {
        foreach(c; TypeTuple!("l","r","g","b"))
            mixin(ComponentExpression!("this._ = l;", c, null));
        static if(canFind!(components, 'a'))
            this.a = a;
    }

    // hex string initialiser
    /** Construct a color from a hex string. */
    this(C)(const(C)[] hex) if(isSomeChar!C)
    {
        import std.experimental.color.conv: colorFromString;
        this = colorFromString!(typeof(this))(hex);
    }

    // casts
    Color opCast(Color)() const if(isColor!Color)
    {
        return convertColor!Color(this);
    }

    // comparison
    bool opEquals(typeof(this) rh) const
    {
        // this is required to exclude 'x' components from equality comparisons
        return tristimulusWithAlpha == rh.tristimulusWithAlpha;
    }

    // operators
    mixin ColorOperators!AllComponents;

    unittest
    {
        alias UnsignedRGB = RGB!("rgb", ubyte);
        alias SignedRGBX = RGB!("rgbx", byte);
        alias FloatRGBA = RGB!("rgba", float);

        // test construction
        static assert(UnsignedRGB("0x908000FF")  == UnsignedRGB(0x80,0,0xFF));
        static assert(FloatRGBA("0x908000FF")    == FloatRGBA(float(0x80)/float(0xFF),0,1,float(0x90)/float(0xFF)));

        // test operators
        static assert(-SignedRGBX(1,2,3) == SignedRGBX(-1,-2,-3));
        static assert(-FloatRGBA(1,2,3)  == FloatRGBA(-1,-2,-3));

        static assert(UnsignedRGB(10,20,30)  + UnsignedRGB(4,5,6) == UnsignedRGB(14,25,36));
        static assert(SignedRGBX(10,20,30)   + SignedRGBX(4,5,6)  == SignedRGBX(14,25,36));
        static assert(FloatRGBA(10,20,30,40) + FloatRGBA(4,5,6,7) == FloatRGBA(14,25,36,47));

        static assert(UnsignedRGB(10,20,30)  - UnsignedRGB(4,5,6) == UnsignedRGB(6,15,24));
        static assert(SignedRGBX(10,20,30)   - SignedRGBX(4,5,6)  == SignedRGBX(6,15,24));
        static assert(FloatRGBA(10,20,30,40) - FloatRGBA(4,5,6,7) == FloatRGBA(6,15,24,33));

        static assert(UnsignedRGB(10,20,30)  * UnsignedRGB(0,1,2) == UnsignedRGB(0,20,60));
        static assert(SignedRGBX(10,20,30)   * SignedRGBX(0,1,2)  == SignedRGBX(0,20,60));
        static assert(FloatRGBA(10,20,30,40) * FloatRGBA(0,1,2,3) == FloatRGBA(0,20,60,120));

        static assert(UnsignedRGB(10,20,30)  / UnsignedRGB(1,2,3) == UnsignedRGB(10,10,10));
        static assert(SignedRGBX(10,20,30)   / SignedRGBX(1,2,3)  == SignedRGBX(10,10,10));
        static assert(FloatRGBA(2,4,8,16)    / FloatRGBA(1,2,4,8) == FloatRGBA(2,2,2,2));

        static assert(UnsignedRGB(10,20,30)  * 2 == UnsignedRGB(20,40,60));
        static assert(SignedRGBX(10,20,30)   * 2 == SignedRGBX(20,40,60));
        static assert(FloatRGBA(10,20,30,40) * 2 == FloatRGBA(20,40,60,80));

        static assert(UnsignedRGB(10,20,30)  / 2 == UnsignedRGB(5,10,15));
        static assert(SignedRGBX(10,20,30)   / 2 == SignedRGBX(5,10,15));
        static assert(FloatRGBA(10,20,30,40) / 2 == FloatRGBA(5,10,15,20));
    }

private:
    alias AllComponents = TypeTuple!("l","r","g","b","a");
    alias ParentColourSpace = XYZ!(FloatTypeFor!ComponentType);
}


// TODO: represent packed colors, eg R5G6B5, etc
struct PackedRGB(string format, bool linear_ = false, RGBColorSpace colorSpace_ = RGBColorSpace.sRGB)
{
@safe: pure: nothrow: @nogc:

    // RGB colors may only contain components 'rgb', or 'l' (luminance)
    // They may also optionally contain an 'a' (alpha) component, and 'x' (unused) components
    static assert(allIn!("rgblax", components), "Invalid Color component '"d ~ notIn!("rgblax", components) ~ "'. RGB colors may only contain components: r, g, b, l, a, x"d);
    static assert(anyIn!("rgbal", components), "RGB colors must contain at least one component of r, g, b, l, a.");
    static assert(!canFind!(components, 'l') || !anyIn!("rgb", components), "RGB colors may not contain rgb AND luminance components together.");

    // create members for some useful information
    alias UnpackedComponentType = ubyte; // RGBA1010102 should be ushort, etc
    enum string components = format; // TODO: strip sizes from format ('rgb565' => 'rgb')
    enum RGBColorSpace colorSpace = colorSpace_;
    enum bool linear = linear_;

    // TODO: we'll try and fabricate the packing algorithm based on the format string
    //...

    void pack(C)(C color);
    C unpack(C)();

private:
    alias ParentColourSpace = RGB!(components, UnpackedComponentType, linear_, colorSpace_);
}


// gamma ramp conversions
/** Convert a value from a color space's gamma to linear. */
T toLinear(RGBColorSpace src, T)(T v) if(isFloatingPoint!T)
{
    enum ColorSpace = RGBColorSpaceDefs!T[src];
    return ColorSpace.toLinear(v);
}
/** Convert a value to a color space's gamma. */
T toGamma(RGBColorSpace src, T)(T v) if(isFloatingPoint!T)
{
    enum ColorSpace = RGBColorSpaceDefs!T[src];
    return ColorSpace.toGamma(v);
}

/** Convert a color to linear space. */
auto toLinear(C)(C color) const if(isRGB!C)
{
    return cast(RGB!(C.components, C.ComponentType, true, C.colorSpace))color;
}
/** Convert a color to gamma space. */
auto toGamma(C)(C color) const if(isRGB!C)
{
    return cast(RGB!(C.components, C.ComponentType, false, C.colorSpace))color;
}


package:
//
// Below exists a bunch of machinery for converting between RGB colour spaces
//

import std.experimental.color.xyz;

// RGB color space definitions
struct RGBColorSpaceDef(F)
{
    alias GammaFunc = F function(F v) pure nothrow @nogc @safe;

    string name;

    GammaFunc toGamma;
    GammaFunc toLinear;

    xyY!F white;
    xyY!F red;
    xyY!F green;
    xyY!F blue;
}

enum RGBColorSpaceDefs(F) = [
    RGBColorSpaceDef!F("sRGB",           &linearTosRGB!F,         &sRGBToLinear!F,         WhitePoint!F.D65, xyY!F(0.6400, 0.3300, 0.212656), xyY!F(0.3000, 0.6000, 0.715158), xyY!F(0.1500, 0.0600, 0.072186)),
    RGBColorSpaceDef!F("sRGB Simple",    &linearToGamma!(F, 2.2), &gammaToLinear!(F, 2.2), WhitePoint!F.D65, xyY!F(0.6400, 0.3300, 0.212656), xyY!F(0.3000, 0.6000, 0.715158), xyY!F(0.1500, 0.0600, 0.072186)),

/+ TODO: these all need testing to prove they are correct
    // ** adobe seen using gamma 2.19921875 ???
    RGBColorSpaceDef!F("Adobe RGB",      &linearToGamma!(F, 2.2), &gammaToLinear!(F, 2.2), WhitePoint!F.D65, xyY!F(0.6400, 0.3300, 0.297361), xyY!F(0.2100, 0.7100, 0.627355), xyY!F(0.1500, 0.0600, 0.075285)),
    RGBColorSpaceDef!F("Apple RGB",      &linearToGamma!(F, 1.8), &gammaToLinear!(F, 1.8), WhitePoint!F.D65, xyY!F(0.6250, 0.3400, 0.244634), xyY!F(0.2800, 0.5950, 0.672034), xyY!F(0.1550, 0.0700, 0.083332)),
    RGBColorSpaceDef!F("Best RGB",       &linearToGamma!(F, 2.2), &gammaToLinear!(F, 2.2), WhitePoint!F.D50, xyY!F(0.7347, 0.2653, 0.228457), xyY!F(0.2150, 0.7750, 0.737352), xyY!F(0.1300, 0.0350, 0.034191)),
    RGBColorSpaceDef!F("Beta RGB",       &linearToGamma!(F, 2.2), &gammaToLinear!(F, 2.2), WhitePoint!F.D50, xyY!F(0.6888, 0.3112, 0.303273), xyY!F(0.1986, 0.7551, 0.663786), xyY!F(0.1265, 0.0352, 0.032941)),
    RGBColorSpaceDef!F("Bruce RGB",      &linearToGamma!(F, 2.2), &gammaToLinear!(F, 2.2), WhitePoint!F.D65, xyY!F(0.6400, 0.3300, 0.240995), xyY!F(0.2800, 0.6500, 0.683554), xyY!F(0.1500, 0.0600, 0.075452)),
    RGBColorSpaceDef!F("CIE RGB",        &linearToGamma!(F, 2.2), &gammaToLinear!(F, 2.2), WhitePoint!F.E,   xyY!F(0.7350, 0.2650, 0.176204), xyY!F(0.2740, 0.7170, 0.812985), xyY!F(0.1670, 0.0090, 0.010811)),
    RGBColorSpaceDef!F("ColorMatch RGB", &linearToGamma!(F, 1.8), &gammaToLinear!(F, 1.8), WhitePoint!F.D50, xyY!F(0.6300, 0.3400, 0.274884), xyY!F(0.2950, 0.6050, 0.658132), xyY!F(0.1500, 0.0750, 0.066985)),
    RGBColorSpaceDef!F("Don RGB 4",      &linearToGamma!(F, 2.2), &gammaToLinear!(F, 2.2), WhitePoint!F.D50, xyY!F(0.6960, 0.3000, 0.278350), xyY!F(0.2150, 0.7650, 0.687970), xyY!F(0.1300, 0.0350, 0.033680)),
//    RGBColorSpaceDef!F("ECI RGB v2",     L*,                                               WhitePoint!F.D50, xyY!F(0.6700, 0.3300, 0.320250), xyY!F(0.2100, 0.7100, 0.602071), xyY!F(0.1400, 0.0800, 0.077679)),
    RGBColorSpaceDef!F("Ekta Space PS5", &linearToGamma!(F, 2.2), &gammaToLinear!(F, 2.2), WhitePoint!F.D50, xyY!F(0.6950, 0.3050, 0.260629), xyY!F(0.2600, 0.7000, 0.734946), xyY!F(0.1100, 0.0050, 0.004425)),
    RGBColorSpaceDef!F("NTSC RGB",       &linearToGamma!(F, 2.2), &gammaToLinear!(F, 2.2), WhitePoint!F.C,   xyY!F(0.6700, 0.3300, 0.298839), xyY!F(0.2100, 0.7100, 0.586811), xyY!F(0.1400, 0.0800, 0.114350)),
    RGBColorSpaceDef!F("PAL/SECAM RGB",  &linearToGamma!(F, 2.2), &gammaToLinear!(F, 2.2), WhitePoint!F.D65, xyY!F(0.6400, 0.3300, 0.222021), xyY!F(0.2900, 0.6000, 0.706645), xyY!F(0.1500, 0.0600, 0.071334)),
    RGBColorSpaceDef!F("ProPhoto RGB",   &linearToGamma!(F, 1.8), &gammaToLinear!(F, 1.8), WhitePoint!F.D50, xyY!F(0.7347, 0.2653, 0.288040), xyY!F(0.1596, 0.8404, 0.711874), xyY!F(0.0366, 0.0001, 0.000086)),
    RGBColorSpaceDef!F("SMPTE-C RGB",    &linearToGamma!(F, 2.2), &gammaToLinear!(F, 2.2), WhitePoint!F.D65, xyY!F(0.6300, 0.3400, 0.212395), xyY!F(0.3100, 0.5950, 0.701049), xyY!F(0.1550, 0.0700, 0.086556)),
    RGBColorSpaceDef!F("Wide Gamut RGB", &linearToGamma!(F, 2.2), &gammaToLinear!(F, 2.2), WhitePoint!F.D50, xyY!F(0.7350, 0.2650, 0.258187), xyY!F(0.1150, 0.8260, 0.724938), xyY!F(0.1570, 0.0180, 0.016875))
+/
];

template RGBColorSpaceMatrix(RGBColorSpace cs, F)
{
    enum F[3] ToXYZ(xyY!F c) = [ c.x/c.y, F(1), (F(1)-c.x-c.y)/c.y ];

    // get the colour space definition
    enum def = RGBColorSpaceDefs!F[cs];
    // build a matrix from the 3 colour vectors
    enum r = def.red, g = def.green, b = def.blue;
    enum m = transpose([ ToXYZ!r, ToXYZ!g, ToXYZ!b ]);

    // multiply by the whitepoint
    enum w = [ (cast(XYZ!F)(def.white)).tupleof ];
    enum s = multiply(inverse(m), w);

    // return colourspace matrix (RGB -> XYZ)
    enum F[3][3] RGBColorSpaceMatrix = [[ m[0][0]*s[0], m[0][1]*s[1], m[0][2]*s[2] ],
                                        [ m[1][0]*s[0], m[1][1]*s[1], m[1][2]*s[2] ],
                                        [ m[2][0]*s[0], m[2][1]*s[1], m[2][2]*s[2] ]];
}


T linearTosRGB(T)(T s) if(isFloatingPoint!T)
{
    if(s <= T(0.0031308))
        return T(12.92) * s;
    else
        return T(1.055) * s^^T(1.0/2.4) - T(0.055);
}
T sRGBToLinear(T)(T s) if(isFloatingPoint!T)
{
    if(s <= T(0.04045))
        return s / T(12.92);
    else
        return ((s + T(0.055)) / T(1.055))^^T(2.4);
}

T linearToGamma(T, T gamma)(T v) if(isFloatingPoint!T)
{
    return v^^T(1.0/gamma);
}
T gammaToLinear(T, T gamma)(T v) if(isFloatingPoint!T)
{
    return v^^T(gamma);
}

T toGrayscale(RGBColorSpace colorSpace = RGBColorSpace.sRGB, T)(T r, T g, T b) pure if(isFloatingPoint!T)
{
    // TODO: this function only works for sRGB!
    // *** others will compile, and produce wrong results!
/*
    TODO: do i have this function right? am i in the wrong space?

    // i think this is the linear conversion coefficients
    wiki = 0.299r + 0.587g + 0.114b
    ps: (0.3)+(0.59)+(0.11)

    // but gimp source seems to use this one... perhaps this performs an sRGB space estimate, or is THIS the linear one?
    gimp: 0.21 R + 0.72 G + 0.07 B
    another = 0.2126 R + 0.7152 G + 0.0722 B   (apparently in linear space?)
*/
    return toGamma!colorSpace(T(0.299)*toLinear!colorSpace(r) + T(0.587)*toLinear!colorSpace(g) + T(0.114)*toLinear!colorSpace(b));
}
T toGrayscale(RGBColorSpace colorSpace = RGBColorSpace.sRGB, T)(T r, T g, T b) pure if(isIntegral!T)
{
    import std.experimental.color.conv: convertPixelType;
    alias F = FloatTypeFor!T;
    return convertPixelType!T(toGrayscale!colorSpace(convertPixelType!F(r), convertPixelType!F(g), convertPixelType!F(b)));
}


// helpers to parse color components from color component string
template canFind(string s, char c)
{
    static if(s.length == 0)
        enum canFind = false;
    else
        enum canFind = s[0] == c || canFind!(s[1..$], c);
}
template allIn(string s, string chars)
{
    static if(chars.length == 0)
        enum allIn = true;
    else
        enum allIn = canFind!(s, chars[0]) && allIn!(s, chars[1..$]);
}
template anyIn(string s, string chars)
{
    static if(chars.length == 0)
        enum anyIn = false;
    else
        enum anyIn = canFind!(s, chars[0]) || anyIn!(s, chars[1..$]);
}
template notIn(string s, string chars)
{
    static if(chars.length == 0)
        enum notIn = char(0);
    else static if(!canFind!(s, chars[0]))
        enum notIn = chars[0];
    else
        enum notIn = notIn!(s, chars[1..$]);
}

unittest
{
    static assert(canFind!("string", 'i'));
    static assert(!canFind!("string", 'x'));
    static assert(allIn!("string", "sgi"));
    static assert(!allIn!("string", "sgix"));
    static assert(anyIn!("string", "sx"));
    static assert(!anyIn!("string", "x"));
}



// try and use the preferred float type, but if the int type exceeds the preferred float precision, we'll upgrade the float
template FloatTypeFor(IntType, RequestedFloat = float)
{
    static if(IntType.sizeof > 2)
        alias FloatTypeFor = double;
    else
        alias FloatTypeFor = RequestedFloat;
}

// find the fastest type to do format conversion without losing precision
template WorkingType(From, To)
{
    static if(isIntegral!From && isIntegral!To)
    {
        // small integer types can use float and not lose precision
        static if(From.sizeof <= 2 && To.sizeof <= 2)
            alias WorkingType = float;
        else
            alias WorkingType = double;
    }
    else static if(isIntegral!From && isFloatingPoint!To)
        alias WorkingType = To;
    else static if(isFloatingPoint!From && isIntegral!To)
        alias WorkingType = FloatTypeFor!To;
    else
    {
        static if(From.sizeof > To.sizeof)
            alias WorkingType = From;
        else
            alias WorkingType = To;
    }
}


// 3d linear algebra functions (this would ideally live somewhere else...)
F[3] multiply(F)(F[3][3] m1, F[3] v)
{
    return [ m1[0][0]*v[0] + m1[0][1]*v[1] + m1[0][2]*v[2],
             m1[1][0]*v[0] + m1[1][1]*v[1] + m1[1][2]*v[2],
             m1[2][0]*v[0] + m1[2][1]*v[1] + m1[2][2]*v[2] ];
}

F[3][3] multiply(F)(F[3][3] m1, F[3][3] m2)
{
    return [[ m1[0][0]*m2[0][0] + m1[0][1]*m2[1][0] + m1[0][2]*m2[2][0],
              m1[0][0]*m2[0][1] + m1[0][1]*m2[1][1] + m1[0][2]*m2[2][1],
              m1[0][0]*m2[0][2] + m1[0][1]*m2[1][2] + m1[0][2]*m2[2][2] ],
            [ m1[1][0]*m2[0][0] + m1[1][1]*m2[1][0] + m1[1][2]*m2[2][0],
              m1[1][0]*m2[0][1] + m1[1][1]*m2[1][1] + m1[1][2]*m2[2][1],
              m1[1][0]*m2[0][2] + m1[1][1]*m2[1][2] + m1[1][2]*m2[2][2] ],
            [ m1[2][0]*m2[0][0] + m1[2][1]*m2[1][0] + m1[2][2]*m2[2][0],
              m1[2][0]*m2[0][1] + m1[2][1]*m2[1][1] + m1[2][2]*m2[2][1],
              m1[2][0]*m2[0][2] + m1[2][1]*m2[1][2] + m1[2][2]*m2[2][2] ]];
}

F[3][3] transpose(F)(F[3][3] m)
{
    return [[ m[0][0], m[1][0], m[2][0] ],
            [ m[0][1], m[1][1], m[2][1] ],
            [ m[0][2], m[1][2], m[2][2] ]];
}

F determinant(F)(F[3][3] m)
{
    return m[0][0] * (m[1][1]*m[2][2] - m[2][1]*m[1][2]) -
           m[0][1] * (m[1][0]*m[2][2] - m[1][2]*m[2][0]) +
           m[0][2] * (m[1][0]*m[2][1] - m[1][1]*m[2][0]);
}

F[3][3] inverse(F)(F[3][3] m)
{
    F det = determinant(m);
    assert(det != 0, "Matrix is not invertible!");

    F invDet = F(1)/det;
    return [[ (m[1][1]*m[2][2] - m[2][1]*m[1][2]) * invDet,
              (m[0][2]*m[2][1] - m[0][1]*m[2][2]) * invDet,
              (m[0][1]*m[1][2] - m[0][2]*m[1][1]) * invDet ],
            [ (m[1][2]*m[2][0] - m[1][0]*m[2][2]) * invDet,
              (m[0][0]*m[2][2] - m[0][2]*m[2][0]) * invDet,
              (m[1][0]*m[0][2] - m[0][0]*m[1][2]) * invDet ],
            [ (m[1][0]*m[2][1] - m[2][0]*m[1][1]) * invDet,
              (m[2][0]*m[0][1] - m[0][0]*m[2][1]) * invDet,
              (m[0][0]*m[1][1] - m[1][0]*m[0][1]) * invDet ]];
}
