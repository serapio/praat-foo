########################################################
#                                                               
# NAME: spectral_tilt.praat                            
#                                                               
# INPUT: 
#	Either:
#		(1) one WAV file (sampling freq above 16000 kHz)             
#        		- with TextGrid segmentation for vowel(s)
#		(2) a directory full of WAV files with matching TextGrids
#                                                               
#                                                               
# USAGE:                                
#	In the case of (1), select the WAV file together with the
#	TextGrid, and run the script. The script steps through
#	each of the intervals with a label that matches @the_label
#	and places one sample point per @spectrum_window.
#	At each point, the user has the chance to inspect the 
#	spectrogram and spectrum for errors in F_n, and either
#	accept the measurements or adjust the reference freqs
#	and retry the calculations.
#
#	In the case of (2), place the script in the directory with
#	the files, and open and run the script. At each inspection
#	point, the user has the option of accepting, retrying, or
#	skipping to a different file.
#
#	If the target label matches one of the given five vowel qualities,
#	The reference frequencies will be adjusted accordingly, and
#	otherwise, central vowel reference frequencies are used. The
#	reference frequencies and pitch range are also adjusted based
#	on the @sex_of_speaker.
#
#	In Syncronized mode, the @spectrum_window is set to be
#	a certain number of wavelengths at the sample point's F0,
#	while in Constant mode, the @spectrum_window is set to
#	a constant time period.
#
# OUTPUT:
#	The measured voice parameters are written to a file
#	in tab-delimited format, with extention ".tilt"
#	
#	cpp:	Cepstral Peak Prominence (Praat's Get Peak Prominence...)
#	hnr: Harmonic-to-Noise ratio (Praat's Harmonicity: Get value at time...)
#	jitter: Local jitter (Praat's PointProcess: Get jitter (local)...)
#	h1h2_u: H1-H2 spectral tilt (uncorrected)
#	h1a1_u: H1-A1 spectral tilt (uncorrected)
#	h1a2_u: H1-A2 spectral tilt (uncorrected)
#	h1a3_u: H1-A3 spectral tilt (uncorrected)
#	h1h2_c: H1-H2 spectral tilt (corrected (Iseli et al. 2007) for formants)
#	h1a1_c: H1-A1 spectral tilt (corrected (Iseli et al. 2007) for formants)
#	h1a2_c: H1-A2 spectral tilt (corrected (Iseli et al. 2007) for formants)
#	h1a3_c: H1-A3 spectral tilt (corrected (Iseli et al. 2007) for formants)
#	h1h2_o: H1-H2 spectral tilt per octave (corrected)
#	h1a1_o: H1-A1 spectral tilt per octave (corrected)
#	h1a2_o: H1-A2 spectral tilt per octave (corrected)
#	h1a3_o: H1-A3 spectral tilt per octave (corrected)
#       
# Original script (called msr&check_spectr_indiv_interv.psc):                       
# BY:   Bert Remijsen                                           
# DATE: 28/09/2004          
# http://www.lel.ed.ac.uk/~bert/praatscripts.html
# "These scripts are freely available to anyone who can use them, as is or, 
# more likely, after modification. Please acknowledge where appropriate."                                    
#                                                               
# Modifications (windows, inverse filtering, batch mode, etc.):
# BY:	 Lucien Carroll
# DATE: 15/09/2014                                                       
########################################################



form Calculate F1, F2, and intensity-related measurements
   comment The tier of segments to be measured, and regex to find the target labels
   positive the_tier 1
   sentence the_label [AEIOUaeiou]
   boolean Play_sound 1
   #boolean Intensity_spectrum 1
   positive Spectrogram_window_(secs) 0.005
   positive Max_samples_per_seg 5
   optionmenu Spectrum_window_mode: 1
      option Syncronized
      option Constant
   positive Syncronized_spectrum_window_(periods) 5
   positive Constant_spectrum_window_(secs) 0.020
   optionmenu Formant_method: 2
      option Direct
      option LPC
   optionmenu Sex_of_speaker_(adjusts_ref_freqs) 2
      option male
      option female
   comment Reference freqs for Track... formant algorithm: [-back]              [+back]
