/*
Here are just some notes for me, in the case I want to modify the patch with other ratios.

[ALL SINE-WAVE FM NON-REDUCIBLE CARRIER/MODULATOR RATIOS]

Side-bands falling against each other after being reflected (after phase-invertion):
1/1, 2/1, 3/1, 4/1  (carrier: 0-300 Hz) (N:1 ratios)
1:2, 3:2, 5:2, 7:2  (carrier: 0-300 Hz) (N:2 ratios)

Normal form  (carrier is the fundamental of the spectrum produced) ratios:
1:1 1:2 1:3 1:4 1:5 1:6 1:7 1:8 1:9 farey serie harmonic (1:N ratios)
2:9 2:7 3:8 2:5 2:7 4:9 farey serie inharmonic
*/

FIRST BOOT THE SERVER HERE BY EVALUATING HERE


(
// Here just allocating memory and booting the audio server for the synthesis
s.options.memSize_(2.pow(20));
s.reboot
);


THEN EVALUATE INSIDE HERE TO MAKE THE SYNTHESIS START

(
x = Task({
	a = Bus.control(s, 1);
	a.set(1);
	b = Bus.control(s, 1);
	b.set(1);
	c = Bus.control(s, 1);
	c.set(1);
	d = Bus.control(s, 1);
	d.set(1);

	// GLOBAL VARIABLES
	~tempo = 15; // Length of each sound in seconds
	~freqBeg = 50; // Init frequency


	// SPAT STEREO FUNCTION:
	// This function creates an array of predicted frequencies
	~spatStereoFunc = {|carrier, ratioC, ratioM|
		var nsides = 6, filterFreqArr = Array.newClear, modulator;
		carrier = carrier * ratioC; // Carrier frequency calculation
		modulator = carrier * ratioM; // Modulator frequency calculation
		(nsides/2).asInteger.do({|item, index|
			filterFreqArr = filterFreqArr.add(carrier + (modulator * (index + 1))); // Carrier + modulator bands
			filterFreqArr = filterFreqArr.add(carrier - (modulator * (index + 1))); // Carrier - modulator bands
		});
		filterFreqArr = filterFreqArr.abs.sort}; // Array of frequencies, re-ordered in ascending order

	~filterFreqArr = ~spatStereoFunc.value(carrier: 40, ratioC: 1, ratioM: 1); // initialise the first array of frequencies
	// SPLITTER FUNCTION (AND GENERATION OF NEXT FUNDAMENTAL)
	// This function, given a carrier frequency, calculates the first couple of side-bands
	// In particular sets the frequency carrier + modulator as the next fundamental. If it is not in the range 0-70 Hz, this frequency is divided by two till it is in that range.

	~splitterFunc = {|freq|
		var modulatorFreq, firstFreq, secondFreq, ratioC = 1, ratioM;
		ratioM = 2.rrand(19); // Random generation of a N:1 ratios (side-bands falling against each other)
		~modulatorFreq = freq * ratioM / ratioC; // modulator frequency calculation
		~firstFreq = freq + ~modulatorFreq; // carrier + modulator side-band
		secondFreq = (freq - ~modulatorFreq).abs; // carrier - modulator side-band
		while ({~firstFreq > 70}, {~firstFreq = ~firstFreq / 2}); // If it is not in the range 0-70 Hz, this frequency is divided by two till it is in that range.
		~firstFreq.postln // Post the frequency of the fundamental in the post window, just for monitorning
	};

	~carrier = ~freqBeg; // Carrier with the init frequency
	~splitterFunc.(~carrier); // Init
	"fatto".postln;

	SynthDef(\synth, {|carrierFreq, ratioC, ratioM, amp, triFreq = 0.2, masterVolume = 0.0, extraRange1 = 0.0, extraRange2 = 0.0, extraRange3 = 0.0|
		var sig, carrier, modulator, env, sideLim, sideStart, sideEnd, sideDur, lfoFilter1, lfoStartFreq1, triMul1, triAdd1, triPhase1, lfoFilter2, lfoStartFreq2, triMul2, triAdd2, triPhase2, lfoFilter3, lfoStartFreq3, triMul3, triAdd3, triPhase3, extrLFO11, extrLFO12, extrLFO21, extrLFO22, extrLFO31, extrLFO32, nSidesUpDown = 5, filterArr, nsides = 6, filterFreqArr = Array.newClear, filterArray = Array.newClear, zerocounter = 0, rev, revMul = 1;

		// CARRIER AND MODULATOR CALCULATION
		carrier = carrierFreq * ratioC;
		modulator = carrierFreq * ratioM;

		// CALCULATE SOME VARIABLES (USEFUL FOR AMPLITUDE VALUES OF THE MODULATOR)
		sideLim = 400;
		sideStart = [0, sideLim].choose; // randomly choose between 0 and side limit
		if (sideStart == 0) {sideEnd = sideLim} {sideEnd = 0};
		if (sideEnd > sideLim) {sideEnd = sideLim; sideStart = sideStart - (sideEnd - sideLim)};

		// CORE FM SYNTHESIS PART + ENVELOPE
		/* Here the two arrays (in the envelope for the amplitude of the modulator) indicates values points fof the amplitude and time points to reach linearly the next point.
		For example: Values array [3,1,2], time points array [2, 4]. It means that it starts from 3, it takes 2 seconds to reach value 1 and then 4 seconds to reach value 2
		*/

		sig = SinOsc.ar(
			carrier + SinOsc.ar((modulator), 0, EnvGen.kr(Env(
				Array.fill(nSidesUpDown + 1, {|item| if (item.even == true) {sideStart} {sideEnd}}), // Values array
				Array.fill(nSidesUpDown, {~tempo * (2 / nSidesUpDown)})), doneAction: 2)), // Time points array (in seconds)
			mul: 1 * amp
		);

		// LFOs TO CONTROL THE CUT-OFF FREQUENCIES OF THE NOTCH FILTERS
		extrLFO11 = 50 - extraRange1;
		extrLFO12 = 500 + extraRange1;
		extrLFO21 = 500 - extraRange2;
		extrLFO22 = 2000 + extraRange2;
		extrLFO31 = 2000 - extraRange3;
		extrLFO32 = 10000 + extraRange3;
		// This part can be written more compact but like this is clearer to read
		lfoStartFreq1 = extrLFO11.rrand(extrLFO12); // Take a random value between extrLFO11 extrLFO12 for the starting frequency
		triMul1 = (extrLFO11 - extrLFO12).abs / 2; // Range
		triAdd1 = extrLFO12 - triMul1; // Offset to range
		triPhase1 = lfoStartFreq1.linlin(extrLFO11, extrLFO12, -1, 1); // Map linearly the starting frequency to the init phase offset
		lfoFilter1 = LFTri.kr(freq: triFreq, iphase: triPhase1, mul: triMul1, add: triAdd1); // LFO
		lfoStartFreq2 = extrLFO21.rrand(extrLFO22);
		triMul2 = (extrLFO21 - extrLFO22).abs / 2;
		triAdd2 = extrLFO22 - triMul2;
		triPhase2 = lfoStartFreq2.linlin(extrLFO21, extrLFO22, -1, 1);
		lfoFilter2 = LFTri.kr(freq: triFreq, iphase: triPhase2, mul: triMul2, add: triAdd2);
		lfoStartFreq3 = extrLFO31.rrand(extrLFO32);
		triMul3 = (extrLFO31 - extrLFO32).abs / 2;
		triAdd3 = extrLFO32 - triMul3;
		triPhase3 = lfoStartFreq3.linlin(extrLFO31, extrLFO32, -1, 1);
		lfoFilter3 = LFTri.kr(freq: triFreq, iphase: triPhase3, mul: triMul3, add: triAdd3);

		// ACTUAL FILTERING
		// Notch filtering with cut-off frequencies controlled by 3 LFOs
		sig = BPeakEQ.ar(sig, lfoFilter1, 0.05, -60);
		sig = BPeakEQ.ar(sig, lfoFilter2, 0.05, -60);
		sig = BPeakEQ.ar(sig, lfoFilter3, 0.05, -60);


		// PANNING ALGORITHM
		// Each of the bands predicted by the ~spatStereoFunc function (~filterFreqArr array) are "isolated" by a band-pass filter and given a different place in the stereo field with higher concentration of bass frequencies at the center.

		~filterFreqArr.collect {|item, index| if (item.abs <  25) {~filterFreqArr[index] = 0; zerocounter = zerocounter + 1}};
		zerocounter.do {~filterFreqArr.remove(0)};
		filterArray = Array.fill(~filterFreqArr.size, {|item|
			var filter, pos;
			filter = BPF.ar(sig, ~filterFreqArr[item], rq: 0.1);
			pos = ~filterFreqArr[item].linlin(30, ~filterFreqArr[~filterFreqArr.size-1], 0, 1);
			if (item.even == false) {pos = pos.neg};
			Pan2.ar(sig, pos);
		});

		// SUMMING ALL THE SIGNALS + LITTLE OF REVERB
		sig = filterArray.sum / filterArray.size * 1.5;
		rev = JPverb.ar(sig, 20, earlyDiff: 1) * revMul;
		sig = sig + rev;

		// ENVELOPE
		env = EnvGen.kr(Env([0, 0.1, 0], [~tempo, ~tempo]), doneAction: 2); // Simple fade-in and fade-out
		sig = sig * env;

		// ROUTING TO THE FIRST TWO CHANNEL OF THE AUDIO INTERFACE
		Out.ar(0, sig * 2.0 * masterVolume);

	}).add;
	"fatto".postln;


	// LARGE-SCALE TIME ORGANISATION
	/*
	Here two synths (of the synth we've seen before) are created at the same moment. Each of them has a different spectrum (depending on the functions seen before that generate the harmony) and gain (a random number between 0.1 and 0.2).
	After waiting "~tempo" seconds, other two synths start. This whole process is repeated 4 times.
	*/

	~synth = {

		// This part could have been written in a more compact way. But I prefer to leave it like this, just in the case I want to apply something specific in any of the 4 parts of this part
		loop{
			var freqArr, nSynthPerGroup, synthArr1 = Array.newClear, synthArr2 = Array.newClear, synthArr3 = Array.newClear, synthArr4 = Array.newClear;
			freqArr = /*~freqBeg */ ~firstFreq * [1, 2, 4, 6, 9, 11, 13, 14, 15, 17, 19, 20]; // Harmonic spectrum generation
			nSynthPerGroup = 2; // Two synths at the same time
			freqArr = freqArr.reshape(4, nSynthPerGroup);
			nSynthPerGroup.do {|item| synthArr1[item].free};
			nSynthPerGroup.do {|item|
				~carrier = freqArr[0][item];
				~splitterFunc.(~carrier);
				~filterFreqArr = ~spatStereoFunc.value(~carrier, 1, 1);
				synthArr1 = synthArr1.add(Synth(\synth, [carrierFreq: ~carrier, modulatorFreq: ~modulatorFreq, ratioC: 1, ratioM: 1, amp: 0.1.rrand(0.2)]).map(\masterVolume, a, \extraRange1 , b, \extraRange2, c, \extraRange3, d));
			};
			1.postln;
			(~tempo).wait;

			nSynthPerGroup.do {|item| synthArr2[item].free};
			nSynthPerGroup.do {|item|
				~carrier = freqArr[1][item];
				~splitterFunc.(~carrier);
				~filterFreqArr = ~spatStereoFunc.value(~carrier, 1, 1);
				synthArr2 = synthArr2.add(Synth(\synth, [carrierFreq: ~carrier, modulatorFreq: ~modulatorFreq, ratioC: 1, ratioM: 1, amp: 0.1.rrand(0.2)]).map(\masterVolume, a, \extraRange1 , b, \extraRange2, c, \extraRange3, d));
			};
			2.postln;
			(~tempo).wait;

			nSynthPerGroup.do {|item| synthArr3[item].free};
			nSynthPerGroup.do {|item|
				~carrier = freqArr[2][item];
				~splitterFunc.(~carrier);
				~filterFreqArr = ~spatStereoFunc.value(~carrier, 1, 1);
				synthArr3 = synthArr3.add(Synth(\synth, [carrierFreq: ~carrier, modulatorFreq: ~modulatorFreq, ratioC: 1, ratioM: 1, amp: 0.1.rrand(0.2)]).map(\masterVolume, a, \extraRange1 , b, \extraRange2, c, \extraRange3, d));
			};
			3.postln;
			(~tempo).wait;

			nSynthPerGroup.do {|item| synthArr4[item].free};
			nSynthPerGroup.do {|item|
				~carrier = freqArr[3][item];
				~splitterFunc.(~carrier);
				~filterFreqArr = ~spatStereoFunc.value(~carrier, 1, 1);
				synthArr4 = synthArr4.add(Synth(\synth, [carrierFreq: ~carrier, modulatorFreq: ~modulatorFreq, ratioC: 1, ratioM: 1, amp: 0.1.rrand(0.2)]).map(\masterVolume, a, \extraRange1 , b, \extraRange2, c, \extraRange3, d));
			};
			4.postln;
			(~tempo).wait;
	}};
	"fatto".postln;

	// EVEN LARGER TIME ORGANISATION
	// The whole process seen before start while the previous is running (after "~tempo" seconds). There's basically a fade-out of one process while the previous is fading-in.

	Task ({
		Task ({
			~synth.value;
		}).play;
		(~tempo).wait;

		Task ({
			~synth.value;
		}).play;
		(~tempo).wait;
	}).play

}).play

)