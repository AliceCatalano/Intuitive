# Briefing: statistical strategy to compare EXPERTS vs RESIDENTS (EEG, robotic suturing)

Purpose: paste this whole file into a chat with Claude (online, with web/literature access) and
discuss which tests to use. Section 6 is a ready-made prompt. Section 5 is my first-pass advice
(written from memory, WITHOUT web access: please verify every citation and claim).

## 1. Study

- Surgeons perform robotic suturing in a simulator while EEG is recorded (64-ch cap, preprocessed
  with ICA, same reference dataset for channel order, 32 channels used in the task analyses).
- Each suture = 4 suture points. Two event types are extracted per suture point:
  - **Grasp** (needle grasp) -> alpha/beta **ERD** window -0.5..1.0 s around the event
  - **Exit** (needle exit) -> **ERS** / beta rebound window -2.0..0.0 s around the event
    (epochs: grasp -0.8..1.5 s, exit -2.5..0.5 s)
- **Experts** (IE): about 10 subjects, task 2 with 20 repetitions x 4 points (80 slots), also a task 1.
- **Residents** (IR): 21 subjects, 6 scenarios of increasing difficulty x up to 10 repetitions x 4 points
  (240 slots). A scenario is passed after 3 consecutive repetitions with performance score (PS) >= 75%;
  the number of repetitions actually done differs per subject and many slots are empty.
  A table gives PS per subject/scene/rep (>=75% = "successful"); some repetitions have a code instead (S/X, meaning unknown to me).
- Unclear / to decide: which expert task/repetitions correspond to which resident scenarios.

## 2. Data structures available (per subject, per slot, per ROI)

- Time-frequency power (Hann taper, 0.2 s window, 2-40 Hz, step 0.05 s), normalised per subject
  as (pow - mean)/mean over trials, channels, freqs, times.
- ROIs (channel indices in the reference montage): MotorLeft [15 20 10], MotorRight [13 19 9],
  Visual [29 30 31], Frontal [4 5 6].
- Bands: theta 4-8, alpha 8-15 ("high alpha" as in the expert analysis), beta 15-25, gamma 25-35.
- **ERD** = min over the ROI-averaged band power in the grasp window (-0.5..1.0 s);
  **ERS** = max in the exit window (-2.0..0.0 s); **Modulation** = |ERS - ERD|. Per slot (extremum statistics).
- FOOOF (4-35 Hz, fixed aperiodic) per slot: aperiodic offset/exponent, alpha/beta/dominant peak
  centre frequency, power, bandwidth, R^2. "Dominant" peak turned out unstable (about 40% alpha, 40% beta).
- Topographies per channel (band power, time-averaged) for cluster-based permutation tests
  (FieldTrip, depsamplesT, clusteralpha 0.05, maxsum, minnbchan 2, 1000 permutations).
- Phase consistency (PLV) analyses showed nothing interesting in residents; not a priority.
- Behaviour: performance score, execution time, path length per repetition.

## 3. Questions to answer

1. Do experts differ from residents in ERD, ERS, modulation, aperiodic exponent/offset, peak frequency
   (per ROI and band)? Spatially (topography)?
2. Do residents move toward the expert pattern with learning (early vs late repetitions, scenarios,
   successful vs unsuccessful repetitions)?
3. Are neural measures related to performance (PS, time, path length), within and across groups?

## 4. Known problems and constraints

- Small and unbalanced groups (about 10 vs 21), different numbers of trials per subject, empty slots.
- Repeated measures nested in subjects (slots in repetitions in scenarios).
- ERD = minimum, ERS = maximum over a window: extremum statistics are biased by noise and by the
  number of averaged trials (more trials -> smaller noise -> less extreme). Groups with different trial counts are not directly comparable.
- Per-subject normalisation uses the subject's own global mean, so results are relative to each subject's own mean power;
  groups were also recorded in different sessions and have different trial counts.
- Many comparisons: 4 ROIs x 4 bands x 2 epochs x several metrics.
- Task difficulty is not matched (experts: task 2, residents: 6 scenarios with different difficulty).
- Possible confounds: age, handedness, experience, signal quality; I do not have these covariates yet.

## 5. My first-pass strategy (to be challenged)

