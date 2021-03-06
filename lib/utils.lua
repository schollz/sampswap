local charset={}
-- qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890
for i=48,57 do table.insert(charset,string.char(i)) end
for i=65,90 do table.insert(charset,string.char(i)) end
for i=97,122 do table.insert(charset,string.char(i)) end

function string.random(length)
  if length>0 then
    return string.random(length-1)..charset[math.random(1,#charset)]
  else
    return ""
  end
end

function string.random_filename(suffix,prefix)
  suffix=suffix or ".wav"
  prefix=prefix or "/tmp/breaktemp-"
  return prefix..string.random(8)..suffix
end

function audio.silence_trim(fname)
  local fname2=string.random_filename()
  os.execute("sox "..fname.." "..fname2.." silence 1 0.1 0.025% reverse silence 1 0.1 0.025% reverse")
  return fname2
end

function audio.seconds(fname)
  local fname_trimmed=audio.silence_trim(fname)
  local s=""
  if util.file_exists(fname_trimmed) then
    s=util.os_capture("sox "..fname_trimmed.." -n stat 2>&1  | grep Length | awk '{print $3}'")
    os.execute("rm -f "..fname_trimmed)
  else
    s=util.os_capture("sox "..fname.." -n stat 2>&1  | grep Length | awk '{print $3}'")
  end
  local file_seconds=tonumber(s)
  return file_seconds
end

function audio.determine_tempo(path_to_file)
  print("audio.determine_tempo",path_to_file)
  local file_seconds=audio.seconds(path_to_file)
  local closet_bpm={0,100000}
  for bpm=100,200 do
    local measures=file_seconds/((60/bpm)*4)
    local measured_rounded=util.round(measures)
    local dif=math.abs(measured_rounded-measures)
    dif=dif-(measured_rounded%4==0 and measured_rounded/60 or 0)
    --print(bpm,measured_rounded,measures,dif)
    if dif<closet_bpm[2] then
      closet_bpm[2]=dif
      closet_bpm[1]=bpm
    end
  end
  local bpm=nil
  for word in string.gmatch(path_to_file,'([^_]+)') do
    if string.find(word,"bpm") then
      bpm=word:match("%d+")
    end
  end
  if bpm==nil then
    bpm=closet_bpm[1]
  end
  bpm=math.floor(bpm)
  local beats=math.floor(util.round(file_seconds/(60/bpm)))
  return bpm,beats,file_seconds
end

function json_dump(filename,t)
  file=io.open(filename,"w+")
  io.output(file)
  io.write(json.encode(t))
  io.close(file)
end

function json_load(filename)
  local f=io.open(filename,"rb")
  if f==nil then 
    print("json_load: could not open "..filename) 
    do return end 
  end
  local content=f:read("*all")
  f:close()

  local data=json.decode(content)
  return data
end

function os.is_dir(path)
  local f=io.open(path,"r")
  local ok,err,code=f:read(1)
  f:close()
  return code==21
end
