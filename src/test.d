module test;

import dsignal.fft;
import dsignal.stft;
import dsignal.window;
import dsignal.analyse;
import dsignal.wave;
import dsignal.util;
import graph.plot;
import image.image;
import sound.sound;
import std.experimental.color;
import std.math;
import std.c.stdlib;
import std.algorithm: map, reduce, copy, sum, clamp;
import std.range: chain;

alias Lum = RGB!("l", double, true);

/+
struct Expression(string _op, T...)
{
	import std.traits;

	static if(_op[0] == '#')
		enum stringof = T[0].stringof;
	else static if(T.length == 1)
		enum stringof = _op~T[0].stringof;
	else static if(T.length == 2)
		enum stringof = "("~T[0].stringof~_op~T[1].stringof~")";

	enum string op = _op;
	alias V = T;

	auto opUnary(string op)()
	{
		return Expression!(op, this)();
	}
	auto opBinary(string op, R)(R rh)
	{
		static assert(isInstanceOf!(Expression, R));
		return Expression!(op, typeof(this), typeof(rh))();
	}
	auto opBinaryRight(string op, L)(L lh)
	{
		static assert(isInstanceOf!(Expression, L));
		return Expression!(op, typeof(lh), typeof(this))();
	}
}

auto Algebraic(alias T) = Expression!("#"~T.stringof, T)();

enum bool isLiteral(alias v) = !__traits(compiles, &v);


template Simplify(alias E)
{
	static if(E.op[0] == '#')
		alias Simplify = E.V[0];
	else static if(E.V.length == 1)
		auto Simplify() { return mixin(E.op~"Simplify!(E.V[0])"); }
	else static if(E.V.length == 2)
		auto Simplify() { return mixin("Simplify!(E.V[0])"~E.op~"Simplify!(E.V[1])"); }
}

template TT(alias a, alias b)
{
	import std.typetuple: Alias;
	alias TT = Alias!(a + b);
}

void algebraic()
{
	// x + 10 = 0

	float x = 10;
	auto a = Algebraic!x;
	auto b = Algebraic!20.0f;
	auto c = (a*a)+b-Algebraic!2;
	pragma(msg, c.stringof);

//	pragma(msg, Simplify!c);
//	auto f = Simplify!c;

	auto f = TT!(a, a);

	auto ff = f;


//	auto c = a+b;
//	sqrt(Algebraic(10)^^2) * 10 + 100
}
+/
void main()
{
//	algebraic();

//	testGraph();
//	testGraph2();
//	testSound();
	testSTFT();
}

void testGraph()
{
	// get some data
	enum Width = 511;
	enum PaddedWidth = 1024;

	float[Width] signal = void;
	generateSinewave(signal, 7);

	float[Width] signal2 = void;
	generateSinewave(signal2, 23);

	signal[] += signal2[]*0.5;

	// apply window
	float[Width] window;
	generateWindow(WindowType.Hann, window);

	signal[] *= window[];

	// zero-padd the data
	auto data = signal[].zeroPadd!true(PaddedWidth);

	Complex!float[PaddedWidth] r = void;
	Complex!float[PaddedWidth] rr = void;

	rr[] = signal[].FFTAnalyse(r)[];
	auto synth = rr.FFTSynth(Width);

	// write the results
	enum GraphWidth = 512;
	enum GraphHeight = 192;

	PlotParams p;
	p.width = 1.5;

	// phase image
	float[PaddedWidth] ph = void;
	r[].phase.copy(ph[]);
	auto phaseImg = ph[]
		.plot(GraphWidth, GraphHeight, p)
		.colorMap!(c => lRGB(1-c, 1-c, 1));

	float[PaddedWidth] ang = void;
	r[].angle.copy(ang[]);
	p.min = -PI; p.max = PI;
	auto angleImg = ang[]
		.plot(GraphWidth, GraphHeight, p)
		.colorMap!(c => lRGB(1-c, 1-c, 1));

	// amplitude image
	p.min = -90; p.max = 0;
	auto ampImg = r[].amplitude
		.plot(GraphWidth, GraphHeight, p)
		.colorMap!(c => lRGB(1, 1-c, 1-c));

	// signal image
	p.min = -1; p.max = 1;
	auto sigImg = signal[]
		.plot(GraphWidth, GraphHeight, p)
		.colorMap!(c => lRGB(1-c, 1, 1-c));

	// data image
	auto dataImg = data
		.plot(GraphWidth, GraphHeight, p)
		.colorMap!(c => lRGB(1-c, 1, 1-c));

	// synth image
	auto synthImg = rr[].map!(e=>e.re)
		.plot(GraphWidth, GraphHeight, p)
		.colorMap!(c => lRGB(1-c, 1, 1-c));

	// composite and save image
	vertical(
				horizontal(sigImg, solid(lRGB(), 2, GraphHeight), dataImg),
				solid(lRGB(), GraphWidth*2+2, 2),
				horizontal(ampImg, solid(lRGB(), 2, GraphHeight), synthImg),
				solid(lRGB(), GraphWidth*2+2, 2),
				horizontal(angleImg, solid(lRGB(), 2, GraphHeight), phaseImg),
			 )
		.save("plot.tga");
	system("start plot.tga");
}