;;   comment (five vowel qualities: high vowels, then mid vowels, then low vowels)
   positive left_F1_high_([i,_u]) 320
   positive right_F1_high_([i,_u])  320
   positive left_F2_high_([i,_u])  2200
   positive right_F2_high_([i,_u])  800
   positive left_F3_high_([i,_u])  3000
   positive right_F3_high_([i,_u])  2500
   positive left_F1_mid_([e,_o])  500
   positive right_F1_mid_([e,_o])  500
   positive left_F2_mid_([e,_o])   2000
   positive right_F2_mid_([e,_o])   1000
   positive left_F3_mid_([e,_o])   2600
   positive right_F3_mid_([e,_o])   2300
   positive left_F1_low_([a]) 1000
   positive left_F2_low_([a]) 1400
   positive left_F3_low_([a]) 2500
   
endform
     
# sex is 1 for male; sex is 2 for female.
if 'sex_of_speaker' = 1
   minF0 = 70
   maxF0 = 280
else
   minF0 = 125
   maxF0 = 500
endif

clearinfo

frequency_cost = 2
bandwidth_cost = 1
transition_cost = 1
check_each = 1

# defaults for processing a single file
current_file = 1
numberOfFiles = 1

# Running on one file or multiple?
nsels = numberOfSelected ("Sound")
nselt = numberOfSelected ("TextGrid")
if (nsels = 1)
   if (nselt = 0)
      name$ = selected$("Sound")
      sound = selected("Sound")
      select TextGrid 'name$'
      textgrid = selected("TextGrid")
   else
      sound = selected("Sound")
      textgrid = selected("TextGrid")
   endif
   finished = 0
   call plot_clip sound textgrid
else
   if (nselt = 1)
      name$ = selected$("TextGrid")
      textgrid = selected("TextGrid")
      select Sound 'name$'
      sound = selected("Sound")
      call plot_clip sound textgrid
   else
      directory$ = "./"
      Create Strings as file list... list 'directory$'*.wav
      last_file = Get number of strings
      first_file = 1
      beginPause ("Press [Continue] when ready")
         comment ("Running on all WAV files in current directory. Okay?") 
         positive ("First file:", 'first_file')
         positive ("Last file:", 'last_file')
         boolean ("Check each", 1)
      endPause ("Continue",1)
      #for current_file from 1 to numberOfFiles
      current_file = 'first_file'
      repeat
         select Strings list
         fileName$ = Get string... current_file
         printline Opening 'fileName$' 
         name$ = fileName$ - ".wav" - ".WAV"
         sound = Read from file... 'directory$''fileName$'
         textgrid = Read from file... 'directory$''name$'.label
         finished = 0
         call plot_clip sound textgrid
         Remove
      #endfor # increment/jump inside @plot_clip > @navigate
      until (current_file > last_file)
      printline Complete!
   endif
endif


procedure plot_clip sound textgrid

   select 'textgrid'
   finishing_time = Get finishing time
   nlabels = Get number of intervals... 'the_tier'
   num_tiers = Get number of tiers

   select 'sound'
   name$ = selected$("Sound")

   select 'sound'
   sound_16khz = Resample... 16000 50
   pitch_16khz = To Pitch... 0 minF0 maxF0
   pitchtier = Down to PitchTier

   call make_table

   for lab_i from 1 to 'nlabels'
      select 'textgrid'
      labelx$ = Get label of interval... 'the_tier' 'lab_i'
      #printline interval 'lab_i' with label 'labelx$' of 'name$'

      if (index_regex( labelx$, the_label$))
         n_b = Get starting point... 'the_tier' 'lab_i'
         n_e = Get end point... 'the_tier' 'lab_i'
         n_len = 'n_e' - 'n_b'
         n_md = ('n_b' + 'n_e') / 2

         call setRefFreqs 'labelx$'

         call setLtasWindow n_md n_b n_e

         parts = round( 'n_len' / 'spectrum_window')
         printline We will do 'parts' samples: 'n_len' / 'spectrum_window'

         if parts > max_samples_per_seg
            parts = max_samples_per_seg
         endif
         n_delta = 'n_len' / 'parts'

         for n_i from 1 to 'parts'
            n_m = 'n_b' + ('n_i' - 0.5) * n_delta
            #printline sample 'n_i' at time 'n_m' in interval 'lab_i'

            call setLtasWindow n_m n_b n_e
            select pitchtier
            f0_m = Get value at time... n_m

            accepted = 0
            while accepted = 0
               #printline finding measures for 'n_m'

               call vowelq 'n_b' 'n_e' 'n_md' 'n_m' 'name$' 'labelx$'
               call voiceq 'f1hzpt' 'f2hzpt' 'f3hzpt' 'name$'
               call inner_cleanup

               call navigate current_file lab_i n_i
               clearinfo

            endwhile           
 
            call update_table

            if jump_out
               goto break
            endif
         endfor
      else
         if lab_i = nlabels
            current_file = current_file + 1
         endif
      endif
   endfor

   label break

   call outer_cleanup

   select 'textgrid'
   plus 'sound'
   
