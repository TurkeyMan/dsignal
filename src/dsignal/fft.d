module dsignal.fft;

public import std.complex;
import std.math;
import std.algorithm: map, copy;
import dsignal.util;

enum FFTDirection
{
    Forward = 0,
    Reverse = 1
}


/// Perform in-place FFT.
void FFT(T)(Complex!T[] buffer, FFTDirection direction = FFTDirection.Forward)
{
    size_t size = buffer.length;
    assert(isPowerOf2(size));
    int m = iFloorLog2(size);

    // do the bit reversal
    int i2 = cast(int)size / 2;
    int j = 0;
    for (int i = 0; i < size - 1; ++i)
    {
        if (i < j)
        {
            auto tmp = buffer[i];
            buffer[i] = buffer[j];
            buffer[j] = tmp;
        }

        int k = i2;
        while(k <= j)
        {
            j -= k;
            k = k / 2;
        }
        j += k;
    }

    // compute the FFT
    Complex!T c = Complex!T(-1);
    int l2 = 1;
    for (int l = 0; l < m; ++l)
    {
        int l1 = l2;
        l2 = l2 * 2;
        Complex!T u = 1;
        for (int j2 = 0; j2 < l1; ++j2)
        {
            int i = j2;
            while (i < size)
            {
                int i1 = i + l1;
                Complex!T t1 = u * buffer[i1];
                buffer[i1] = buffer[i] - t1;
                buffer[i] += t1;
                i += l2;
            }
            u = u * c;
        }

        T newImag = sqrt((1 - c.re) / 2);
        if (direction == FFTDirection.Forward)
            newImag = -newImag;
        T newReal = sqrt((1 + c.re) / 2);
        c = Complex!T(newReal, newImag);
    }

    // scaling for forward transformation
    if (direction == FFTDirection.Forward)
    {
        for (int i = 0; i < size; ++i)
            buffer[i] = buffer[i] / Complex!T(cast(T)size, 0);
    }
}

void IFFT(F)(Complex!F[] buffer)
{
	return FFT(buffer, FFTDirection.Reverse);
}


auto FFTAnalyse(F)(const(F)[] signal, Complex!F[] buffer)
{
	signal.map!(e => Complex!F(e)).zeroPadd!true(buffer.length).copy(buffer);
	FFT(buffer);
	return buffer;
}

auto FFTSynth(F)(Complex!F[] buffer, size_t outputSamples = 0)
{
	IFFT(buffer);
	return buffer.unpadd!true(outputSamples ? outputSamples : buffer.length).map!(e => e.re);
}

auto FFTSynth(F)(Complex!F[] buffer, F[] output)
{
	IFFT(buffer);
	return buffer.unpadd!true(output.length).map!(e => e.re).copy(output);
}
