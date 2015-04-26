module dsignal.dft;

public import std.complex;
import std.math;
import std.traits;


void DFT(F)(Complex!F[] data)
{
	size_t N = data.length;
	Complex!F[] r = new Complex!F[N];
	foreach(k; 0..N)
	{
		r[k] = 0;
		foreach(i; 0..N)
		{
			Complex!F s = std.complex.expi(2*PI*k/N*i);
			r[k] += data[i]*conj(s);
		}
	}
	data[] = r[];
}

void DFT(F)(F[] data, Complex!F[] result)
{
	ptrdiff_t N = data.length;
	foreach(k; 0..N)
	{
		result[k] = 0;
		foreach(n; 0..N)
		{
			Complex!F s = std.complex.expi(2*PI*(-N/2+k)/N*(-N/2+n));
			result[k] += data[n]*conj(s);
		}
	}
}

void IDFT(F)(Complex!F[] data, F[] result)
{
	ptrdiff_t N = data.length;
	foreach(n; 0..N)
	{
		Complex!F r = 0;
		foreach(k; 0..N)
		{
			Complex!F s = std.complex.expi(2*PI*(-N/2+n)/N*(-N/2+k));
			r += data[k]*s;
		}
		result[n] = (r/N).re;
	}
}
