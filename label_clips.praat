# label_clips.praat
# Facilitates annotation of segment boundaries and/or transcriptions of clips
# designed to be compatible with Yi Xu's _TimeNormalize.praat

# released under LGPL 
# by Lucien Carroll AUG2013 

# The script assumes:
#	- A set of WAV format clipped files all in a single directory
#	- Each clip file has one utterance, with the file name indicative of the content
# The segment boundary guesser works best if all the clips in the directory are 
# 	- of the same utterance type
#	- by the same speaker
# 	- and the 'minf0' and 'maxf0' are set to match the actual distribution of pitch
# But the segment boundary guesser is not very accurate anyway.



minf0 = 70
maxf0 = 500
suffix$ = ".label"

beginPause ("Press [Continue] when ready")
	optionMenu ("Directory", 1)
		option (defaultDirectory$)
		option (shellDirectory$)
		option ("Other")
	optionMenu ("Mode", 1)
		option ("Check")
		option ("Insert")
		option ("Overwrite")
		option ("Recode")
		option ("Clip")
	sentence ("Suffix (for annotations)", suffix$)
	integer ("Use channel (0=all)", 0)
	positive ("Initial file", 1)
finished = endPause ("Continue", 1)

if directory$ = "Other"
	directory$ = chooseDirectory$ ("Choose the directory of clips")
endif
directory$ = directory$ - "/" + "/"

if mode$ = "Clip"
	beginPause ("Choose clipping settings")
		optionMenu ("Segment index", 1)
			option ("Left-to-right")
			option ("Right-to-left")
		optionMenu ("Segment labels", 1)
			option ("Extracted")
			option ("Collapsed")
		sentence ("Segment regex", "[AEIOUaeiou]")
		sentence ("Segment suffix", suffix$)
	endPause ("Continue",1)
elsif mode$ = "Recode"
	printline Ready
else
	beginPause ("Choose boundaries settings")
		boolean ("Guess boundaries", 1)
		boolean ("Check each", 1)
		positive ("Minf0", 'minf0')
		positive ("Maxf0", 'maxf0')
	endPause ("Continue", 1)
endif

Create Strings as file list... list 'directory$'*.wav
numberOfFiles = Get number of strings
if !numberOfFiles
	Create Strings as file list... list 'directory$'*.WAV
	numberOfFiles = Get number of strings
endif
if !numberOfFiles
	exit There are no sound files in the folder!
else
	Write to raw text file... 'directory$'FileList.txt
endif

for current_file from initial_file to numberOfFiles
	select Strings list
	fileName$ = Get string... current_file

	echo Opening 'fileName$' 
	call Labeling "'fileName$'"
endfor

select Strings list
Remove

echo Complete!

###############
### Procedures ###

procedure Labeling file_name$ file_extension$
	if use_channel = 0
		wav = Read from file... 'directory$''file_name$'
	else
		wav0 = Read from file... 'directory$''file_name$'
		wav = Extract one channel... use_channel
	endif
	name$ = file_name$ - ".wav" - ".WAV"
	labelfile$ = "'directory$''name$''suffix$'"
	if fileReadable (labelfile$)
		grid = Read from file... 'labelfile$'
	else
		printline No file found: 'labelfile$'
		grid = To TextGrid... "words targets" 
		Set interval text... 2 1 'name$'
	endif
	tier1$ = Get tier name... 1

	if mode$ = "Overwrite"
		if tier1$ = "peaks"
			Remove tier... 1
			tier1$ = Get tier name... 1
		endif
		if tier1$ = "segs"
			Remove tier... 1
		endif
	endif

	plus wav
	if mode$ = "Check" and (tier1$ = "segs" or tier1$ = "peaks")
		printline Assuming 'name$' already has segment labels
	elsif mode$ = "Recode"
		printline Skipping segmentation
	elsif mode$ = "Clip"
		printline Skipping segmentation
	else
		call Guess_segs
	endif		
	
	if mode$ = "Recode"
		printline Recoding 'name$' and removing peaks tiers
		select grid
		tier1$ = Get tier name... 1
		while tier1$ = "peaks"
			Remove tier... 1
			tier1$ = Get tier name... 1
		endwhile
		finished = 3
		next_file = current_file + 1
	elsif mode$ = "Clip"
		printline Clipping segments from 'name$'
		call getTierByName 'grid' segs
		tierN = getTierByName.found
		if tierN = 0
			printline Segs tier not found
		else
			call Clip_segs 'tierN'
		endif
		finished = 3
		next_file = current_file + 1
	else
		select wav
		plus grid
		Edit
	
		finished = 0
		next_file = current_file + 1
		if check_each
			beginPause ("Press Finish to exit")
				comment ("The current file is 'current_file'")
				integer ("Next file:", 'next_file')
			finished = endPause ("Finish", "Back", "Continue", 3)
		else
			finished = 3
		endif
	endif
	
	select grid
	Write to text file... 'directory$''name$''suffix$'
	Remove

	select wav
	if use_channel > 0
		plus wav0
	endif
	Remove

	nocheck select IntensityTier delta
	nocheck Remove

	if finished = 1
		echo Current file number is 'current_file'.
		exit
	elsif finished = 2
		current_file = max(current_file - 2, 0)
	elsif finished = 3
		current_file = next_file - 1
	endif
