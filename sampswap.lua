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
include("sampswap/lib/utils")
UI=require("ui")
if not string.find(package.cpath,"/home/we/dust/code/sampswap/lib/") then
  package.cpath=package.cpath..";/home/we/dust/code/sampswap/lib/?.so"
end
json=require("cjson")
local lattice_=require("lattice")
sample_=include("sampswap/lib/sample")
-- local crowseq=include("sampswap/lib/crowseq")

engine.name="Sampswap"

SENDOSC="/home/we/dust/data/sampswap/sendosc"
WORKDIR="/tmp/sampswap/"
NRTREADY="/tmp/nrt-scready"
PROGRESSFILE="/tmp/sampswap/progress"
INSTALLINGFILE="/tmp/sampswap_installing"

shift=false
global_progress_file_exists=false
global_installing_file_exists=true

function init()
  loading=true
  samplei=1
  sample=nil

  current_tempo=clock.get_tempo()
  lattice=lattice_:new()
  lattice_beats=-1
  pattern=lattice:new_pattern{
    action=function(t)
      if global_installing_file_exists then
        do return end
      end
      loading=not util.file_exists(NRTREADY)
      if sample==nil then
        sample={}
        for i=1,4 do
          sample[i]=sample_:new{id=i}
        end
        params:default()
        for i=1,4 do
          sample[i]:default()
        end
      end
      lattice_beats=lattice_beats+1
      local tozero={}
      if sample~=nil then 
        for i,smpl in ipairs(sample) do
          if smpl:update_beat(lattice_beats) then
            table.insert(tozero,i)
          end
        end
      end
      if #tozero==1 then
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
  -- if norns.crow.connected() then
  --   cs=crowseq:new()
  --   crowpattern=lattice:new_pattern{
  --     action=function(t)
  --       cs:emit()
  --     end,
  --     division=1/16,
  --   }
  -- end
  lattice:start()

  -- startup scripts
  startup_clock=clock.run(function()
    os.execute(_path.code.."sampswap/lib/install.sh 2>&1 | tee /tmp/sampswap.log &")
  end)
  clock_redraw=clock.run(function()
    while true do
      clock.sleep(1/10)
      if global_installing_file_exists then
        global_installing_file_exists=util.file_exists(INSTALLINGFILE)
      else
        if sample~=nil and sample[samplei]~=nil then
          sample[samplei]:update()
        end
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
    samplei=util.clamp(samplei+d,1,4)
  elseif k==2 then
    for i=1,4 do
      sample[i]:option_sel_delta(samplei,d)
    end
  elseif k==3 then
    sample[samplei]:option_set_delta(d)
  end
end

function key(k,z)
  if k==1 then
    shift=z==1
  elseif k==2 and z==1 then
    if loading then
      do return end
    end
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
  screen.clear()
  screen.aa(0)
  if global_installing_file_exists then
    screen.move(64,32)
    screen.text_center("installing sampswap...")
  else
    if sample~=nil and sample[samplei]~=nil then
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
    for _,smpl in ipairs(sample) do
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