endproc

procedure setRefFreqs labelx$
   # set maximum frequency of Formant calculation algorithm on basis of sex and vowel label
   #printline 'labelx$'
   if index_regex(labelx$, "[aA]")
      printline This is an [a]: 'labelx$'
      f1ref = left_F1_low
      f2ref = left_F2_low
      f3ref = left_F3_low
   elsif index_regex(labelx$, "[eE]")
      printline This is an [e]: 'labelx$'
      f1ref = left_F1_mid
      f2ref = left_F2_mid
      f3ref = left_F3_mid
   elsif index_regex(labelx$, "[oO]")
      printline This is an [o]: 'labelx$'
      f1ref = right_F1_mid
      f2ref = right_F2_mid
      f3ref = right_F3_mid
   elsif index_regex(labelx$, "[uU]")
      printline This is an [u]: 'labelx$'
      f1ref = right_F1_high
      f2ref = right_F2_high
      f3ref = right_F3_high
   elsif index_regex(labelx$,"[iI]")
      printline This is an [i]: 'labelx$'
      f1ref = left_F1_high
      f2ref = left_F2_high
      f3ref = left_F3_high
   else
      printline This is not a recognized vowel: 'labelx$'
      f1ref = 500
      f2ref = 1500
      f3ref = 2700
   endif
   f4ref = 3650
   f5ref = 4700
   maxf = 4000

   freqcost = frequency_cost
   bwcost = bandwidth_cost
   transcost = transition_cost

   # sex is 1 for male; sex is 2 for female.
   if 'sex_of_speaker' = 1
      f1ref = f1ref - 0.05 * f1ref
      f2ref = f2ref - 0.05 * f2ref
      f3ref = f3ref - 0.05 * f3ref
      f4ref = f4ref - 0.05 * f4ref
      f5ref = f5ref - 0.05 * f5ref
      maxf = maxf - 0.05 * maxf
   else
      f1ref = f1ref + 0.05 * f1ref
      f2ref = f2ref + 0.05 * f2ref
      f3ref = f3ref + 0.05 * f3ref
      f4ref = f4ref + 0.05 * f4ref
      f5ref = f5ref + 0.05 * f5ref
      maxf = maxf + 0.05 * maxf
  endif
endproc

procedure setLtasWindow t_mid t_begin t_end
   if (spectrum_window_mode = 2)
      spectrum_window = constant_spectrum_window
   else
      select pitchtier
      f0_mid = Get value at time... 't_mid'
      if f0_mid = undefined
         f0_mid = Get mean (curve)... 't_begin' 't_end'
      endif
      if f0_mid = undefined
         spectrum_window = constant_spectrum_window
         printline Warning! Falling back to constant ltas window.
      else
         spectrum_window = syncronized_spectrum_window / f0_mid
      endif
   endif
endproc

