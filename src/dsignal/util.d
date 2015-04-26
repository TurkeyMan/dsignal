module dsignal.util;

public import std.complex;
import std.math;
import std.algorithm: map;
import std.traits;
import std.range;

ulong nextPowerOf2(ulong n)
{
	n--;
	n |= n >> 1;
	n |= n >> 2;
	n |= n >> 4;
	n |= n >> 8;
	n |= n >> 16;
	n |= n >> 32;
	n++;
	return n;
}

bool isPowerOf2(size_t sz) @safe pure nothrow @nogc
{
    return (sz & (sz-1)) == 0;
}

// return x so that (1 << x) >= i
int iFloorLog2(size_t i)
{
	import core.bitop;
    assert(i > 0);
	return bsr(i);
}


auto toDecibels(F)(F val) if(isFloatingPoint!F)
{
	return 20*log10(val);
}

auto fromDecibels(F)(F val) if(isFloatingPoint!F)
{
	return 10^^(val/20);
}


auto sin(R)(R range) if(isInputRange!R)
{
	return range.map!(e => sin(e));
}

auto cos(R)(R range) if(isInputRange!R)
{
	return range.map!(e => cos(e));
}

auto expi(R)(R range) if(isInputRange!R)
{
	return range.map!(e => std.complex.expi(e));
}

auto abs(R)(R range) if(isInputRange!R)
{
	return range.map!(e => std.complex.abs(e));
}

auto angle(R)(R range) if(isInputRange!R)
{
	return range.map!(a => arg(a));
}

auto toDecibels(R)(R range) if(isInputRange!R)
{
	return range.map!(a => 20*log10(a));
}

auto fromDecibels(R)(R range) if(isInputRange!R)
{
	return range.map!(a => 10^^(a/20));
}

auto amplitude(R)(R range) if(isInputRange!R)
{
	return range.map!(a => 20*log10(std.complex.abs(a)));
}

// TODO: should perform phase unwrapping...?
auto phase(R)(R range) if(isForwardRange!R)
{
	struct Unwrap
	{
		R range;
		typeof(range.front.re) offset;

		@property bool empty() { return range.empty; }
		@property size_t length() { return range.length; }
		@property auto front() { return arg(range.front) + offset; }
		void popFront()
		{
			auto prev = front;
			range.popFront;
			if(empty)
				return;
			auto f = front;
			if(f - prev < -PI)
				offset += PI;
			if(f - prev > PI)
				offset -= PI;
		}

//        @property inout(T) back() inout { return value; }
//        void popBack() { --length; }
		@property auto save() { return this; }
//        inout(T) opIndex(ulong n) inout { return value; }
		auto opSlice() inout { return this; }
//        auto opSlice(ulong lower, ulong upper) inout { return typeof(this)(value, upper-lower); }
		alias opDollar = length;
	}
	return Unwrap(range, 0);
}



auto zeroPadd(bool bZeroPhaseWindow = false, R)(R range, size_t paddedSize = 0)
{
	if(paddedSize == 0)
		paddedSize = nextPowerOf2(range.length);

	size_t middle = range.length/2;
	static if(bZeroPhaseWindow)
	{
		return chain(range[middle..$], literalRange!(ElementType!R(0))(paddedSize - range.length), range[0..middle]);
	}
	else
	{
		size_t newMiddle = paddedSize/2;
		auto lead = literalRange!(ElementType!R(0))(newMiddle - middle);
		auto tail = literalRange!(ElementType!R(0))(paddedSize - newMiddle - (range.length - middle));
		return chain(lead, range, tail);
	}
}

auto unpadd(bool bZeroPhaseWindow = false, R)(R range, size_t origSize = 0)
{
	size_t origMiddle = origSize/2;
	static if(bZeroPhaseWindow)
	{
		return chain(range[$-origMiddle..$], range[0..origSize-origMiddle]);
	}
	else
	{
		size_t start = range.length/2 - origMiddle;
		return range[start..start+origSize];
	}
}

auto zeroPhaseWindow(R)(R range)
{
	size_t middle = range.length/2;
	return chain(range[middle..$], range[0..middle]);
}


auto literalRange(alias value)(size_t length)
{
	struct LiteralRange(alias Value)
	{
		alias value = Value;
		size_t length;

		@property bool empty() const { return !length; }
		@property auto front() inout { return value; }
		void popFront() { --length; }
		@property auto back() inout { return value; }
		void popBack() { --length; }
		@property auto save() { return this; }
		auto opIndex(ulong n) inout { return value; }
		auto opSlice() inout { return this; }
		auto opSlice(ulong lower, ulong upper) inout { return typeof(this)(upper-lower); }
		alias opDollar = length;
	}

	return LiteralRange!(value)(length);
}

auto constantRange(T)(T value, size_t length)
{
	struct ConstantRange(T)
	{
		T value;
		size_t length;

		@property bool empty() const { return !length; }
		@property inout(T) front() inout { return value; }
		void popFront() { --length; }
		@property inout(T) back() inout { return value; }
		void popBack() { --length; }
		@property auto save() { return this; }
		inout(T) opIndex(ulong n) inout { return value; }
		auto opSlice() inout { return this; }
		auto opSlice(ulong lower, ulong upper) inout { return typeof(this)(value, upper-lower); }
		alias opDollar = length;
	}
	return ConstantRange!T(value, length);
}
