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
local lattice_=require("lattice")
local sample_=include("sampswap/lib/sample")
local UI=require("ui")

engine.name="Sampswap"

SENDOSC="/home/we/dust/data/sampswap/sendosc"
WORKDIR="/tmp/sampswap/"
NRTREADY="/tmp/nrt-scready"
PROGRESSFILE="/tmp/sampswap/progress"

shift=false

function init()
  -- gather the list of known the wav files 
  local file_list={}
  for line in io.lines(_path.data.."sampswap/files.txt") do 
    table.insert(file_list,line)
  end

  loading=true
  samplei=1
  sample={}
  for i=1,3 do
    sample[i]=sample_:new{id=i,file_list=file_list}
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
        smpl:update_beat(lattice_beats)
      end
      if util.file_exists(PROGRESSFILE) then 
        progress_current=tonumber(util.os_capture("tail -n1 "..PROGRESSFILE))
      else
        progress_current=nil
      end
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
    -- os.execute("cd /home/we/dust/code/sampswap/lib && sclang sampswap_nrt.supercollider &")
  end)
  clock_redraw=clock.run(function()
    while true do 
      clock.sleep(1/10)
      sample[samplei]:update()
      redraw()
    end
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
  if d>0 then 
    d=1 
  elseif d<0 then 
    d=-1
  end
  if k==1 then
    samplei=util.clamp(samplei+d,1,3)
  elseif k==2 then
    for i=1,3 do 
      sample[i]:option_sel_delta(d)
    end
  elseif k==3 then
    sample[samplei]:option_set_delta(d)
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
      sample[samplei]:toggle_playing()
    end
  end

end

function redraw()
  screen.clear()

  if loading==true then
    screen.level(15)
    screen.move(64,32)
    screen.text_center("loading, please wait . . . ")
  else
    sample[samplei]:redraw(sample,progress_current)
  end
  screen.update()
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
  if clock_redraw~=nil then 
    clock.cancel(clock_redraw)
  end
  print("finished cleaning")
end