procedure vowelq n_b n_e n_md n_m name$ labelx$

  select sound_16khz
  formant_plotting = To Formant (burg)... 0.01 3 'maxf' 'spectrum_window' 50
  select sound_16khz
  if formant_method = 1
     # Direct method
     sound_vowel = Extract part...  'n_b' 'n_e' rectangular 1 yes
     To Formant (burg)... 0.0 4 'maxf' 'spectrum_window' 50
     Rename... 'name$'_beforetracking
     formant_beforetracking = selected("Formant")
  else
     # LPC method
     sound_vowel = Extract part... (n_m-n_delta) (n_m+n_delta) rectangular 1 yes
     formant_lpc = To LPC (burg)... 18 'spectrum_window' 0.005 50
     To Formant
     Rename... 'name$'_beforetracking
     formant_beforetracking = selected("Formant")
     select formant_lpc
     Remove
  endif
  select formant_beforetracking
  nformants = Get minimum number of formants
  if (nformants > 2)
     #printline Frequency cost is currently 'freqcost'
     Track... 3 'f1ref' 'f2ref' 'f3ref' 'f4ref' 'f5ref' 'freqcost' 'bwcost' 'transcost'
     Rename... 'name$'_aftertracking
     formant_aftertracking = selected("Formant")
   else
      formant_aftertracking = formant_beforetracking
   endif
   select 'formant_aftertracking'
   f1hzpt = Get value at time... 1 'n_m' Hertz Linear
   f2hzpt = Get value at time... 2 'n_m' Hertz Linear
   f3hzpt = Get value at time... 3 'n_m' Hertz Linear
   if finished <> 3
      # i.e. not retrying this file
      if f2hzpt = undefined
         printline Warning! Using formant median around sampling point.
         f1hzpt = Get quantile... 1 (n_m-n_delta) (n_m+n_delta) Hertz 0.5
         f2hzpt = Get quantile... 2 (n_m-n_delta) (n_m+n_delta) Hertz 0.5
         f3hzpt = Get quantile... 3 (n_m-n_delta) (n_m+n_delta) Hertz 0.5
      endif
      if f2hzpt = undefined
         printline Warning! Using formants at midpoint of vowel.
         f1hzpt = Get value at time... 1 'n_md' Hertz Linear
         f2hzpt = Get value at time... 2 'n_md' Hertz Linear
         f3hzpt = Get value at time... 3 'n_md' Hertz Linear
      endif
   endif
   if f3hzpt = undefined
      f3hzpt = f3ref
      printline Warning! Punting on F3.
   endif
   if f2hzpt = undefined
      f2hzpt = f2ref
      printline Warning! Punting on F2
   endif
   if f1hzpt = undefined
      f1hzpt = f1ref
      printline Warning! Punting on F1
   endif
   #b1hz = Get quantile of bandwidth... 1 'n_b' 'n_e' Hertz 0.50
   #b2hz = Get quantile of bandwidth... 2  'n_b' 'n_e' Hertz 0.50
   #b3hz = Get quantile of bandwidth... 3 'n_b' 'n_e' Hertz 0.50

# display the formant tracks overlaid on spectrogram.
   Erase all
   Font size... 14
   display_from = 'n_b' - 0.15
   if ('display_from' < 0)
      display_from = 0
   endif
   display_until = 'n_e' + 0.15
   if ('display_until' > 'finishing_time')
      display_until = 'finishing_time'
   endif
   select 'sound'
   To Spectrogram... 'spectrogram_window' 4000 0.002 20 Gaussian
   spectrogram = selected("Spectrogram")
   spec_limit = 4.0 - num_tiers * (1.25/3)
   Viewport... 0 7 0 spec_limit
   Paint... 'display_from' 'display_until' 0 4000 100 yes 50 6 0 no
   select 'formant_plotting'
   Yellow
   Speckle... 'display_from' 'display_until' 4000 30 no
   Marks left every... 1 500 yes yes yes  
   Viewport... 0 7 0 4.0
   select 'textgrid'
   Black
   Draw... 'display_from' 'display_until' no yes yes
   One mark bottom... 'n_m' yes yes yes

   call round f1hzpt 0
   rf1hzpt = round.result
   call round f2hzpt 0
   rf2hzpt = round.result
   call round f3hzpt 0
   rf3hzpt = round.result
   Text top... no Tracker output -- F1: 'rf1hzpt' ----- F2: 'rf2hzpt'