endproc

procedure Clip_segs tierSeg
	select grid
	nints = Get number of intervals... tierSeg
	clipped = 0
	for intIdxN from 1 to nints
		if segment_index = 2
			# segment right-to-left
			intIdx = nints - intIdxN + 1
		else
			# segment left-to-right
			intIdx = intIdxN
		endif
		#printline 'intIdx'
		select grid
		t_i = Get start point... tierSeg intIdx
		t_f = Get end point... tierSeg intIdx
		seg$ = Get label of interval... tierSeg intIdx
		if (index_regex( seg$, segment_regex$))
			clipped = clipped + 1
			call getTierByName 'grid' words
			words$ = Get label of interval... getTierByName.found 1
			call getTierByName 'grid' targets
			if getTierByName.found = 0
				call getTierByName 'grid' gloss
			endif
			lab$ = Get label of interval... getTierByName.found 1
			seg_label_file$ = "'directory$'seg'clipped'-'seg$'-'name$''segment_suffix$'"
			seg_wav_file$ =  "'directory$'seg'clipped'-'seg$'-'name$'.wav"
			select wav
			wav_part = Extract part... t_i t_f rectangular 1.0 no
			Write to WAV file... 'seg_wav_file$'

			if segment_labels$ = "Extracted"
				select grid
				grid_part = Extract part... t_i t_f no
				Write to text file... 'seg_label_file$'
			else
				# Condensed
				select wav_part
				grid_part = To TextGrid... seg
				Set interval text... 1 1 'seg$'-'lab$'
				Write to text file... 'seg_label_file$'
			endif
			select wav_part 
			plus grid_part
			Remove

			fileappend "'directory$'segs.csv" seg'clipped'-'seg$'-'name$''tab$''t_i''tab$''t_f''tab$''clipped''tab$''seg$''tab$''words$''tab$''lab$''newline$'
		endif
	endfor	
endproc

procedure Guess_segs

	wav = selected("Sound")
	grid = selected("TextGrid")

	select wav
	pitch0 = To Pitch... 0 minf0 maxf0
	pitch = Interpolate
	select pitch0
	Remove
	
	select pitch
	nframes = Get number of frames

	select grid
	Insert interval tier... 1 voiced

	prev = undefined
	for idx from 1 to nframes
		select pitch
		p = Get value in frame... 'idx' Hertz
		t = Get time from frame number... 'idx'
		select grid
		if p = undefined & prev != undefined
			Insert boundary... 1 t
		elsif prev = undefined & p != undefined
			Insert boundary... 1 t
		endif
		prev = p
	endfor

	select grid
	Duplicate tier... 1 1 segs
	Insert point tier... 1 peaks

	if guess_boundaries
		nints = Get number of intervals... 3
		for intIdx from 1 to nints
			select grid
			t1 = Get start point... 3 intIdx
			t2 = Get end point... 3 intIdx
			select pitch
			p = Get value at time... (t1+t2)/2 Hertz linear
			if p != undefined
				if t2 - t1 > 0.1
					select wav
					piece = Extract part... t1 t2 rectangular 1 yes
					call intensityBreak piece grid
				else
					select grid
					Insert point... 1 (t1+t2)/2 V
				endif
			endif		
		endfor
	endif

	select grid
	Remove tier... 3
		
	select pitch
	Remove

	select wav
	plus grid

endproc