1. **Unit of analysis = subject.** Average slots within subject first, or use a linear mixed model with a random
   subject intercept (value ~ group * stage + (1|subject), maybe random slope for repetition). Never treat
   slots as independent. For the unbalanced small groups use Satterthwaite / Kenward-Roger degrees of freedom.
2. **Define comparable conditions explicitly** before any test. For example (a) residents' last successful
   repetitions per scenario (the "last3" table) vs experts' successful repetitions; (b) first vs last repetition
   of each group. State why they are comparable (difficulty / performance level).
3. **Trial-count matching.** Subsample each subject to the same number of trials (repeat many times) or use an
   estimator that is not an extremum (mean in a fixed window, or ERD/ERS from the trial-averaged curve) to
   avoid the trial-count bias of min/max.
4. **Topographies:** cluster-based permutation test (Maris & Oostenveld 2007) with `indepsamplesT` on
   subject-level maps for the group difference, and for the learning x group interaction test the
   difference (last - first) between groups. Report cluster p, extent, effect size.
5. **ROI metrics (ERD, ERS, modulation, FOOOF parameters):** mixed models per outcome with FDR correction
   (Benjamini-Hochberg) across the pre-specified family; permutation-based p-values as a robustness check given the small n.
6. **Effect sizes and uncertainty first:** Hedges g with bootstrap CIs; interpret p-values cautiously.
   If the hypothesis is "no difference" (e.g. late residents = experts), use equivalence testing (TOST,
   Lakens 2017) or Bayes factors, since a non-significant result is not evidence of equivalence.
7. **FOOOF peaks:** analyse alpha and beta peaks separately; model presence/absence of a peak (logistic mixed model)
   separately from peak frequency/power conditional on presence; use R^2 threshold and report it.
8. **Brain-behaviour:** within-subject centred predictors in a mixed model (repetition-level PS / time vs neural measure),
   plus a between-subject correlation on subject means (kept separate: within- and between-subject effects can differ).
9. **Pre-specify primary outcomes** (e.g. beta ERD and ERS in motor ROIs) and label the rest exploratory.

Literature to check (from memory; verify): Maris & Oostenveld 2007 J Neurosci Methods (cluster permutation);
Maris 2012 Psychophysiology (statistical testing in electrophysiological studies); Pfurtscheller & Lopes da Silva 1999
Clin Neurophysiol (ERD/ERS); Donoghue et al. 2020 Nat Neurosci (FOOOF / parameterizing power spectra);
Bates et al. 2015 J Stat Softw (lme4); Luke 2017 Behav Res Methods (p-values in linear mixed models);
Lakens 2017 Soc Psychol Personal Sci (equivalence tests); Vinck et al. 2010 NeuroImage (PPC, bias of PLV);
Neubauer & Fink 2009 Neurosci Biobehav Rev (neural efficiency); Groppe et al. 2011 Psychophysiology (mass-univariate EEG statistics).

## 6. Prompt to give to Claude online

> I have EEG data from 10 expert and 21 resident surgeons performing robotic suturing. For each suture point I
> have event-locked (grasp, exit) time-frequency power, ERD (minimum) / ERS (maximum) / modulation per ROI and
> band, FOOOF parameters, scalp topographies, and behavioural scores. Groups are small and unbalanced, trials per
> subject differ, and residents have learning data (6 scenarios x up to 10 repetitions, success defined as
> performance score >= 75%) while experts have 20 repetitions of one task. I attach a briefing with details.
> Please (1) search the literature for how comparable expert vs novice EEG studies (motor skill, surgery,
> laparoscopic/robotic training, ERD/ERS, spectral parameterization) handled group comparison and learning
> trajectories; (2) critique my proposed strategy in section 5, in particular the trial-count bias of
> min/max ERD/ERS, matching of conditions between groups, mixed models vs permutation tests with n=10 vs 21,
> and the interaction test (group x learning stage) for cluster-based statistics; (3) propose a final
> pre-specified analysis plan with primary and exploratory outcomes, multiple-comparison control and
> effect-size reporting; (4) give MATLAB/FieldTrip or R (lme4/lmerTest) implementation hints and
> verified citations (with DOI) for every claim.