# display the spectrum, with Ltas and LPC
   select 'sound_16khz'
   spectrum_begin = n_m - spectrum_window/2
   spectrum_end = n_m + spectrum_window/2
   Extract part...  'spectrum_begin' 'spectrum_end' Hanning 1 no
   Rename... 'name$'_slice
   sound_16khz_slice = selected("Sound") 
   To Spectrum (fft)
   spectrum = selected("Spectrum")
   Viewport... 0 7 4.0 7

   Draw... 0 4000 -20 80 yes
   ltas = To Ltas (1-to-1)
   Viewport... 0 7 4.0 7
   Draw... 0 4000 -20 80 no bars
   Marks bottom every... 1 500 yes yes no
   Marks bottom every... 1 250 no no yes
   ltas_mat = To Matrix
   ltas_nx = Get number of columns
   for n from 1 to ltas_nx
      fx = Get x of column... n
      dbx = Get value in cell... 1 n
      bw = 80 + (150 * f1hzpt / 5000)
      call correctiondb fx f1hzpt bw 16000
      dbx = dbx - correctiondb.result
      bw = 80 + (150 * f2hzpt / 5000)
      call correctiondb fx f2hzpt bw 16000
      dbx = dbx - correctiondb.result
      bw = 80 + (150 * f3hzpt / 5000)
      call correctiondb fx f3hzpt bw 16000
      dbx = dbx - correctiondb.result
      Set value... 1 n dbx
   endfor
   ltas_corr = To Ltas
   spectrum_corr = To SpectrumTier (peaks)
   Draw... 0 4000 -20 80 no lines and speckles

   select 'sound_16khz'
   lpc = To LPC (autocorrelation)... 18 'spectrum_window' 0.005 50
   spectrum_lpc = To Spectrum (slice)... 'n_m' 20 0 50
   Rename... LPC_'name$'
   ltas_lpc = To Ltas (1-to-1)
   lpc_f1 = Get value at frequency... f1hzpt Nearest
   lpc_f2 = Get value at frequency... f2hzpt Nearest
   lpc_f3 = Get value at frequency... f3hzpt Nearest
   plus 'lpc'
   Remove
   select 'spectrum_lpc'
   Line width... 2
   Draw... 0 4000 -20 80 no
   Line width... 1
   Draw arrow... f1hzpt (lpc_f1-10) f1hzpt lpc_f1
   Draw arrow... f2hzpt (lpc_f2-10) f2hzpt lpc_f2
   Draw arrow... f3hzpt (lpc_f3-10) f3hzpt lpc_f3
   ltasw = round(spectrum_window * 1000)
   Text top... yes Spectrum ['ltasw' ms], Ltas(1-to-1) ['ltasw' ms], LPC(autocorrelation), overlaid
   
   printline Settings for sample 'n_i' of 'parts' in interval 'lab_i' (finished: 'finished'; freqcost: 'freqcost')
   printline F1ref:'f1ref' ---- F2ref:'f2ref' ---- F3ref:'f3ref' ---- F4ref:'f4ref' ---- F5ref:'f5ref'
endproc

procedure voiceq f1hzpt f2hzpt f3hzpt name$

  call round f0_m 1
  rf0m = round.result
  p10_f0m = 'f0_m' / 10

  select sound_16khz
  pcg = To PowerCepstrogram... 60 0.002 4000 50
  pcs = To PowerCepstrum (slice)... n_m
  pcpp = Get peak prominence... 60 333.3 Parabolic 0.001 0 Straight Robust
  #pchnr = Get harmonics to noise ratio... 60 333.3 0.5
  rpcpp$ = fixed$(pcpp, 2)
  #rpchnr$ = fixed$(pchnr, 2)
  plus pcg
  Remove

  select pitch_16khz
  pitch_pp = To PointProcess
  jitter = Get jitter (local)... (n_m-spectrum_window/2) (n_m+spectrum_window/2) 0.0001 0.02 1.3
  rjitter$ = fixed$(jitter * 100, 2) + "%" 
  Remove
  
  select sound_16khz
  harm = To Harmonicity (cc)... 0.01 minF0 0.1 4.5
  hnr = Get value at time... n_m Cubic
  if hnr < 0
     hnr = undefined
  endif
  rhnr$ = fixed$(hnr, 2)
  Remove

  select 'ltas'
  lowerbh1 = 'f0_m' - 'p10_f0m'
  upperbh1 = 'f0_m' + 'p10_f0m'
  lowerbh2 = ('f0_m' * 2) - ('p10_f0m' * 2)
  upperbh2 = ('f0_m' * 2) + ('p10_f0m' * 2)
  h1db = Get maximum... 'lowerbh1' 'upperbh1' None
  h1hz = Get frequency of maximum... 'lowerbh1' 'upperbh1' None
  h2db = Get maximum... 'lowerbh2' 'upperbh2' None
  h2hz = Get frequency of maximum... 'lowerbh2' 'upperbh2' None
  call round h1hz 1
  rh1hz = round.result
  call round h2hz 1
  rh2hz = round.result