procedure intensityBreak piece grid

	printline Making intensity gradient

	select piece
	start = Get start time
	end = Get end time

	select piece
	call deltaIntensity piece
	delta = deltaIntensity.result

	printline Smoothing intensity gradient

	call smoothIntenTier delta 3
	diffIntenTier = smoothIntenTier.result

	printline Labeling peaks and valleys

	select piece
	filtered = Filter (pass Hann band)... minf0 5000 100
	Pre-emphasize (in-line)... minf0
	inten = To Intensity... minf0 0.0 yes
	intenTier = Down to IntensityTier
	call smoothIntenTier intenTier 5
	select intenTier
	plus inten
	Remove

	intenTier = smoothIntenTier.result	
	select intenTier
	ampTier = To AmplitudeTier
	flatPiece = To Sound (pulse train)... 44100 2000
	inten = To Intensity... minf0 0.0 yes

	select piece
	piecePitch = To Pitch... 0 minf0 maxf0	
	pp = To PointProcess
	vuv = To TextGrid (vuv)... 0.02 0.01

	select pp
	plus ampTier
	Remove


	select inten

	peakTier = To IntensityTier (peaks)
	npeaks = Get number of points
	if npeaks > 0
		for pIdx from 1 to npeaks
			select peakTier
			t = Get time from index... pIdx
			select piecePitch
			p = Get value at time... t Hertz linear
			select grid
			if p = undefined
				Insert point... 1 t C
			else
				Insert point... 1 t V
			endif
		endfor
	else
		select piecePitch
		p = Get value at time... (start+end)/2 Hertz linear
		select grid
		if p = undefined
			Insert point... 1 (start+end)/2 C
		else
			Insert point... 1 (start+end)/2 V
		endif
	endif
	select peakTier
	Remove

	select inten
	valleyTier = To IntensityTier (valleys)
	nvalleys = Get number of points
	for pIdx from 1 to nvalleys
		select valleyTier
		tc = Get time from index... pIdx
		select intenTier
		intenC = Get value at time... tc
		select grid
		iv = Get nearest index from time... 1 tc
		tv = Get time of point... 1 iv
		select intenTier
		intenV = Get value at time... tv
		;; printline 'iv' 'tv' 'intenV' 'pIdx' 'tc' 'intenC'
		if (intenV - intenC) > 0.9
			select grid
			Insert point... 1 tc C
		endif
	endfor
	select valleyTier
	Remove

	printline Finding break points

	select grid
	Duplicate tier... 1 4 peaks
	nPts = Get number of points... 4
	for pIdx from 2 to nPts
		select grid
		tHere = Get time of point... 4 pIdx
		hereIdx = Get nearest index from time... 1 tHere
		tPrev = Get time of point... 1 (hereIdx - 1)

		select vuv
		vcHereIdx = Get interval at time... 1 tHere
		vcHere$ = Get label of interval... 1 vcHereIdx
		vcPrevIdx = Get interval at time... 1 tPrev
		vcPrev$ = Get label of interval... 1 vcPrevIdx
		tvuv = Get start point... 1 vcHereIdx

		select grid
		here$ = Get label of point... 1 hereIdx
		prev$ = Get label of point... 1 (hereIdx - 1)
		;; printline 'prev$' 'here$' 'tHere'
		if (tPrev >= start) and (tHere <= end)
			if (here$ = "V") and (prev$ = "C")
				tPrev = max(tvuv, tPrev)
				call maxValue diffIntenTier tPrev tHere
				select grid
				Insert boundary... 2 'maxValue.tmax'
			elsif (here$ = "C") and (prev$ = "V")
				;;if (tvuv > tPrev)
				;;	tHere = tvuv
				;;endif
				call maxValue diffIntenTier tPrev tHere
				select grid
				Insert boundary... 2 'maxValue.tmax'		
			endif			
		endif
	endfor
	nPts = Get number of points... 4
	for pIdx from 2 to nPts
		tHere = Get time of point... 4 pIdx
		hereIdx = Get nearest index from time... 1 tHere
		tPrev = Get time of point... 1 (hereIdx - 1)
		here$ = Get label of point... 1 hereIdx
		prev$ = Get label of point... 1 (hereIdx - 1)
		if (tPrev >= start) and (tHere <= end)
			if (here$ = "V") and (prev$ = "V")
				select intenTier
				intensHere = Get value at time... tHere
				intensPrev = Get value at time... tPrev
				;; printline 'prev$' 'intensPrev' 'here$' 'intensHere'
				select grid
				if intensHere > intensPrev
					Remove point... 1 (hereIdx-1)
				else
					Remove point... 1 hereIdx
				endif
			elsif (here$ = "C") and (prev$ = "C")
				select grid
				Remove point... 1 hereIdx
			endif
		endif
	endfor

	select grid
	Remove tier... 4	

	select intenTier
	plus inten
	plus piece
	plus piecePitch
	plus filtered
	plus diffIntenTier
	plus flatPiece
	plus vuv
	;;plus delta
	Remove

	select delta
	plus wav
	Edit
	

