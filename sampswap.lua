-- sampswap v2.0.0
-- bysplicing
--
-- llllllll.co/t/sampswap
--
--
--
--    ▼ instructions below ▼
--
-- K2 generates beat
-- K3 toggles beat
-- E changes sample
lattice_=require("lattice")
sample_=include("sampswap/lib/sample")

engine.name="Sampswap"

SENDOSC="/home/we/dust/data/sampswap/sendosc"
WORKDIR="/tmp/sampswap/"
NRTREADY="/tmp/nrt-scready"
PROGRESSFILE="/tmp/sampswap/progress"

shift=false

function init()
  sample={}
  for i=1,3 do
    sample[i]=sample_:new{id=i}
  end

  current_tempo=clock.get_tempo()
  lattice=lattice_:new()
  lattice_beats=-1
  pattern=lattice:new_pattern{
    action=function(t)
      if clock.get_tempo()~=current_tempo then
        current_tempo=clock.get_tempo()
        for i,smpl in ipairs(sample) do
          smpl:determine_index_max()
        end
      end
      lattice_beats=lattice_beats+1
      for i,smpl in ipairs(sample) do
        smpl:update()
      end
      redraw()
    end,
    division=1/4
  }
  lattice:start()

  params:default()

  -- startup scripts
  norns.system_cmd(_path.code.."sampswap/lib/install.sh",function(x)
    loading=false
  end)
  os.execute("rm -rf "..WORKDIR)
  os.execute("rm -f "..NRTREADY)
  os.execute(SENDOSC..' --host 127.0.0.1 --addr "/quit" --port 57113')
  if clock_startup~=nil then
    clock.cancel(clock_startup)
  end
  clock_startup=clock.run(function()
    os.execute("cd /home/we/dust/code/sampswap/lib && sclang sampswap_nrt.supercollider &")
  end)
end

function filename_from_index(basename,index)
  local tempo=math.floor(clock.get_tempo())
  return _path.audio.."sampswap/"..basename.."_bpm"..tempo.."_"..index..".wav"
end

function get_max_index(basename)
  local tempo=math.floor(clock.get_tempo())
  local mi=0
  for i=1,1000 do
    if not util.file_exists(filename_from_index(basename,i)) then
      break
    end
    mi=i
  end
  return mi
end

function toggle_sample(i)
  print("toggling sample "..i)
  sample[i].playing=not sample[i].playing
  if not sample[i].playing then
    engine.amp(i,0)
  else
    engine.amp(i,1)
    sample[i].debounce_index=1
  end
end

function enc(k,d)
  if k==2 then
    samplei=util.clamp(samplei+(d>0 and 1 or-1),1,3)
  elseif k==3 then
    d=d>0 and 1 or-1
    sample[samplei].index=util.clamp(sample[samplei].index+d,0,max_index)
    if sample[samplei].playing then
      sample[samplei].debounce_index=4
    end
  end
end

function key(k,z)
  if k==1 then
    shift=z==1
  elseif k==2 and z==1 then
  elseif k==3 and z==1 then
    if shift then
      lattice_beats=-1
      lattice:hard_restart()
    else
    end
  end

end

function redraw()
  screen.clear()
  for i=1,3 do
    local x=128/4*i-4
    local icon=UI.PlaybackIcon.new(x,1,6,4)
    screen.level(samplei==i and 15 or 4)
    icon.status=sample[i].playing and 1 or 4
    icon:redraw()
    screen.level(samplei==i and 15 or 4)
    screen.move(x+3,15)
    screen.text_center(""..(sample[i].index==0 and "none" or sample[i].index))
  end
  screen.level(15)
  if loading==true then
    screen.move(64,32)
    screen.text_center("loading, please wait . . . ")
  else
    if progress_file_exists then
      draw_progress()
    else
      if making_beat~=nil then
        sample[making_beat].debounce_index=4
        making_beat=nil
        max_index=get_max_index()
      end
      screen.move(64,32-5)
      screen.text_center("press K2 to generate")
      screen.move(64,32+5)
      screen.text_center("press K3 to stop/start")
    end
  end
  screen.update()
end

slider=UI.Slider.new(4,55,118,8,0,0,100,{},"right")
slider.label="progress"
function draw_progress()
  local _,filename,_=os.splitpath(params:get("break_file"))
  screen.move(64,32-5)
  screen.text_center(string.format("generating beat from"))
  screen.move(64,32+5)
  screen.text_center(string.format("'%s'",filename))
  local progress=tonumber(util.os_capture("tail -n1 "..PROGRESSFILE))
  if progress==nil then
    do
      return
    end
  end
  slider:set_value(progress)
  slider:redraw()
end

function cleanup()
  print("cleaning up script...")
  os.execute(SENDOSC..' --host 127.0.0.1 --addr "/quit" --port 57113')
  os.execute("rm -rf "..WORKDIR)
  os.execute("rm -f "..NRTREADY)
  if lattice.superclock_id~=nil then
    print("canceling lattice clock")
    clock.cancel(lattice.superclock_id)
  end
  if cmd_clock~=nil then
    print("canceling clock cmd")
    clock.cancel(cmd_clock)
  end
  if clock_startup~=nil then
    print("canceling clock startup")
    clock.cancel(clock_startup)
  end
  print("finished cleaning")
end
