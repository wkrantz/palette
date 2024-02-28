-- chord player thing
--
--
-- wayk

include('lib/ui')
include('lib/music_tools')
musicutil = require("musicutil")

local nb = require "nb/lib/nb"

-- mxsamples=include("mx.samples/lib/mx.samples")
-- engine.name="MxSamples"
-- instruments = {}


g = grid.connect()
if type(g.device) == 'table' then
  rows = g.device.rows or 8
  print(rows .. '-row Grid detected')
else
  rows = 8
  print('No Grid detected')
end
 

--position of chord playing buttons
start_x=7
start_y=5

Chordname = ""
momentary_inversion = 0
momentary_octave = 4
notes  = {}
prev_chord = {}
chord_playing = false
loading_sequence_step = false
current_step = 0
seq_running=false


f
function add_params()
    -- skeys=mxsamples:new()
    -- instruments = skeys:list_instruments()
    -- params:add_option("mx_ins", "MX.INSTRUMENT", instruments, 10)
    
    params:add_number("transpose", "Key", 0, 11, 0, function(param) return transpose_string(param:get()) end)
    params:add_number('mode', 'Mode', 1, 7, 1, function(param) return mode_index_to_name(param:get()) end)
    params:add_number('octave', 'Octave', 0, 8, 4)
    params:add_number('inversion' , 'Inversion', 0, 2, 0)
    params:add_option('bass_note', 'Bass Note', {'no', 'yes'}, 2)
    params:add_number('alt_mode', '2nd Mode', 1, 7, 6, function(param) return mode_index_to_name(param:get()) end)
    params:add_number('chord2', 'Mod 2', 1, 27, 14, function(param) return get_short_chord_name(param:get()) end)

    params:add{
        type = "control",
        id = "humanize",
        name = "humanize",
        controlspec = controlspec.def{
          min = 0,
          max = 200,
          warp = 'lin',
          step = 1, -- round to nearest whole number
          default = 50,
          units = "ms"
        }
      }

      params:add_separator('Sequencer')
      params:add_option('seq_step', 'Step', {0.25,0.5,1}, 3)

end





function init()
    nb:init()
    nb:add_param("voice", "voice")
    nb:add_player_params()

    add_params()

    -- set the voice to "resonator"
    params:set("voice", 8)

    grid_dirty = false -- script initializes with no LEDs drawn
    screen_dirty = false
    momentary = {} -- meta-table to track the state of all the grid keys
    basemap = {} -- the background UI to display when no notes are pressed

    
    seq = {}
    -- fill with 16 empty steps
    for i = 1, 16 do
        seq[i]=false
    end

    for x = 1,16 do -- for each x-column (16 on a 128-sized grid)...
        momentary[x] = {} -- create a table that holds...
        basemap[x] = {}     
        for y = 1,8 do -- each y-row (8 on a 128-sized grid)!
            momentary[x][y] = false -- the state of each key is 'off'
            basemap[x][y] = 0 -- the background UI is 'off'
        end
    end
    make_ui_basemap(start_x,start_y, params:get("mode"), params:get("alt_mode")) -- populate the basemap table
    draw_basemap()
    redraw()
    g:refresh()
    clock.run(redraw_clock) -- start the grid redraw clock
    clock.run(sequencer)
end

function redraw_clock() -- our grid redraw clock
    while true do -- while it's running...
        clock.sleep(1/10) -- refresh at 10fps.
        if grid_dirty then -- if a redraw is needed...
            grid_redraw() -- redraw...
            grid_dirty = false -- then redraw is no longer needed.
        end

        if screen_dirty then
            redraw()
            screen_dirty = false
        end
    end
end




