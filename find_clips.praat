# find_clips.praat
# This script uses cross-correlation to find audio clips inside a long sound file
# If your audio clips are just clipped (not filtered or resampled), then
# searching for exact byte matches in the WAV data will work and be faster
#
# released under LGPL 
# by Lucien Carroll MAY2014 

select all
nwav = numberOfSelected ("LongSound")
if nwav > 0
	wav = selected ("LongSound", -1)
	wavname$ = selected$ ("LongSound", -1)
else
	nwav = numberOfSelected ("Sound")
	if nwav > 0
		wav = selected ("Sound", -1)
		wavname$ = selected$ ("Sound", -1)
	else
		wav = 0
		wavname$ = "None"
	endif
endif

beginPause ("Press [Continue] when ready")
	optionMenu ("Directory", 1)
		option (defaultDirectory$)
		option (shellDirectory$)
		option ("Other")
	optionMenu ("Target", 1)
		option (wavname$)
		option ("Other")
	integer ("Use channel (0=all)", 0)
finished = endPause ("Continue", 1)

if directory$ = "Other"
	directory$ = chooseDirectory$ ("Choose the directory of clips")
endif
directory$ = directory$ - "/" + "/"

if target$ = "Other" or target$ = "None"
	filename$ = chooseReadFile$ ("Choose the container sound file")
	wav = Open long sound file... 'filename$'
	wavname$ = selected$ ( )
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

select wav
grid = To TextGrid... filename
for current_file from 1 to numberOfFiles
	select Strings list
	fileName$ = Get string... current_file

	call FindOffset 'fileName$'
endfor

select Strings list
Remove

#########################
####### Procedures ########

procedure FindOffset clip$
	printline Looking for 'clip$' in 'wavname$'
	clip_raw = Read from file... 'directory$''clip$'
	if use_channel = 0
		clip = clip_raw
	else
		clip = Extract one channel... 'use_channel'
		select clip_raw
		Remove
	endif

	select wav
	endtime = Get end time
	pieces = ceiling( endtime / 120 )
	select clip
	clip_dur = Get total duration
	for num from 1 to pieces
		select wav
		piece_num = Extract part... (num-1)*120 num*120+5 yes
		plus clip
		cc = Cross-correlate... "peak 0.99" zero
		cc_mean = Get root-mean-square... 0 0
		cc_max = Get maximum... 0 0 Sinc70
		t_max = Get time of maximum... 0 0 Sinc70
		printline 'cc_mean' 'cc_max' 't_max'
		if cc_max/cc_mean > 25
			printline Guessing it is here
			select grid
			Insert boundary... 1 't_max'
			intIdx = Get high interval at time... 1 't_max'
			Set interval text... 1 'intIdx' 'clip$'
			Insert boundary... 1 't_max'+'clip_dur'
		endif
		select piece_num
		plus cc
		Remove
	endfor
	select clip
	Remove
endproc
