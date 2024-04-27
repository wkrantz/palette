(a work in progress script for [monome norns](https://monome.org/docs/norns/))

# palette

A palette of chords to paint with.

Requires n.b., can cause issues outputting many simultaneous notes to some voices.

## Grid

### Chord Palette

The main chord palette on the grid presents a five rows of seven. 

The seven columns represent the scale degrees.

Each row presents a variation of the chord of that degree as follows:

 - The secondary dominant of each degree
 - An alternate mode of the same root (by default the relative minor)
 - **The main chords of the chosen scale**
 - The 7th chord of each degree
 - Another chord variant (by default the Sus4)

Conceptually, the two rows below the main row are variations on the root chords, while the two rows above are borrowed chords that don't necessarily fit in the root key but work as modulations or passing chords.


### Modifiers
In the bottom left corner are two rows of **momentary** modifiers that will adjust the octave (bottom row) and inversion (2nd row) of the played chord if they are held while pressing a chord key.

There is a shortcut to change the octave persistantly by holding the center key on the bottom row and then pressing octave up or down.


### Sequencer

A very simple 16 step sequencer is presented across the top row of the grid.
Pressing an empty step will insert the most recently played chord.
Pressing a step with a chord will remove it.

The single lit key on the second row of the grid starts and stops the sequencer.


## Norns
Current UI is highly tentative.

The norns screen will show the most recently played chord and a map of the current palette. 

E1 chooses the root note of the key
E2 chooses the mode of the key

A helpful piano shows the notes you are playing so I can learn something

## Parameters

Bass note - toggle a bass note on octave below the root

2nd Mode - Chose the mode for the 2nd row of the palette

Chord 2    - Change the chord type for the 4th row of the palette

Humanize - Play the notes of the chord with a slight random spread of time between them

Sequencer step - Change the sequencer step length in bars


## Acknowledgements
 - Piano UI adapted from [arcologies](https://github.com/northern-information/arcologies)
 - Several helpful music theory functions adapted from [dreamsequence](https://github.com/dstroud/dreamsequence/tree/main)