function g.key(x,y,z)  -- define what happens if a grid key is pressed or released
    if x == 16 and y == 8 and z == 1 then
        panic()
    end

    -- if a grid key is pressed AND a chord is not currently being held down, flip it's table entry to 'on'
    momentary[x][y] = z == 1 and (not chord_playing) or false 
    

    ---- MODIFIERS ---- 
  -- check the basemap to see if we are on a pressable button
    if basemap[x][y] > 0 then
        -- is x between 1 and 3 inclusive, aka the modifier buttons
        if x >= 1 and x <= 4 then

            if y == 8 then
                -- if holding the middle button, then change the base octave
                if momentary[2][8] then
                    params:set("octave",z==1 and params:get("octave")+(x-2) or params:get("octave"))
                end
                -- otherwise, just do a momentary octave shift
                momentary_octave = z == 1 and params:get("octave") + (x-2) or params:get("octave")

            elseif y ==7 then
                -- momentarily change the inversion, otherwise leave it at the default set in the params
                momentary_inversion = z == 1 and x-1 or params:get("inversion")

            elseif y == 5 then
                -- not sure yet
            end
        end

        ---- CHORD BUTTONS ----
        -- are we on the chord buttons?
        if x >= start_x and x <= start_x+7 and y>=3 then
            -- if releasing the previous chord, then allow to proceed
            if (not chord_playing==false) then

                -- check to see if the key being released is the same as the one that was pressed
                if chord_playing[1] == x and chord_playing[2] == y and z==0 then
                    chord_playing = false

                end
            end

            if (chord_playing==false) then
                play_chord(y-start_y, x - start_x + 1, z)
                chord_playing = z==1 and {x,y} or false
            end
        end

        grid_dirty = true -- flag for redraw
    end


    ---- SEQUENCER ----
    if y == 1 and z == 1 then
        -- if already a step, then clear it. If not, then load most recently played chord
        if seq[x] then
            seq[x] = false
        else
            seq[x] = prev_chord
        end
 
        grid_dirty = true
    end

    if y == 2 and z == 1 then
        if x == 1 then
            if seq_running then
                seq_running = false
                current_step = 0
                panic()
            else
                seq_running = true
                clock.run(sequencer)
            end
        end

    end
end

function enc(n,d)
    if n == 2 then
        params:delta("transpose", d)
    end

    if n == 3 then
        params:delta("mode", d)
    end
    screen_dirty = true
end

