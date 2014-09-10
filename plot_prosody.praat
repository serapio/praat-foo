# plot_prosody.praat
# Produces figures (optionally) showing:
#  - wave form
#  - intensity curve
#  - spectrogram
#  - pitch track
#  - annotations
#
# released under LGPL
# by Lucien Carroll AUG2014

wav$ = selected$ ("Sound")
label$ = selected$ ("TextGrid")

# defaults 
minf0 = 150
maxf0 = 300
margf0 = 25
window_width = 6.25
window_height = 3.0
margin = 0.3
plot_intensity = 0
plot_spectrogram = 0
half_plot = 0.5
use_vowel_filter = 0
whistled = 0
speckle = 1

Font size... 10 
title_plot = 0


Edit

editor TextGrid 'label$'
	if 1
		# autorun or not
		beginPause ("Press Continue when ready")
			comment ("Add labels and select the region of interest")
			positive ("minf0", minf0)
			positive ("maxf0", maxf0)
			positive ("margf0", margf0)
			positive ("window width", window_width)
			positive ("window height", window_height)
			positive ("margin", margin)
			boolean ("plot intensity", plot_intensity)
			boolean ("plot spectrogram", plot_spectrogram)
			# boolean ("use vowel filter", use_vowel_filter)
			# boolean ("whistled", whistled)
			boolean ("speckle", speckle)
		
		endPause ("Continue", 1)
	endif
sel_start = Get start of selection
sel_end = Get end of selection
Zoom to selection
endeditor

## Draw wave form ##
Select inner viewport... margin window_width-margin margin margin+0.3

editor TextGrid 'label$'
Draw visible sound... yes yes 0 0 no no no no
Close
endeditor
Draw inner box
if title_plot
	Text top... no 'label$'
endif

## Draw intensity ##
if plot_intensity
	Select inner viewport... margin window_width-margin margin+0.3 window_height*half_plot
	select Sound 'wav$'
	if use_vowel_filter
		Filter (pass Hann band)... maxf0+100 3500 100
	endif
	To Intensity... maxf0 0 yes
	intensity_max = Get maximum... sel_start sel_end Parabolic
	intensity_max = 5 * ceiling(intensity_max / 5)
	Draw... sel_start sel_end intensity_max-30 intensity_max no
	Draw inner box
	Text left... no Int (dB)
	One mark right... intensity_max-10 yes yes yes
	One mark right... intensity_max-20 yes yes yes

	Select inner viewport... margin window_width-margin window_height*half_plot window_height-margin
else
	Select inner viewport... margin window_width-margin margin+0.3 window_height-margin
endif

## Draw spectrogram ##
if plot_spectrogram
	Select inner viewport... margin window_width-margin margin+0.3 window_height*half_plot
	select Sound 'wav$'
	spec = To Spectrogram... 0.005 6000 0.002 20 Gaussian
	Paint... sel_start sel_end 0 0 100 yes 50 6 0 no
	Text left... no     	    F0 (Hz)
	One mark right... 3000 yes yes yes
	select spec
	Remove
	Select inner viewport... margin window_width-margin window_height*half_plot window_height-margin
else
	Select inner viewport... margin window_width-margin margin+0.3 window_height-margin
endif

## Draw pitch and text
if whistled and ( maxf0 < 1000 )
	minf0 = minf0 * 10
	maxf0 = maxf0 * 10
endif

select Sound 'wav$'

if whistled
	To Formant (burg)... 0 1 maxf0 0.025 50
	if speckle
		Speckle... sel_start sel_end maxf0 30 no
	else
		Draw...  sel_start sel_end maxf0 30 no
	endif
	Text left... no whistle F0 (Hz)
	One mark right... maxf0-200 yes yes yes
	One mark right... minf0 yes yes yes

	select TextGrid 'label$'
	Draw... sel_start sel_end yes no no
else
	To Pitch (ac)...  0 minf0 10 yes 0.03 0.25 0.01 0.35 0.14 maxf0
	plus TextGrid 'label$'
	if speckle
		Speckle separately... sel_start sel_end minf0 maxf0 yes yes no
	else
		Draw separately... sel_start sel_end minf0 maxf0 yes yes no
	endif
	Text left... no     	    F0 (Hz)
	One mark right... maxf0-margf0 yes yes yes
	One mark right... minf0+margf0 yes yes yes
endif
#Marks bottom... 2 yes no no
time_len = round( (sel_end - sel_start)*100 )/100
Text bottom... no 'time_len' s
Draw inner box

if whistled
	select Formant 'wav$'
else
	select Pitch 'wav$'
endif

if plot_intensity
	if use_vowel_filter
		plus Sound 'wav$'_band
		plus Intensity 'wav$'_band
	else
		plus Intensity 'wav$'
	endif
endif
Remove

# Reset viewport
Viewport... 0 window_width 0 window_height
name$ = wav$ - ".wav" + ".eps"
#printline Saved to 'shellDirectory$'/'name$'
#Write to EPS file... 'shellDirectory$'/'name$'

select Sound 'wav$'
plus TextGrid 'label$'