endproc
		
procedure flattenIntenTier intenTier
	select intenTier
	nPts = Get number of points
	
	for pt from 2 to (nPts-1)
		last = Get value at index... (pt-1)
		here = Get value at index... pt
		next = Get value at index... (pt+1)
		if (abs(here-next) < 1.0 and abs(here-last) < 1.0)
			t = Get time from index... pt
			Remove point near... t
			Add point... t (0.1*next + 0.8*here + 0.1*last)
		endif
	endfor
endproc

procedure smoothIntenTier .intenTier .iter
	select .intenTier
	.res0 = Copy... intenTier res0
	.res1 = Copy... intenTier res1
	.nPts = Get number of points
	.start = Get time from index... 2
	.end = Get time from index... (.nPts-1)

	for .idx from 1 to .iter
		select .res1
		Remove points between... .start .end
		select .res0
		last = Get value at index... 1
		here = Get value at index... 2
		for pt from 2 to (.nPts-1)
			select .res0
			next = Get value at index... (pt+1)
			;; printline 'pt' 'last' 'here' 'next'
			t = Get time from index... pt
			select .res1
			Add point... t (0.2*next + 0.6*here + 0.2*last)
			last = here
			here = next
		endfor
		.swap = .res0
		.res0 = .res1
		.res1 = .swap
	endfor
	select .res1
	Remove
	.result = .res0
endproc

;;int = selected("IntensityTier")
;;call smoothIntenTier int 50

procedure maxDiff .tier .start .end
	.max = 0
	.tmax = (.start + .end)/2

	select .tier
	.nPts = Get number of points
	for .pIdx from 2 to .nPts
		tPrev = Get time from index... (.pIdx - 1)
		tHere = Get time from index... .pIdx
		if (tPrev > .start) and (tHere < .end)
			vPrev = Get value at index... (.pIdx - 1)
			vHere = Get value at index... .pIdx
			.diff = abs(vPrev - vHere)
			;; printline 'tHere' 'vPrev' 'vHere' '.diff'
			if .diff > .max
				.tmax = (tPrev + tHere) / 2
				.max = .diff
			endif
		endif
	endfor
endproc

procedure maxValue .tier .start .end
	.max = 0
	.tmax = (.start + .end)/2
	
	select .tier
	.init = Get high index from time... .start
	.final = Get low index from time... .end
	for .idx from .init to .final
		.val = Get value at index... .idx
		if .val > .max
			.tmax = Get time from index... .idx
			.max = .val
		endif
	endfor
endproc
	