function play_chord(row,degree,z)

    -- if we are letting go of a button, just turn off the current set of notes
    if z == 0 then
        notes_to_engine(notes, z)

    -- if we are pressing a button, figure out the new set of notes
    else
        -- first stop the last chord just to be safe
        --notes_to_engine(notes, 0)
        notes_to_engine(prev_chord, 0)

        local root = momentary_octave*12 + params:get("transpose")
        local current_scale  = musicutil.generate_scale(root, mode_index_to_name(params:get("mode")),1)

        -- get the notes for the base chord

        -- main chord row
        if row == 0 then
            notes = musicutil.generate_chord_scale_degree(root, mode_index_to_name(params:get("mode")), degree, false)

            Chordname = get_chord_name(notes[1], params:get("mode"), degree, momentary_inversion)
        end


        -- secondary dominant row
        if row == -2 then
            -- the root of the secondary dominant the first note in the chord we would be playing
            secondary_dominant_root = musicutil.generate_chord_scale_degree(root, mode_index_to_name(params:get("mode")), degree, false)[1]

            -- then we get the five chord in that key
            -- play it down an octave and as a 7th by default
            notes = musicutil.generate_chord_scale_degree(secondary_dominant_root - 12, "Major", 5, true)
            Chordname = get_chord_name(notes[1], 1, 5+7, 0)
        end

        -- secondary mode
        if row == -1 then
            notes = musicutil.generate_chord_scale_degree(root, mode_index_to_name(params:get("alt_mode")), degree, false)
            Chordname = get_chord_name(notes[1],params:get("alt_mode"), degree, momentary_inversion)
        end

        -- seventh chord row
        if row == 1 then
            notes = musicutil.generate_chord_scale_degree(root,  mode_index_to_name(params:get("mode")), degree, true)
            Chordname = get_chord_name(notes[1], params:get("mode"), degree+7, momentary_inversion)
        end

        -- sus 4
        if row == 2 then
            notes = musicutil.generate_chord(current_scale[degree], musicutil.CHORDS[params:get("chord2")]["name"], momentary_inversion)
            local chordtype = get_short_chord_name(params:get("chord2"))

            Chordname = musicutil.note_num_to_name(notes[1],false).. " " .. chordtype


        end


        -- modifications -- 
        -- doing the bass note addition in a weird order so it's not affected by inversion, could think of a better way to do this
        bass_note = notes[1]-12

        --invert chord as specified
        notes = invert_chord(notes, momentary_inversion)

        if params:get("bass_note") == 2 then
            notes[#notes+1] = bass_note
        end

        -- sort the notes in ascending order so that a strum will play correctly
        table.sort(notes)
        
        notes_to_engine(notes, z)
        

        
    end
    
    screen_dirty = true
end



function get_chord_name(rootnote, mode, degree, inversion)
    local chord_name = musicutil.note_num_to_name(rootnote,false)

    local modifier = chord_lookup[mode]["quality"][degree]
    return (chord_name .. modifier)
end



function notes_to_engine(notes, on_or_off)
    
    if on_or_off == 1 then
        clock.run(function()
            for i = 1, #notes do
                local player = params:lookup_param("voice"):get_player()
                player:note_on(notes[i], 1)
                if params:get("humanize") > 0 then
                    clock.sleep(math.random(math.floor(params:get("humanize")/2),params:get("humanize"))/1000)
                end
            end
        end)
    else
        for i = 1, #notes do
            local player = params:lookup_param("voice"):get_player()
            player:note_off(notes[i])
        end
    end

    

    -- if we just turned off all the notes, then clear the notes table
    if on_or_off == 0 then
        prev_chord = notes
        notes = {}
    end
end


function sequencer()
    local playing_seq_chord = {}
    -- current default is to hold chord until the next chord is played, 
    -- hopefully a more customizable option in the future

    while seq_running do
        -- every clock step, play the current step and advance current_step
        clock.sync(params:get("seq_step"))
        --print(current_step)
        -- check to see if the table at the current step is not empty

        -- if we have a chord in this step...
        if seq[current_step] then

            -- send off notes from the previous chord
            notes_to_engine(playing_seq_chord, 0)
            -- play the new chord
            notes_to_engine(seq[current_step], 1)
            playing_seq_chord = seq[current_step]

        end 
        current_step = current_step + 1


        if current_step > 16 then
            current_step = 1
        end
        grid_dirty = true
        
    end
end



function grid_redraw() -- how we redraw
    --g:all(0) -- turn off all the LEDs
    draw_basemap()
    


    -- draw the sequencer steps

    for x = 1,16 do -- for each column...
        for y = 1,8 do -- and each row...
            if momentary[x][y] then -- if the key is held...
                g:led(x,y,15) -- turn on that LED!
            else
                g:led(x,y,basemap[x][y]) -- otherwise, turn it back to the basemap color
            end
        end
    end


    for i = 1, 16 do
        -- light up the steps that are active
        if seq[i] then
            g:led(i,1,9)
        end
        -- and the current step playing in the sequence
        if i == (current_step-1) then
            g:led(i,1,15)
        end
    end

    g:refresh() -- refresh the hardware to display the LED state

    
end


function redraw() -------------- redraw() is automatically called by norns
    rowheight = 8
    screen.clear() --------------- clear space
    draw_piano(notes)
    screen.aa(1) ----------------- enable anti-aliasing
    screen.font_face(1) ---------- set the font face to "04B_03"
    screen.font_size(16) ---------- set the size to 8
    screen.level(15) ------------- max
    screen.move(10, 32) ---------- move the pointer to x = 64, y = 32
    screen.text(Chordname) -- center our message at (64, 32)

    -- draw a little grid map
    readout_x = 64
    readout_y = 8


    for x = 1, 7 do
        for y = 0, 4 do
            --absolute value of y-4 times 3

            rect(x*rowheight+45, y*rowheight+readout_y-1, 5, 5,2)
        end
    end

    screen.level(15)
    screen.font_size(8) ---------- set the size to 8
    

    screen.move(readout_x+42, readout_y + rowheight*1-4)
    screen.text_right("2nd Dom.")
    screen.move(readout_x+42, readout_y + rowheight*2-4)
    screen.text_right(mode_index_to_name(params:get("alt_mode")))
    screen.font_size(8)
    screen.move(readout_x-10, readout_y + rowheight*3-4)
    screen.text(transpose_string(params:get("transpose")))
    screen.move(readout_x+1, readout_y + rowheight*3-4)
    screen.text(mode_index_to_name(params:get("mode")))
    screen.font_size(8)
    screen.move(readout_x+42, readout_y + rowheight*4-4)
    screen.text_right("7th")
    screen.move(readout_x+42, readout_y + rowheight*5-4)
    screen.text_right(get_short_chord_name(params:get("chord2")))


    -- screen.pixel(0, 0) ----------- make a pixel at the north-western most terminus
    -- screen.pixel(127, 0) --------- and at the north-eastern
    -- screen.pixel(127, 63) -------- and at the south-eastern
    -- screen.pixel(0, 63) ---------- and at the south-western
    screen.fill() ---------------- fill the termini and message at once
    screen.update() -------------- update space
  end




function panic()
    print("panic")
    nb:stop_all()
    for i = 0, 127 do
        local player = params:lookup_param("voice"):get_player()
        player:note_off(i)
    end
end




function make_ui_basemap(x_start, y_start, mode, alt_mode)
    lev1 = 3
    lev2 = 6
    lev3 = 9
    lev4 = 12

    -- sequencer
    for x = 1, 16 do
        basemap[x][1] = lev1
        
    end

    --- sequencer controls
    basemap[1][2] = lev1



    -- main keyboard region
    -- for x = (x_start),(x_start+6) do
    --     basemap[x][y_start-2] = lev1
    --     basemap[x][y_start-1] = lev1
    --     basemap[x][y_start] = lev3
    --     basemap[x][y_start+1] = lev1
    --     basemap[x][y_start+2] = lev1
    --     basemap[x][y_start+3] = lev1
    -- end

    -- get the first 7 entries of the quality table for the mode
    modifiers = chord_lookup[mode]["quality"]
    alt_modifiers = chord_lookup[alt_mode]["quality"]
    for i = 1, 7 do
        basemap[x_start+i-1][y_start-2] = lev2

        if modifiers[i] == "" then
            basemap[x_start+i-1][y_start] = lev4

            basemap[x_start+i-1][y_start+1] = lev2
            basemap[x_start+i-1][y_start+2] = lev2
        else
            basemap[x_start+i-1][y_start] = lev3

            basemap[x_start+i-1][y_start+1] = lev1
            basemap[x_start+i-1][y_start+2] = lev1

        end

        if alt_modifiers[i] == "" then
            basemap[x_start+i-1][y_start-1] = lev2
        else
            basemap[x_start+i-1][y_start-1] = lev1
        end

    end

    -- modifyer area

    -- modulation 
    -- basemap[1][5] = lev3
    -- basemap[2][5] = 1
    -- basemap[3][5] = lev3


    -- inversions
    basemap[1][7] = lev1
    basemap[2][7] = lev2
    basemap[3][7] = lev3
    -- basemap[4][7] = lev3 + 3

    -- octaves
    basemap[1][8] = lev3
    basemap[2][8] = 1
    basemap[3][8] = lev3
end
