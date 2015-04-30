module test;

import dsignal.dft;
import dsignal.fft;
import dsignal.stft;
import dsignal.window;
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

alias Lum = Color!("l", double, ColorSpace.sRGB_l);
alias lRGB = Color!("rgb", double, ColorSpace.sRGB_l);

void main()
{
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
		.plot(512, 256, p)
		.colorMap!(c => lRGB(1-c, 1, 1-c));

	enum WindowSize = 801;
	enum Hop = 50;
	enum FFTSize = nextPowerOf2(WindowSize);

	float[WindowSize] window;
	generateWindow(WindowType.Hamming, window);

	float sum = window[].sum;
	window[] *= (1.0f/sum);

	float[][] amplitude = new float[][](segment(s.samples, WindowSize, WindowSize-Hop).length, FFTSize/2+1);
	float[][] phase = new float[][](segment(s.samples, WindowSize, WindowSize-Hop).length, FFTSize/2+1);

	STFT(s.samples, window[], amplitude, phase, Hop, FFTSize);

	ISTFT(amplitude, phase, s.samples, window.length, Hop, FFTSize);

	vertical(wf,
			 s.samples
			 .plot(512, 256, p)
			 .colorMap!(c => lRGB(1-c, 1, 1-c)),
			 amplitude.matrixFrom2DArray.vFlip
				 .colorMap!(e => lRGB(clamp(toDecibels(e)/150 + 1, 0, 1)))
//			 phase.matrixFrom2DArray.vFlip
//				 .colorMap!(e => Lum(e*(1/(PI*2) + 0.5))), 
			 )
		.save("plot.tga");

	system("start plot.tga");

	s.save("synth.wav");
//	system("start synth.wav");
}