procedure deltaIntensity .piece

	select .piece
	.piece = Filter (pre-emphasis)... 50

	printline 'tab$'Initializing intensity bands
	select .piece
	.filtered = Filter (pass Hann band)... 70 500 100
	.inten = To Intensity... maxf0 0.0 yes
	.intenTier0 = Down to IntensityTier
	call smoothIntenTier .intenTier0 5
	.intenTier1 = smoothIntenTier.result
	select .filtered
	plus .inten
	plus .intenTier0
	Remove

	select .piece
	.filtered = Filter (pass Hann band)... 500 1000 100
	.inten = To Intensity... maxf0 0.0 yes
	.intenTier2 = Down to IntensityTier
	;;call smoothIntenTier .intenTier0 3
	;;.intenTier2 = smoothIntenTier.result
	select .filtered
	plus .inten
	;;plus .intenTier0
	Remove

	select .piece
	.filtered = Filter (pass Hann band)... 1000 2500 100
	.inten = To Intensity... maxf0 0.0 yes
	.intenTier3 = Down to IntensityTier
	;;call smoothIntenTier .intenTier0 3
	;;.intenTier3 = smoothIntenTier.result
	select .filtered
	plus .inten
	;;plus .intenTier0
	Remove

	select .piece
	.filtered = Filter (pass Hann band)... 2500 5000 100
	.inten = To Intensity... maxf0 0.0 yes
	.intenTier4 = Down to IntensityTier
	;;call smoothIntenTier .intenTier0 3
	;;.intenTier4 = smoothIntenTier.result
	select .filtered
	plus .inten
	;;plus .intenTier0
	Remove

	select .intenTier1
	.delta = Copy... delta
	.npts = Get number of points
	.start = Get time from index... 3
	.end = Get time from index... (.npts-2)
	Remove points between... .start .end

	# initialize
	printline 'tab$'Combining components...
	.idx = 3
	.t1 = Get time from index... (.idx-2)
	.t2 = Get time from index... (.idx-1)
	.t3 = Get time from index... .idx
	.t4 = Get time from index... (.idx+1)
	select .intenTier1
	.int1_1 = Get value at time... .t1
	.int1_2 = Get value at time... .t2
	.int1_3 = Get value at time... .t3
	.int1_4 = Get value at time... .t4
	select .intenTier2
	.int2_1 = Get value at time... .t1
	.int2_2 = Get value at time... .t2
	.int2_3 = Get value at time... .t3
	.int2_4 = Get value at time... .t4
	select .intenTier3
	.int3_1 = Get value at time... .t1
	.int3_2 = Get value at time... .t2
	.int3_3 = Get value at time... .t3
	.int3_4 = Get value at time... .t4
	select .intenTier4
	.int4_1 = Get value at time... .t1
	.int4_2 = Get value at time... .t2
	.int4_3 = Get value at time... .t3
	.int4_4 = Get value at time... .t4

	for .idx from 3 to (.npts-2)
		;; printline '.idx' '.npts'
		if (.idx mod 100 = 0)
			printline 'tab$''.idx' of '.npts'
		endif
		select .intenTier1
		.t3 = Get time from index... .idx
		.t5 = Get time from index... (.idx+2)
		.int1_5 = Get value at time... .t5
		select .intenTier2
		.int2_5 = Get value at time... .t5
		select .intenTier3
		.int3_5 = Get value at time... .t5
		select .intenTier4
		.int4_5 = Get value at time... .t5
		.d1 = sqrt((.int1_3 - .int1_1)^2 + (.int2_3 - .int2_1)^2 + (.int3_3 - .int3_1)^2 + (.int4_3 - .int4_1)^2)
		.d2 = sqrt((.int1_3 - .int1_2)^2 + (.int2_3 - .int2_2)^2 + (.int3_3 - .int3_2)^2 + (.int4_3 - .int4_2)^2)
		.d3 = sqrt((.int1_2 - .int1_4)^2 + (.int2_2 - .int2_4)^2 + (.int3_2 - .int3_4)^2 + (.int4_2 - .int4_4)^2) 
		.d4 = sqrt((.int1_4 - .int1_3)^2 + (.int2_4 - .int2_3)^2 + (.int3_4 - .int3_3)^2 + (.int4_4 - .int4_3)^2)
		.d5 = sqrt((.int1_5 - .int1_3)^2 + (.int2_5 - .int2_3)^2 + (.int3_5 - .int3_3)^2 + (.int4_5 - .int4_3)^2)
		.d = .d1 + .d2 + .d3 + .d4 + .d5 + .int1_3/2
		select .delta
		Add point... .t3 .d

		# move down
		select .intenTier1
		.int1_1 = .int1_2
		.int1_2 = .int1_3
		.int1_3 = .int1_4
		.int1_4 = .int1_5
		select .intenTier2
		.int2_1 = .int2_2
		.int2_2 = .int2_3
		.int2_3 = .int2_4
		.int2_4 = .int2_5
		select .intenTier3
		.int3_1 = .int3_2
		.int3_2 = .int3_3
		.int3_3 = .int3_4
		.int3_4 = .int4_5
		select .intenTier4
		.int4_1 = .int4_2
		.int4_2 = .int4_3
		.int4_3 = .int4_4
		.int4_4 = .int4_5
	endfor

	select .intenTier1
	plus .intenTier2
	plus .intenTier3
	plus .intenTier4
	plus .piece
	Remove

	.result = .delta
endproc

procedure getTierByName .grid .name$
	.found = 0
	select .grid
	numTiers = Get number of tiers
	for .tierN from 1 to numTiers
		if .found = 0
			.tier$ = Get tier name... '.tierN'
			if .tier$ = .name$
				.found = .tierN
			endif
		endif
	endfor
	if .found = 0
		printline These are not the tiers you are looking for: '.name$'
	endif
endproc