# Get the a1, a2, a3 measurements.

  p10_f1hzpt = max('f1hzpt' / 10, 'f0_m'/2)
  p10_f2hzpt = max('f2hzpt' / 10, 'f0_m'/2)
  p10_f3hzpt = max('f3hzpt' / 10, 'f0_m'/2)
  lowerba1 = 'f1hzpt' - 'p10_f1hzpt'
  upperba1 = 'f1hzpt' + 'p10_f1hzpt'
  lowerba2 = 'f2hzpt' - 'p10_f2hzpt'
  upperba2 = 'f2hzpt' + 'p10_f2hzpt'
  lowerba3 = 'f3hzpt' - 'p10_f3hzpt'
  upperba3 = 'f3hzpt' + 'p10_f3hzpt'
  a1db = Get maximum... 'lowerba1' 'upperba1' None
  a1hz = Get frequency of maximum... 'lowerba1' 'upperba1' None
  a2db = Get maximum... 'lowerba2' 'upperba2' None
  a2hz = Get frequency of maximum... 'lowerba2' 'upperba2' None
  a3db = Get maximum... 'lowerba3' 'upperba3' None
  a3hz = Get frequency of maximum... 'lowerba3' 'upperba3' None

  call round a1hz 0
  ra1hz = round.result
  call round a2hz 0
  ra2hz = round.result
  call round a3hz 0
  ra3hz = round.result

# Get "corrected" amplitudes

  select 'ltas_corr'
  h1db_corr = Get maximum... 'lowerbh1' 'upperbh1' None
  h1hz_corr = Get frequency of maximum... 'lowerbh1' 'upperbh1' None
  h2db_corr = Get maximum... 'lowerbh2' 'upperbh2' None
  h2hz_corr = Get frequency of maximum... 'lowerbh2' 'upperbh2' None

# Get the a1, a2, a3 measurements.

  a1db_corr = Get maximum... 'lowerba1' 'upperba1' None
  a1hz_corr = Get frequency of maximum... 'lowerba1' 'upperba1' None
  a2db_corr = Get maximum... 'lowerba2' 'upperba2' None
  a2hz_corr = Get frequency of maximum... 'lowerba2' 'upperba2' None
  a3db_corr = Get maximum... 'lowerba3' 'upperba3' None
  a3hz_corr = Get frequency of maximum... 'lowerba3' 'upperba3' None

# Calculate potential voice quality correlates.
   h1mnh2 = 'h1db' - 'h2db'
   h1mna1 = 'h1db' - 'a1db'
   h1mna2 = 'h1db' - 'a2db'
   h1mna3 = 'h1db' - 'a3db'
   h1mnh2_corr = h1db_corr - h2db_corr
   h1mna1_corr = h1db_corr - a1db_corr
   h1mna2_corr = h1db_corr - a2db_corr
   h1mna3_corr = h1db_corr - a3db_corr
   h1mnh2_oct = h1mnh2_corr / (log2(h2hz_corr) - log2(h1hz_corr))
   h1mna1_oct = h1mna1_corr / (log2(a1hz_corr) - log2(h1hz_corr))
   h1mna2_oct = h1mna2_corr / (log2(a2hz_corr) - log2(h1hz_corr))
   h1mna3_oct = h1mna3_corr / (log2(a3hz_corr) - log2(h1hz_corr))
# rounded value strings for display
   rh1mnh2$ = fixed$(h1mnh2, 2)
   rh1mna1$ = fixed$(h1mna1 , 2)
   rh1mna2$ = fixed$(h1mna2 , 2)
   rh1mna3$ = fixed$(h1mna3 , 2)
   rh1mnh2_corr$ = fixed$(h1mnh2_corr , 2)
   rh1mna1_corr$ = fixed$(h1mna1_corr , 2)
   rh1mna2_corr$ = fixed$(h1mna2_corr , 2)
   rh1mna3_corr$ = fixed$(h1mna3_corr , 2)
   rh1mnh2_oct$ = fixed$(h1mnh2_oct , 2)
   rh1mna1_oct$ = fixed$(h1mna1_oct , 2)
   rh1mna2_oct$ = fixed$(h1mna2_oct , 2)
   rh1mna3_oct$ = fixed$(h1mna3_oct, 2)

   if (play_sound = 1)
      select 'sound'
      Extract part... 'display_from' 'display_until' Hanning 1 no
      Play
      Remove
   endif

