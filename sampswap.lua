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
UI=require("ui")

engine.name="Sampswap"

SENDOSC="/home/we/dust/data/sampswap/sendosc"
WORKDIR="/tmp/sampswap/"
NRTREADY="/tmp/nrt-scready"
PROGRESSFILE=PROGRESSFILE

progress_file_exists=false
max_index=0
samplei=1
making_beat=nil
shift=false

function os.cmd(cmd)
  print(cmd)
  os.execute(cmd.." 2>&1")
end

function os.splitpath(s)
  local folder,filename,ext=string.match(s,"(.-)([^\\/]-%.?([^%.\\/]*))$")
  return folder,filename,ext
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
    sample[i]={playing=false,index=0,beats=0,beats_offset=0,debounce_index=nil,index_max=0}
  end
  current_tempo=clock.get_tempo()

  break_options={
    {"reverse",10},
    {"stutter",20},
    {"pitch",5},
    {"reverb",5},
    {"revreverb",5},
    {"jump",20},
  }
  for i=1,3 do
    params:add_group("loop "..i,5+#break_options)
    params:add{type='binary',name="make beat",id='break_make'..i,behavior='trigger',action=function(v) sampleswap(i) end}
    params:add_file("break_file","load sample"..i,_path.audio.."sampswap/amen_resampled.wav")
    params:add{type="number",id="break_beats"..i,name="beats",min=16,max=128,default=32}
    for _,op in ipairs(break_options) do
      params:add{type="number",id="break_"..op[1]..i,name=op[1],min=0,max=100,default=op[2]}
    end
    params:add_option("break_tapedeck"..i,"tapedeck",{"no","yes"})
    params:add_option("break_retempo"..i,"tempo changing",{"speed","timestretch","none"})
  end

  lattice=lattice_:new()
  lattice_beats=-1
  pattern=lattice:new_pattern{
    action=function(t)
      if clock.get_tempo()~=current_tempo then
        current_tempo=clock.get_tempo()
        for i=1,3 do
          sample[i].index_max=get_max_index(sample[i].basename)
        end
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
      progress_file_exists=util.file_exists(PROGRESSFILE)
      redraw()
    end,
    division=1/4
  }
  lattice:start()

  params:default()

  norns.system_cmd(_path.code.."sampswap/lib/install.sh",function(x)
    loading=false
  end)
  os.cmd("rm -rf "..WORKDIR)
  os.cmd("rm -f "..NRTREADY)
  os.cmd(SENDOSC..' --host 127.0.0.1 --addr "/quit" --port 57113')
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
    sampleswap(samplei)
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
  os.cmd(SENDOSC..' --host 127.0.0.1 --addr "/quit" --port 57113')
  os.cmd("rm -rf "..WORKDIR)
  os.cmd("rm -f "..NRTREADY)
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

-- specific

function sampleswap(si)
  if util.file_exists(PROGRESSFILE) or making_beat~=nil then
    do
      return
    end
  end
  params:write()
  making_beat=si
  sample[si].index=max_index+1
  local tempo=math.floor(clock.get_tempo())
  local fname=filename_from_index(max_index+1)
  local cmd="cd ".._path.code.."sampswap/lib/ && lua mangler.lua --server-started"
  cmd=cmd.." -t "..tempo.." -b "..params:get("break_beats")
  cmd=cmd.." -o "..fname.." ".." -i "..params:get("break_file")
  for _,op in ipairs(break_options) do
    cmd=cmd.." --"..op[1].." "..params:get("break_"..op[1])
  end
  if params:get("break_tapedeck")==2 then
    cmd=cmd.." -tapedeck"
  end
  local retempos={"speed","stretch","none"}
  cmd=cmd.." -retempo"..retempos[params:get("break_retempo")].." "
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

