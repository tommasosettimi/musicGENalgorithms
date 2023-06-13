

// FIRSLY BOOT THE AUDIO SERVER
(
s.options.memSize_(2.pow(20));
s.reboot;
)

s.record

// THEN EVALUATE IT
(
Task({
	~buffer = Buffer.alloc(s, s.sampleRate * 0.1, 1, 2);
	~freq = 27.5; // Fundamental frequency
	~spectrumGen = {|freq, powerTwo = 0| //Spectrum generator function
		var arr = Array.newClear, mul, firstPartials, goodPartials;
		goodPartials = freq  * [1, 2, 4, 6, 9, 11, 13, 14, 15, 17, 20];
		mul = 2**powerTwo;
		20.do {|i, index| arr = arr.add(freq * (index + 1))};
		firstPartials = Array.with(arr[0], arr[1]);
		arr = arr.drop(1).drop(1);
		9.do {|i, index| arr.removeAt(1.rrand(2))};
		arr = firstPartials ++ arr;
		arr = [arr, goodPartials].choose;
		arr = arr * mul;
	};
	~inputFreq = ~spectrumGen.(~freq, 0);
	~multiV = {|input, vibrMax, switchFreq = 0, nvoice, stepFreq, lowLim, uppLim, gain = 2, curve = 0, switchAmp = 0, directionAmp, slopeAmp, widthGen, widthPan, switchPan = 0|
		var freqArr, ampArr, offsetAmp, panArr, freqRange, dataArr, vibrArr, outputVibr, ampArr1, panArr1, positive = Array.newClear, negative = Array.newClear, rand1, rand2, bigger;
		vibrArr = Array.fill(input.size, {0.3.rrand(6.0)}).sort.normalize(0.3, vibrMax);
		case
		{switchFreq == 0}{vibrArr}
		{switchFreq == 1}{vibrArr = vibrArr.reverse}
		{switchFreq == 2}{vibrArr = vibrArr.rotate((vibrArr.size * 0.5).asInteger)}
		{true}{vibrArr = vibrArr.rotate(switchFreq)};
		case
		{curve == 0}{ampArr1 = Array.linrand(input.size, 0.05, 1).sort.reverse}
		{curve == 1}{ampArr1 = Array.exprand(input.size, 0.05, 1).sort.reverse}
		{curve == 2}{ampArr1 = Array.rand(input.size, 0.05, 1.0).sort.reverse}
		{true}{ampArr1 = Array.linrand(input.size, 0.05, gain).sort.reverse};
		ampArr1 = ampArr1.normalize(min: ampArr1.minItem, max: gain);
		case
		{switchAmp == 0}{ampArr1 = ampArr1}
		{switchAmp == 1}{ampArr1 = ampArr1.reverse}
		{switchAmp == 2}{ampArr1 = ampArr1.rotate((ampArr1.size * 0.5).asInteger)}
		{true}{ampArr1 = ampArr1.rotate(switchAmp)};
		rand1 = [(input.size * 0.5).ceil, (input.size * 0.5).floor].choose;
		positive = Array.fill(rand1, {0.0.rrand(1.0)}).sort.normalize(0.0, widthGen);
		if (positive.size == (input.size * 0.5).ceil)
		{negative = Array.fill(rand1 - 1, {-1.0.rrand(0.0)}).sort.normalize(widthGen.neg, 0.0); bigger = "positive"}
		{negative = Array.fill(rand1 + 1, {-1.0.rrand(0.0)}).sort.normalize(widthGen.neg, 0.0)};
		negative = negative.reverse;
		if (bigger == "positive")
		{panArr1 = [positive, negative]}
		{panArr1 = [negative, positive]};
		panArr1 = panArr1.lace(positive.size + negative.size);
		case
		{switchPan == 0}{panArr1 = panArr1}
		{switchPan == 1}{panArr1 = panArr1.reverse}
		{switchPan == 2}{panArr1 = panArr1.rotate((panArr1.size * 0.5).asInteger)}
		{true}{panArr1 = panArr1.rotate(switchPan)};
		dataArr = {|i|
			freqArr = Array.series((nvoice / 2).asInteger, 0, stepFreq);
			freqArr = (vibrArr[i]) + freqArr;
			freqArr = [[input[i] + freqArr], [input[i] - freqArr]].flat.sort;
			freqRange = uppLim - lowLim;
			freqArr = freqArr.collect {|i| if (i < lowLim) {if ((lowLim - i) > freqRange) {i = lowLim.rrand(uppLim)} {i = i + (lowLim - i)}} {i}};
			freqArr = freqArr.collect {|i| if (i > uppLim) {if ((i - uppLim) > freqRange) {i = lowLim.rrand(uppLim)} {i = uppLim - (i - uppLim)}} {i}};
			ampArr = Array.fill((nvoice/2).asInteger, {|i| slopeAmp * i});
			ampArr = ampArr + (100 - ampArr[(nvoice/2).asInteger-1]);
			ampArr = ampArr / 100;
			offsetAmp = ampArr1[i] - ampArr[(nvoice/2).asInteger-1];
			if (directionAmp == 1) {ampArr = ampArr.reverse};
			ampArr = ampArr.reverse ++ ampArr;
			ampArr = ampArr + offsetAmp;
			panArr = Array.series((nvoice/2).asInteger, 0 + widthPan / (nvoice/2).asInteger, widthPan / (nvoice/2).asInteger);
			panArr = panArr1[i] + (panArr.reverse.neg ++ panArr);
			panArr = panArr.collect {|i| if (i < 1.neg) {i = 1.neg + (1.neg - i)} {i}};
			panArr = panArr.collect {|i| if (i > 1) {i = 1 - (i - 1)} {i}};
			[freqArr, ampArr, panArr]} ! input.size;
		dataArr;
	};
	~multiVArr = ~multiV.(
		input: ~inputFreq,
		vibrMax: 3,
		switchFreq: 0,
		nvoice: 3,
		stepFreq: 0.05,
		lowLim: 20,
		uppLim: 20000,
		gain: 2,
		curve: 0,
		switchAmp: 0,
		slopeAmp: 10,
		directionAmp: 1,
		widthGen: 1,
		widthPan: 0.1,
		switchPan: 0
	);

	~multiVDef = SynthDef(\splitDef, {
		var sig, env, tempo, modFreq = 200, modIndex = 0.5, freqDev = modIndex * modFreq, fm, am;
		modIndex = LFDNoise3.kr(0.4, 0.3, 0.4);
		modFreq = 200;
		fm = SinOsc.ar(modFreq, 0, freqDev);
		sig = {|j| {|i| Pan2.ar(SinOsc.ar(~multiVArr[j][0][i] + fm, mul: ~multiVArr[j][1][i]), pos: ~multiVArr[j][2][i])} ! ~multiVArr[j][0].size} ! ~inputFreq.size;
		sig = sig.collect {|i| i.sum / ~multiVArr[0][0].size * 0.1};
		sig = sig.sum / ~inputFreq.size;
		~tempo = 27;
		env = EnvGen.kr(Env([0, 1, 1, 0], [~tempo, ~tempo, ~tempo]), doneAction: 2);

		sig = sig * env * LFDNoise3.kr(0.35, 0.9 + LFDNoise3.kr(0.2, 0.2) + LFDNoise3.kr(0.1, 0.1)) * SinOsc.kr(0.1, mul: 0.25, add: 0.75) * SinOsc.kr(0.1, phase: 1, mul: 0.15, add: 0.95);
		am =  sig * SinOsc.ar(100, mul: 0.5, add: 0.5) * LFDNoise3.kr(0.35, 0.5, 0.5);
		sig = sig + (am * 0.15);
		Out.ar([100, 101], sig * 6)
	}).add;

	SynthDef(\effects, {|revMul = 1, hpMul = 1, lpMul = 1, bpMul = 1, midWeight = 0, normalOutMul = 0, weightedOutMul = 1|
		var sig, rev, dist, filter, hp, lp, bp, env, mid, side, normalOut, weightedOut;
		sig = In.ar([100, 101]);
		rev = JPverb.ar(sig, 20, earlyDiff: 1) * revMul;
		sig = sig + rev;
		hp = HPF.ar(sig, 2000) + (sig * 0.1);
		lp = LPF.ar(sig, 500) + (sig * 0.1);
		bp = BPF.ar(sig, 1500) + (sig * 0.1);
		sig = (hp * hpMul) + (lp * lpMul) + (bp * lpMul);
		env = EnvGen.kr(Env([0, 1, 1, 0], [~tempo, ~tempo, ~tempo]), doneAction: 2);
		sig = sig * env;
		normalOutMul = Out.ar(0, sig);
	}).add;
	~layers = Task ({
		loop{
			//first layer
			~inputFreq = ~spectrumGen.(~freq, 0);
			(
				~multiVArr = ~multiV.(
					input: ~inputFreq,
					vibrMax: 10,
					switchFreq: 2,
					nvoice: 3,
					stepFreq: 1,
					lowLim: 20,
					uppLim: 20000,
					gain: 2,
					curve: 1,
					switchAmp: 2,
					slopeAmp: 2,
					directionAmp: 0,
					widthGen: 1,
					widthPan: 0.6,
					switchPan: 0
			));
			a = Synth(\effects, [revMul: 0.5]);
			x = SynthDef(\splitter1, ~multiVDef.func).play;
			(~tempo / 2).wait;
			//second layer
			~inputFreq = ~spectrumGen.(~freq, 1);
			(
				~multiVArr = ~multiV.(
					input: ~inputFreq,
					vibrMax: 10,
					switchFreq: 2,
					nvoice: 3,
					stepFreq: 1,
					lowLim: 20,
					uppLim: 20000,
					gain: 0.4,
					curve: 1,
					switchAmp: 2,
					slopeAmp: 2,
					directionAmp: 0,
					widthGen: 1,
					widthPan: 0.1,
					switchPan: 0
			));
			y = SynthDef(\splitter2, ~multiVDef.func).play;
			(~tempo / 2).wait;
			//third layer
			~inputFreq = ~spectrumGen.(~freq, 7);
			(
				~multiVArr = ~multiV.(
					input: ~inputFreq,
					vibrMax: 30,
					switchFreq: 0,
					nvoice: 2,
					stepFreq: 10,
					lowLim: 20,
					uppLim: 20000,
					gain: 0.0000000001,
					curve: 0,
					switchAmp: 0,
					slopeAmp: 2,
					directionAmp: 0,
					widthGen: 1,
					widthPan: 0.3,
					switchPan: 0
			));
			z = SynthDef(\splitter3, ~multiVDef.func).play;
			(~tempo / 2).wait;
	}}).play
}
).play
)
