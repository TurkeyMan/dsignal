module std.experimental.color.hsx;

import std.experimental.color;

import std.traits : isFloatingPoint, isIntegral, isSigned, isUnsigned, isSomeChar, Unqual;
import std.typetuple : TypeTuple;
import std.typecons : tuple;

@safe pure nothrow @nogc:

/**
Detect whether $(D T) is a member of the HSx color family.
*/
enum isHSx(T) = isInstanceOf!(HSx, T);

///
unittest
{
    static assert(isHSx!(HSx!(HSxType.HSV, ushort)) == true);
    static assert(isHSx!string == false);
}

/**
Alias for a HSV (HSB) color.
*/
alias HSV(CT = float, RGBColorSpace cs = RGBColorSpace.sRGB) = HSx!(HSxType.HSV, CT, cs);

/**
Alias for a HSL color.
*/
alias HSL(CT = float, RGBColorSpace cs = RGBColorSpace.sRGB) = HSx!(HSxType.HSL, CT, cs);

/**
Alias for a HSI color.
*/
alias HSI(CT = float, RGBColorSpace cs = RGBColorSpace.sRGB) = HSx!(HSxType.HSI, CT, cs);

/**
Alias for a HCY color.
*/
alias HCY(CT = float, RGBColorSpace cs = RGBColorSpace.sRGB) = HSx!(HSxType.HCY, CT, cs);

/**
Define a HSx family colour type.
*/
enum HSxType
{
    /** Hue-saturation-value (aka HSB: Hue-saturation-brightness) */
    HSV,
    /** Hue-saturation-lightness */
    HSL,
    /** Hue-saturation-intensity */
    HSI,
    /** Hue-chroma-luma */
    HCY
}

/**
HSx color space is used to describe a suite of angular color spaces including HSL, HSV, HSI, HCY.
*/
struct HSx(HSxType type_, CT = float, RGBColorSpace colorSpace_ = RGBColorSpace.sRGB) if(isFloatingPoint!CT || isUnsigned!CT)
{
@safe pure nothrow @nogc:

    /** Type of the color components. */
    alias ComponentType = CT;
    /** The color space specified. */
    enum colorSpace = colorSpace_;
    /** The color type from the HSx family. */
    enum type = type_;

    // mixin the color channels according to the type
    mixin("CT " ~ Components!type[0] ~ " = 0;");
    mixin("CT " ~ Components!type[1] ~ " = 0;");
    mixin("CT " ~ Components!type[2] ~ " = 0;");

    // casts
    Color opCast(Color)() const if(isColor!Color)
    {
        return convertColor!Color(this);
    }

    // operators
    mixin ColorOperators!(Components!type);

private:
    template Components(HSxType type)
    {
        static if(type == HSxType.HSV)
            alias Components = TypeTuple!("h","s","v");
        else static if(type == HSxType.HSL)
            alias Components = TypeTuple!("h","s","l");
        else static if(type == HSxType.HSI)
            alias Components = TypeTuple!("h","s","i");
        else static if(type == HSxType.HCY)
            alias Components = TypeTuple!("h","c","y");
    }
    alias ParentColourSpace = RGB!("rgb", CT, false, colorSpace_);
}

///
unittest
{
    // HSL color with float components
    alias HSLf = HSx!(HSxType.HSL, float);

    HSLf c = HSLf(3.1415, 1, 0.5);

    // test HSL operators and functions
    static assert(HSLf(3.1415, 0.2, 0.5) + HSLf(0, 0.5, 0.5) == HSLf(3.1415, 0.7, 1));
    static assert(HSLf(2, 0.5, 1) * 100.0 == HSLf(200, 50, 100));
}