# display H1, H2, A1, A2, A3 of vowel to check for errors.
  Viewport... 0 7 4.0 7.25
  Font size... 14
  Line width... 2
  One mark bottom... 'h1hz' no no yes H1
  One mark bottom... 'h2hz' no no yes H2
  One mark top... 'a1hz' no no yes A1
  One mark top... 'a2hz' no no yes A2
  if a3hz < 4000
     One mark top... 'a3hz' no no yes A3
  endif
  Line width... 1
  printline F0: 'rf0m' 'tab$' Frequency of H1: 'rh1hz' 'tab$' H1 (dB): 'h1db' 'h1db_corr'
  printline 'tab$''tab$' Frequency of H2: 'rh2hz' 'tab$' H2 (dB): 'h2db' 'h2db_corr'
  printline F1: 'rf1hzpt' 'tab$' Frequency of A1: 'ra1hz' 'tab$' A1 (dB): 'a1db' 'a1db_corr'
  printline F2: 'rf2hzpt' 'tab$' Frequency of A2: 'ra2hz' 'tab$' A2 (dB): 'a2db' 'a2db_corr'
  printline F3: 'rf3hzpt' 'tab$' Frequency of A3: 'ra3hz' 'tab$' A3 (dB): 'a3db' 'a3db_corr'
  printline
  printline CPP: 'rpcpp$' 'tab$' HNR: 'rhnr$' 'tab$' Jitter (local): 'rjitter$'
  printline
  printline Spectral tilt 'tab$' Corrected 'tab$' Per octave
  printline H1-H2: 'rh1mnh2$' 'tab$''tab$' 'rh1mnh2_corr$' 'tab$''tab$' 'rh1mnh2_oct$' 
  printline H1-A1: 'rh1mna1$' 'tab$''tab$' 'rh1mna1_corr$' 'tab$''tab$' 'rh1mna1_oct$' 
  printline H1-A2: 'rh1mna2$' 'tab$''tab$' 'rh1mna2_corr$' 'tab$''tab$' 'rh1mna2_oct$'
  printline H1-A3: 'rh1mna3$' 'tab$''tab$' 'rh1mna3_corr$' 'tab$''tab$' 'rh1mna3_oct$' 
  printline 
  printline When the 'To formant' and 'Track...' procedures do not        
  printline produce plausible formant values, the user can (1) run the           
  printline script again with new tracking values, (2) on the basis       
  printline of the spectrum/Ltas/LPC display at the bottom part of       
  printline the Picture window, determine F1 and F2 by hand using         
  printline e.g. the LPC (Spectrum LPC_slice) the Object window.                   

   #printline "The current step is: 'current_file':'lab_i':'n_i'"     

endproc

procedure navigate current_file .lab_i .n_i
   if .n_i < parts
      n_next = .n_i + 1
      label_next = .lab_i
      file_next = current_file
   else
      n_next = 1
      if .lab_i < nlabels
         label_next = .lab_i+1
         file_next = current_file
      else
         label_next = 1
         file_next = current_file + 1
      endif
   endif

   if check_each
      finished = 0
      beginPause ("Press Finish to exit")
         comment ("The current step (file:interval:sample) is: 'current_file':'.lab_i':'.n_i'")
         #comment ("The next step is: 'file_next':'label_next':'n_next'")
         comment ("Number of files in list: 'numberOfFiles'")
         comment ("Number of samples in interval: 'parts'")
         comment ("Retry with the following estimates")
         positive ("F0", 'rf0m')
         positive ("F1", 'rf1hzpt')
         positive ("F2", 'rf2hzpt')
         positive ("F3", 'rf3hzpt')
         comment ("Or jump to another file")
         positive ("Jump to file", 'file_next')
      finished = endPause ("Finish", "Jump", "Retry", "Continue", 4)
   else
      finished = 4
   endif

   jump_out = 0
   if finished = 3
      f0_m = f0
      if spectrum_window_mode = 1
         spectrum_window = syncronized_spectrum_window / f0_m
      endif
      f1ref = f1
      f2ref = f2
      f3ref = f3
      accepted = 0
      freqcost = freqcost + frequency_cost
   else
      # end the while loop
      accepted = 1
      freqcost = frequency_cost
 
      if finished = 4
         # proceed to next step (may be same or next file)
         .current_file = file_next
      else
         # end the for-loops
         jump_out = 1
         if finished = 1
            printline Current file number is 'current_file'.
            current_file = numberOfFiles+1
         elsif finished = 2
            #jump to another file
            current_file = jump_to_file
         endif
      endif
   endif
endproc

