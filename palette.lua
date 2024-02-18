-- chord player thing
--
--
-- wayk

include('lib/ui')
include('lib/music_tools')
musicutil = require("musicutil")
mxsamples=include("mx.samples/lib/mx.samples")
engine.name="MxSamples"
instruments = {}


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


chordname = ""
momentary_inversion = 0
momentary_octave = 3
notes  = {}
chord_playing = false
steps_in_scale = {0,2,4,5,7,9,11}

--scale_shape = [lev1,lev2]

function add_params()
    skeys=mxsamples:new()
    instruments = skeys:list_instruments()
    params:add_option("mx_ins", "MX.INSTRUMENT", instruments, 10)

    
    params:add_number("transpose", "Key", 0, 11, 0, function(param) return transpose_string(param:get()) end)
    params:add_number('mode', 'Mode', 1, 9, 1, function(param) return mode_index_to_name(param:get()) end)
    params:add_number('octave', 'Octave', 0, 8, 3)
    params:add_number('inversion' , 'Inversion', 0, 2, 0)
    params:add_option('bass_note', 'Bass Note', {'no', 'yes'}, 2)

    params:add_number('alt_mode', 'Secondary Mode', 1, 9, 2, function(param) return mode_index_to_name(param:get()) end)


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

    
end
add_params()




function init()
    grid_dirty = false -- script initializes with no LEDs drawn
    screen_dirty = false
    momentary = {} -- meta-table to track the state of all the grid keys
    basemap = {} -- the background UI to display when no notes are pressed


    for x = 1,16 do -- for each x-column (16 on a 128-sized grid)...
        momentary[x] = {} -- create a table that holds...
        basemap[x] = {}     
        for y = 1,8 do -- each y-row (8 on a 128-sized grid)!
            momentary[x][y] = false -- the state of each key is 'off'
            basemap[x][y] = 0 -- the background UI is 'off'
        end
    end
    make_ui_basemap(start_x,start_y) -- populate the basemap table
    draw_basemap()
    redraw()
    clock.run(redraw_clock) -- start the grid redraw clock
end

function redraw_clock() -- our grid redraw clock
    while true do -- while it's running...
        clock.sleep(1/30) -- refresh at 30fps.
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

function grid_redraw() -- how we redraw
    --g:all(0) -- turn off all the LEDs
    draw_basemap()
    for x = 1,16 do -- for each column...
        for y = 1,8 do -- and each row...
            if momentary[x][y] then -- if the key is held...
                g:led(x,y,15) -- turn on that LED!
            else
                g:led(x,y,basemap[x][y]) -- otherwise, turn it back to the basemap color
            end
        end
    end
    g:refresh() -- refresh the hardware to display the LED state

    
end


function g.key(x,y,z)  -- define what happens if a grid key is pressed or released

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

                if momentary[2][5] then
                    baseroot = z==1 and baseroot + (4*(x-2)) or baseroot
                end
                
                root = z == 1 and baseroot+(4*(x-2)) or baseroot 

            end


        end


        -- are we on the chord buttons?
        if x >= start_x and x <= start_x+7 then
            -- if releasing the previous chord, then allow to proceed
            if (not chord_playing==false) then

                -- check to see if the key being released is the same as the one that was pressed
                if chord_playing[1] == x and chord_playing[2] == y and z==0 then
                    chord_playing = false

                end
            end

            if (chord_playing==false) then
                play_chord(y-start_y, x - start_x + 1, z)
                
                -- -- tritone substitution
                -- if y == 3 then
                --     --play_chord(root+1, x-4, true, false,inversion,z)
                
                    chord_playing = z==1 and {x,y} or false
            end
            
        end

        
        momentary[x][y] = z == 1 and true or false -- if a grid key is pressed, flip it's table entry to 'on'


  -- what ^that^ did was use an inline condition to assign our momentary state.
  -- same thing as: if z == 1 then momentary[x][y] = true else momentary[x][y] = false end
        grid_dirty = true -- flag for redraw
    end
end



