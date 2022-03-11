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
global_progress_file_exists=false

function init()
  loading=true
  samplei=1
  sample=nil

  current_tempo=clock.get_tempo()
  lattice=lattice_:new()
  lattice_beats=-1
  pattern=lattice:new_pattern{
    action=function(t)
      loading=not util.file_exists(NRTREADY)
      if loading then
        do return end 
      end
      if sample==nil then 
        sample={}
        for i=1,3 do
          sample[i]=sample_:new{id=i}
        end
        params:default()
      end
      if clock.get_tempo()~=current_tempo then
        current_tempo=clock.get_tempo()
        for i,smpl in ipairs(sample) do
          smpl:determine_index_max()
        end
      end
      lattice_beats=lattice_beats+1
      local tozero={}
      for i,smpl in ipairs(sample) do
        if smpl:update_beat(lattice_beats) then 
          table.insert(tozero,i)
        end
      end
      if #tozero==1 then 
        print("tozero1",tozero[1])
        engine.tozero1(tozero[1])
      elseif #tozero==2 then 
        engine.tozero2(tozero[1],tozero[2])
      elseif #tozero==3 then 
        engine.tozero3(tozero[1],tozero[2],tozero[3])
      end
      global_progress_file_exists=util.file_exists(PROGRESSFILE)
      if global_progress_file_exists then 
        progress_current=tonumber(util.os_capture("tail -n1 "..PROGRESSFILE))
      else
        progress_current=nil
      end
    end,
    division=1/4
  }
  lattice:start()

  -- startup scripts

  startup_clock=clock.run(function()
    os.execute(_path.code.."sampswap/lib/install.sh 2>&1 | tee /tmp/sampswap.log &")
  end)
  clock_redraw=clock.run(function()
    while true do 
      clock.sleep(1/10)
      if sample~=nil then 
        sample[samplei]:update()
      end
      redraw()
    end
  end)
end

function enc(k,d)
  if loading then 
    do return end 
  end
  if d>0 then 
    d=1 
  elseif d<0 then 
    d=-1
  end
  if k==1 then
    samplei=util.clamp(samplei+d,1,3)
  elseif k==2 then
    for i=1,3 do 
      sample[i]:option_sel_delta(samplei,d)
    end
  elseif k==3 then
    sample[samplei]:option_set_delta(d)
  end
end

function key(k,z)
  if loading then 
    do return end 
  end
  if k==1 then
    shift=z==1
  elseif k==2 and z==1 then
    sample[samplei]:swap()
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
  if loading then
    local progress_val=util.os_capture("wc -l < /tmp/sampswap.log")
    progress_val=tonumber(progress_val)
    progress_val=progress_val or 0 
    progress_val=util.round(progress_val/71*100)
    if progress_val==last_progress_val then 
      do return end 
    end
    screen.clear()
    screen.aa(0)
    last_progress_val=progress_val
    local slider=UI.Slider.new(0,0,128,9,0,0,100,{},"right")
    screen.level(15)
    slider.active=true
    slider:set_value(progress_val)
    slider:redraw()
    screen.update()
    screen.blend_mode(1)
    screen.level(15)
    screen.move(64,7)
    screen.text_center("loading...")
    screen.update()
    screen.blend_mode(0)
    screen.level(15)
    screen.move(64,18)
    screen.text_center(util.os_capture("cat /tmp/sampswap.log | grep . | cat | cut -c -30 | tail -n5  | head -n1"))
    screen.move(64,28)
    screen.text_center(util.os_capture("cat /tmp/sampswap.log | grep . | cat | cut -c -30 | tail -n4 | head -n1"))
    screen.move(64,38)
    screen.text_center(util.os_capture("cat /tmp/sampswap.log | grep . | cat | cut -c -30 | tail -n3 | head -n1"))
    screen.move(64,48)
    screen.text_center(util.os_capture("cat /tmp/sampswap.log | grep . | cat | cut -c -30 | tail -n2 | head -n1"))
    screen.move(64,58)
    screen.text_center(util.os_capture("cat /tmp/sampswap.log | grep . | cat | cut -c -30 | tail -n1"))
  else
    screen.clear()
    screen.aa(0)
    if sample~=nil then 
      sample[samplei]:redraw(sample,progress_current)
    end
  end
  screen.update()
end

function cleanup()
  print("cleaning up script...")
  os.execute("/home/we/dust/code/sampswap/lib/cleanup.sh")
  if lattice~=nil then 
    if lattice.superclock_id~=nil then
      print("canceling lattice clock")
      clock.cancel(lattice.superclock_id)
    end
  end
  if sample~=nil then 
    for _, smpl in ipairs(sample) do
      if smpl.cmd_clock~=nil then 
        clock.cancel(smpl.cmd_clock)
      end
    end
  end
  if clock_redraw~=nil then 
    clock.cancel(clock_redraw)
  end
  if startup_clock~=nil then 
    clock.cancel(startup_clock)
  end
  print("finished cleaning")
end
