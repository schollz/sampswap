-- makebreakbeat v2.0.0
-- bysplicing
--
-- llllllll.co/t/makebreakbeat
--
--
--
--    ▼ instructions below ▼
--
-- K2 generates beat
-- K3 toggles beat
-- E changes sample
lattice_=require("lattice")
UI=require("ui")

engine.name="Makebreakbeat"

PROGRESS_FILE="/tmp/mangler/breaktemp-progress"
progress_file_exists=false
max_index=0
samplei=1
making_beat=nil
shift=false

function os.cmd(cmd)
  print(cmd)
  os.execute(cmd.." 2>&1")
end

audi_o={}
function audi_o.length(fname)
  print("getting length of",fname)
  local s=util.os_capture("sox "..fname.." -n stat 2>&1  | grep Length | awk '{print $3}'")
  return tonumber(s)
end

function init()
  sample={}
  for i=1,3 do
    sample[i]={playing=false,index=0,beats=0,beats_offset=0,debounce_index=nil}
  end
  startup_done=false
  current_tempo=clock.get_tempo()
  max_index=get_max_index()

  params:add{type='binary',name="make beat",id='break_make',behavior='trigger',action=function(v) do_beat(samplei) end}
  params:add_file("break_file","load sample",_path.audio.."makebreakbeat/amen_resampled.wav")
  params:add{type="number",id="break_beats",name="beats",min=16,max=128,default=32}
  do_params()

  lattice=lattice_:new()
  lattice_beats=-1
  pattern=lattice:new_pattern{
    action=function(t)
      if clock.get_tempo()~=current_tempo then
        current_tempo=clock.get_tempo()
        max_index=get_max_index()
      end
      lattice_beats=lattice_beats+1
      for i=1,3 do
        if sample[i].beats>0 then
          if (lattice_beats-sample[i].beats_offset)%sample[i].beats==0 then
            print("mbb: resetting sample "..i)
            engine.tozero(i)
          end
        end
        if sample[i].debounce_index~=nil then
          sample[i].debounce_index=sample[i].debounce_index-1
          if sample[i].debounce_index==0 then
            sample[i].debounce_index=nil
            if sample[i].index>0 then
              local fname=filename_from_index(sample[i].index)
              print("loading "..fname)
              if util.file_exists(fname) then
                engine.load_track(i,fname)
                sample[i].beats=audi_o.length(fname)/(60/clock.get_tempo())
              end
            end
          end
        end
      end
      progress_file_exists=util.file_exists(PROGRESS_FILE)
      redraw()
    end,
    division=1/4
  }
  lattice:start()

  params:default()

  do_startup()
end

function filename_from_index(index)
  local tempo=math.floor(clock.get_tempo())
  return _path.audio.."makebreakbeat/"..tempo.."_"..index..".wav"
end

function get_max_index()
  local tempo=math.floor(clock.get_tempo())
  local mi=0
  for i=1,1000 do
    if not util.file_exists(filename_from_index(i)) then
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
    do_beat(samplei)
  elseif k==3 and z==1 then
    if shift then
      lattice_beats=-1
      lattice:hard_restart()
    else
      if not (sample[samplei].index==0 and sample[samplei].playing==false) then
        toggle_sample(samplei)
      end
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
  local _,filename,_=string.match(params:get("break_file"),"(.-)([^\\/]-%.?([^%.\\/]*))$")
  screen.move(64,32-5)
  screen.text_center(string.format("generating beat from"))
  screen.move(64,32+5)
  screen.text_center(string.format("'%s'",filename))
  local progress=tonumber(util.os_capture("tail -n1 "..PROGRESS_FILE))
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
  do_cleanup()
end

-- specific

function do_params()
  break_options={
    {"reverse",10},
    {"stutter",20},
    {"pitch",5},
    {"reverb",5},
    {"revreverb",5},
    {"jump",20},
  }
  for _,op in ipairs(break_options) do
    params:add{type="number",id="break_"..op[1],name=op[1],min=0,max=100,default=op[2]}
  end
  params:add_option("break_tapedeck","tapedeck",{"no","yes"})
end

function do_startup()
  norns.system_cmd(_path.code.."makebreakbeat/lib/install.sh",function(x)
    loading=false
  end)
  os.execute("mkdir -p ".._path.audio.."makebreakbeat")
  if not util.file_exists(_path.audio.."makebreakbeat/amen_resampled.wav") then
    os.execute("cp ".._path.code.."makebreakbeat/lib/amen_resampled.wav ".._path.audio.."makebreakbeat/")
  end
  os.cmd("chmod +x /home/we/dust/code/makebreakbeat/lib/sendosc")
  os.cmd("rm -rf /tmp/mangler")
  -- os.cmd("pkill -f 'sampswap_nrt'")
  os.cmd("rm -f /tmp/nrt-scready")
  os.cmd('/home/we/dust/code/makebreakbeat/lib/sendosc --host 127.0.0.1 --addr "/quit" --port 57113')
  if clock_startup~=nil then
    clock.cancel(clock_startup)
  end
  clock_startup=clock.run(function()
    os.execute("cd /home/we/dust/code/makebreakbeat/lib && sclang sampswap_nrt.supercollider &")
  end)
  startup_done=true
end

function do_beat(si)
  if util.file_exists("/tmp/mangler/breaktemp-progress") or making_beat~=nil then
    do
      return
    end
  end
  params:write()
  making_beat=si
  sample[si].index=max_index+1
  local tempo=math.floor(clock.get_tempo())
  local fname=filename_from_index(max_index+1)
  local cmd="cd ".._path.code.."makebreakbeat/lib/ && lua mangler.lua --server-started"
  cmd=cmd.." -t "..tempo.." -b "..params:get("break_beats")
  cmd=cmd.." -o "..fname.." ".." -i "..params:get("break_file")
  for _,op in ipairs(break_options) do
    cmd=cmd.." --"..op[1].." "..params:get("break_"..op[1])
  end
  if util.file_exists("/usr/share/SuperCollider/Extensions/PortedPlugins/AnalogTape_scsynth.so") and
    params:get("break_tapedeck")==2 then
    cmd=cmd.." -tapedeck"
  end
  cmd=cmd.." &"
  print(cmd)
  if cmd_clock~=nil then
    clock.cancel(cmd_clock)
  end
  cmd_clock=clock.run(function()
    os.execute(cmd)
  end)
  print("running command!")
end

function do_cleanup()
  os.cmd('/home/we/dust/code/makebreakbeat/lib/sendosc --host 127.0.0.1 --addr "/quit" --port 57113')
  os.cmd("rm -f /tmp/nrt-scready")
  os.cmd("rm -rf /tmp/mangler")
  --os.cmd("pkill -f 'sampswap_nrt'")
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