procedure inner_cleanup
   select 'spectrum_lpc'
   plus 'spectrum'
   plus 'ltas'
   plus 'ltas_mat'
   plus 'ltas_corr'
   plus 'spectrum_corr'
   plus 'spectrogram'
   plus 'formant_beforetracking'
   plus 'formant_aftertracking'
   plus 'formant_plotting'
   plus 'sound_16khz_slice'
   plus 'sound_vowel'
   Remove
endproc

procedure make_table

      Create TableOfReal... tilt 23 1
      Set row label (index)... 1 interval
      Set row label (index)... 2 sample
      Set row label (index)... 3 time
      Set row label (index)... 4 cpp
      Set row label (index)... 5 hnr
      Set row label (index)... 6 jitter
      Set row label (index)... 7 h1h2_u
      Set row label (index)... 8 h1a1_u
      Set row label (index)... 9 h1a2_u
      Set row label (index)... 10 h1a3_u
      Set row label (index)... 11 h1h2_c
      Set row label (index)... 12 h1a1_c
      Set row label (index)... 13 h1a2_c
      Set row label (index)... 14 h1a3_c
      Set row label (index)... 15 h1h2_o
      Set row label (index)... 16 h1a1_o
      Set row label (index)... 17 h1a2_o
      Set row label (index)... 18 h1a3_o
      Set row label (index)... 19 h1hz
      Set row label (index)... 20 h2hz
      Set row label (index)... 21 a1hz
      Set row label (index)... 22 a2hz
      Set row label (index)... 23 a3hz

endproc

procedure update_table

   select TableOfReal tilt
   ncols = Get number of columns
      Set value...   1 ncols lab_i
      Set value...   2 ncols n_i
      Set value...   3 ncols n_m
      Set value...   4 ncols pcpp
      Set value...  5 ncols hnr
      Set value...   6 ncols jitter
      Set value...  7 ncols h1mnh2
      Set value...  8 ncols h1mna1
      Set value...  9 ncols h1mna2
      Set value...   10 ncols h1mna3
      Set value...   11 ncols h1mnh2_corr
      Set value...  12 ncols h1mna1_corr
      Set value...  13 ncols h1mna2_corr
      Set value...   14 ncols h1mna3_corr
      Set value...   15 ncols h1mnh2_oct
      Set value...   16 ncols h1mna1_oct
      Set value...   17 ncols h1mna2_oct
      Set value...   18 ncols h1mna3_oct
      Set value...   19 ncols h1hz
      Set value...   20 ncols h2hz
      Set value...  21 ncols a1hz
      Set value...   22 ncols a2hz
      Set value...   23 ncols a3hz


   Set column label (index)... ncols s'lab_i'_'n_i'
   Insert column (index)... ncols + 1 

endproc

procedure outer_cleanup

   select TableOfReal tilt
   ncols = Get number of columns
   if ncols > 1
      Remove column (index)... ncols
      Write to headerless spreadsheet file... 'name$'.tilt
   endif
   plus sound_16khz
   plus pitch_16khz
   plus pitchtier
   Remove

endproc

procedure correctiondb freq f_i b_i f_s
   # Iseli and Alwaan (2004), Iseli et al (2007)
   # F_s := sampling frequency
   # F_i := formant frequency
   # B_i := formant bandwidth
   # H(w) := amplitude of angular frequency w
   # w = 2 \pi f / F_s
   # r_i = exp( - \pi B_i / F_s)
   # w_i = 2 \pi F_i / F_s
   # H*(w) = H(w) - \Sigma 10 log_10 	[		(1 - 2 r_i cos (w_i) + r_i ^2 )^2 / 
   #					(1 - 2 r_i cos (w + w_i) + r_i ^2) (1 - 2 r_i cos (w - w_i) + r_i ^2) ]

   w = 2 * pi * freq / f_s
   r_i = exp( - pi * b_i / f_s )
   w_i = 2 * pi * f_i / f_s
   amp_A = 1 - 2 * r_i * cos(w_i) + r_i^2
   amp_B = 1 - 2 * r_i * cos(w + w_i) + r_i^2
   amp_C = 1 - 2 * r_i * cos(w - w_i) + r_i^2

   .result = 20*log10(amp_A) - 10*(log10(amp_B) + log10(amp_C))
   if .result = undefined
      .result = 0
      printline Warning! Undefined correction term.
   endif

endproc


procedure round .num .digits
   if .num = undefined
      .result = undefined
   else
      .factor = 10 ^.digits
      .result = round(.num * .factor) / .factor
   endif
endproc