function play_chord(row,degree,z)
    root = momentary_octave*12 + params:get("transpose")

    -- get the notes for the base chord

    -- main chord row
    if row == 0 then
        notes = musicutil.generate_chord_scale_degree(root, params:get("mode"), degree, false)
    end


    -- secondary dominant row
    if row == -1 then
        -- the root of the secondary dominant the first note in the chord we would be playing
        secondary_dominant_root = musicutil.generate_chord_scale_degree(root, params:get("mode"), degree, false)[1]

        -- then we get the five chord in that key
        -- play it down an octave and as a 7th by default
        notes = musicutil.generate_chord_scale_degree(secondary_dominant_root - 12, "Major", 5, true)
    end
    -- seventh chord row
    if row == 1 then
        notes = musicutil.generate_chord_scale_degree(root, params:get("mode"), degree, true)
    end

    -- secondary mode
    if row == 2 then
        notes = musicutil.generate_chord_scale_degree(root, params:get("alt_mode"), degree, false)
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

    chordname = root + degree
    screen_dirty = true
end


function invert_chord(notes, inversion)
    if inversion == 0 then
        return notes
    elseif inversion == 1 then
        notes[1] = notes[1] + 12
    elseif inversion == 2 then
        notes[1] = notes[1] + 12
        notes[2] = notes[2] + 12
    elseif inversion == 3 then
        notes[1] = notes[1] + 12
        notes[2] = notes[2] + 12
        notes[3] = notes[3] + 12
    end
    return notes
end


function old_play_chord(root, degree, seventh, minor, inversion, on_or_off)
    root = root + params:get("transpose")
    notes = musicutil.generate_chord_scale_degree(root, params:get("mode"), degree, seventh)

    if minor then
        -- check if major or minor
        if notes[2] - notes[1] == 3 then
            notes[2] = notes[2] + 1
        else    
            notes[2] = notes[2] - 1
        end
    end

    -- if inversion is 1, then move the root note up one octave
    if inversion == 0 then
        notes[#notes+1] = notes[1] - 12
    elseif inversion == 1 then
        notes[#notes+1] = notes[1]- 12
        notes[1] = notes[1] + 12
    elseif inversion == 2 then
        notes[#notes+1] = notes[1]- 12
        notes[1] = notes[1] + 12
        notes[2] = notes[2] + 12
    end
        
    -- randomly shuffle the order of the notes
    -- for i = 1, #notes do
    --     j = math.random(i, #notes)
    --     notes[i], notes[j] = notes[j], notes[i]
    -- end

    if on_or_off == 1 then
        clock.run(function()
            for i = 1, #notes do
                skeys:on({name=instruments[params:get("mx_ins")],midi=notes[i],velocity = 70, release=0.5})

                
                -- if notes[i]-baseroot > 0 then
                --     momentary[notes[i]-baseroot][2] = true
                -- end

                -- wait between 1 and 100 ms
                if params:get("humanize") > 0 then
                    clock.sleep(math.random(math.floor(params:get("humanize")/2),params:get("humanize"))/1000)
                end
            end
            -- grid_dirty = true
        end)
    else
        for i = 1, #notes do
            skeys:off({name=instruments[params:get("mx_ins")],midi=notes[i]})

            -- if notes[i]-baseroot > 0 then
            --     momentary[notes[i]-baseroot][2] = false
            -- end

        end
        -- grid_dirty = true
    end

    -- update the piano drawing
    if on_or_off == 1 then

    else
        notes = {}

    end


    
    -- trigger a screen update
    chordname = transpose_string(params:get("transpose")+degree - 1)
    
    screen_dirty = true
end



function send_notes_to_engine(notes, on_or_off)
    --
end






function draw_basemap()
    for x = 1,16 do
        for y = 1,8 do
        g:led(x,y,basemap[x][y])
        end
    end
    g:refresh()
end

-- function redraw()
--     screen.clear()

--     --screen.aa(1)
--     --screen.font_size(10)
--     --screen.move(1,20)
--     --screen.text(chordname)
--     draw_piano(notes)
--     screen.update()

-- end

function redraw() -------------- redraw() is automatically called by norns
    screen.clear() --------------- clear space
    draw_piano(notes)
    screen.aa(1) ----------------- enable anti-aliasing
    screen.font_face(1) ---------- set the font face to "04B_03"
    screen.font_size(8) ---------- set the size to 8
    screen.level(15) ------------- max
    screen.move(64, 32) ---------- move the pointer to x = 64, y = 32
    screen.text_center(chordname) -- center our message at (64, 32)
    screen.pixel(0, 0) ----------- make a pixel at the north-western most terminus
    screen.pixel(127, 0) --------- and at the north-eastern
    screen.pixel(127, 63) -------- and at the south-eastern
    screen.pixel(0, 63) ---------- and at the south-western
    screen.fill() ---------------- fill the termini and message at once

    screen.update() -------------- update space
  end