void testGraph2()
{
	// get some data
	Sound s = load("claps.wav");

	// zero-padd the data
	size_t paddedWidth = 0;
	auto data = s.samples.zeroPadd!true(paddedWidth);
	paddedWidth = data.length;

	Complex!float[] r = new Complex!float[paddedWidth];
	Complex!float[] rr = new Complex!float[paddedWidth];

	rr[] = s.samples.FFTAnalyse(r)[];
	auto synth = rr.FFTSynth(s.samples.length);

	// write the results
	enum GraphWidth = 512;
	enum GraphHeight = 192;

	PlotParams p;
	p.width = 1.5;

	// phase image
	float[] ph = new float[paddedWidth];
	r.phase.copy(ph);
	auto phaseImg = ph[]
		.plot(GraphWidth, GraphHeight, p)
		.colorMap!(c => lRGB(1-c, 1-c, 1));

	p.min = -PI; p.max = PI;
	auto angleImg = r.angle
		.plot(GraphWidth, GraphHeight, p)
		.colorMap!(c => lRGB(1-c, 1-c, 1));

	// amplitude image
	p.min = -90; p.max = 0;
	auto ampImg = r.amplitude
		.plot(GraphWidth, GraphHeight, p)
		.colorMap!(c => lRGB(1, 1-c, 1-c));

	// signal image
	p.min = -1; p.max = 1;
	auto sigImg = s.samples
		.plot(GraphWidth, GraphHeight, p)
		.colorMap!(c => lRGB(1-c, 1, 1-c));

	// data image
	auto dataImg = data
		.plot(GraphWidth, GraphHeight, p)
		.colorMap!(c => lRGB(1-c, 1, 1-c));

	// synth image
	auto synthImg = rr.map!(e=>e.re)
		.plot(GraphWidth, GraphHeight, p)
		.colorMap!(c => lRGB(1-c, 1, 1-c));

	// composite and save image
	vertical(
			 horizontal(sigImg, solid(lRGB(), 2, GraphHeight), dataImg),
			 solid(lRGB(), GraphWidth*2+2, 2),
			 horizontal(ampImg, solid(lRGB(), 2, GraphHeight), synthImg),
			 solid(lRGB(), GraphWidth*2+2, 2),
			 horizontal(angleImg, solid(lRGB(), 2, GraphHeight), phaseImg),
			 )
		.save("plot.tga");
	system("start plot.tga");

	// save out wav
	float[] wav = new float[synth.length];
	synth.copy(wav);

	s.samples = wav;
	s.save("synth.wav");

	system("start synth.wav");
}


void testSound()
{
	Sound s = load("save.wav");
	s.save("synth.wav");

	system("start synth.wav");
}

void testSTFT()
{
	// get some data
	Sound s = load("save.wav");

	// signal image
	PlotParams p;
	p.width = 1.5;
	p.min = -1; p.max = 1;
	auto wf = s.samples.dup
		.plotWaveform(1024, 256);

	enum WindowSize = 801;
	enum Hop = 50;
	enum FFTSize = nextPowerOf2(WindowSize);

	float[WindowSize] window = void;
	generateWindow(WindowType.Hamming, window);

	float sum = window[].sum;
	window[] *= (1.0f/sum);

	float[][] amplitude = new float[][](segment(s.samples, WindowSize, WindowSize-Hop).length, FFTSize/2+1);
	float[][] phase = new float[][](segment(s.samples, WindowSize, WindowSize-Hop).length, FFTSize/2+1);

	STFT(s.samples, window[], amplitude, phase, Hop, FFTSize);

//	detectPeaks(amplitude[100], 0.5f);

	ISTFT(amplitude, phase, s.samples, window.length, Hop, FFTSize);

	vertical(wf,
			 s.samples.plotWaveform(1024, 256),
			 amplitude.plotSpectrum
//			 phase.matrixFrom2DArray.vFlip
//				 .colorMap!(e => Lum(e*(1/(PI*2) + 0.5))), 
			 )
		.save("plot.tga");

	system("start plot.tga");

	s.save("synth.wav");
//	system("start synth.wav");
}

extern (C) int tt()
{
	int a = 10;
	int b = 2;
	return a + b;
}
