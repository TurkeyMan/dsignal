module std.experimental.color.hsv;

import std.experimental.color;

import std.traits: isFloatingPoint, isIntegral, isSigned, isUnsigned, isSomeChar, Unqual;
import std.typetuple: TypeTuple;
import std.typecons: tuple;

@safe: pure: nothrow: @nogc:

enum isHSL(T) = isInstanceOf!(HSL, T);
enum isHSV(T) = isInstanceOf!(HSV, T);

enum isValidComponentType(T) = isUnsigned!T || isFloatingPoint!T;


struct HSL(CT = float, RGBColorSpace colorSpace_ = RGBColorSpace.sRGB) if(isValidComponentType!CT)
{
@safe: pure: nothrow: @nogc:

    alias ComponentType = CT;
    enum colorSpace = colorSpace_;

    CT h = 0;
    CT s = 0;
    CT l = 0;

    // casts
    Color opCast(Color)() const if(isColor!Color)
    {
        return convertColor!Color(this);
    }

    // operators
    typeof(this) opBinary(string op, S)(S rh) const if(isFloatingPoint!S && (op == "*" || op == "/" || op == "^^"))
    {
        alias T = Unqual!(typeof(this));
        T res = this;
        foreach(c; XYZComponents)
            mixin(ComponentExpression!("res._ #= rh;", c, op));
        return res;
    }
    ref typeof(this) opOpAssign(string op, S)(S rh) if(isFloatingPoint!S && (op == "*" || op == "/" || op == "^^"))
    {
        foreach(c; XYZComponents)
            mixin(ComponentExpression!("_ #= rh;", c, op));
        return this;
    }

private:
    alias AllComponents = TypeTuple!("h","s","l");
    alias ParentColourSpace = RGB!("rgb", CT, false, colorSpace_);
}

unittest
{
    //...
}

struct HSV(CT = float, RGBColorSpace colorSpace_ = RGBColorSpace.sRGB) if(isValidComponentType!CT)
{
@safe: pure: nothrow: @nogc:

    alias ComponentType = CT;
    enum colorSpace = colorSpace_;

    CT h = 0;
    CT s = 0;
    CT v = 0;

    // casts
    Color opCast(Color)() const if(isColor!Color)
    {
        return convertColor!Color(this);
    }

    // operators
    typeof(this) opBinary(string op, S)(S rh) const if(isFloatingPoint!S && (op == "*" || op == "/" || op == "^^"))
    {
        alias T = Unqual!(typeof(this));
        T res = this;
        foreach(c; XYZComponents)
            mixin(ComponentExpression!("res._ #= rh;", c, op));
        return res;
    }
    ref typeof(this) opOpAssign(string op, S)(S rh) if(isFloatingPoint!S && (op == "*" || op == "/" || op == "^^"))
    {
        foreach(c; XYZComponents)
            mixin(ComponentExpression!("_ #= rh;", c, op));
        return this;
    }

private:
    alias XYZComponents = TypeTuple!("h","s","v");
    alias ParentColourSpace = RGB!("rgb", CT, false, colorSpace_);
}

unittest
{
    //...
}
