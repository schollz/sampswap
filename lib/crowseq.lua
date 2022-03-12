local CrowSeq={}

local lattice_=require("lattice")
local musicutil=require("musicutil")

function CrowSeq:new (o)
  o=o or {}
  setmetatable(o,self)
  self.__index=self
  o.s=require("sequins")
  o.last_accent=0

  crow.output[1].volts=1
  params:add_control("acid_slide","slide",controlspec.new(0,0.5,'lin',0.01,0.0,'s',0.01/0.5))
  params:add_control("acid_envmod","env mod",controlspec.new(0.1,10,'lin',0.1,5,'v',0.1/10))
  params:add_control("acid_accent","accent",controlspec.new(0.01,6,'lin',0.01,0.7,'v',0.01/5))
  params:add_control("acid_decay","decay",controlspec.new(0,1000,'lin',1,210,'ms',1/1000))
  params:bang()

  o.scale={1,2,3,4,6,8,9,11}
  o.notes=o.s{6,2,2,0,6,0,8,7,2,0,2,0,3,7,3,0}
  o.accen=o.s{1,0,0,0,0,0,0,1,0,0,0,0,0,0,0,1}
  o.slide=o.s{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
  return o
end

function CrowSeq:get_matrix()

end

function CrowSeq:grid_press(rrow,col)
  local notes=o.notes.data
  local accen=o.accen.data
  local slide=o.slide.data
  local row=9-row
  if notes[col]==row then
    if accen[col]==1 then
      if slide[col]==1 then
        -- turn note off
        notes[col]=0
      else
        slides[col]=1
      end
    else
      accen[col]=1
    end
  else
    notes[col]=row
  end
end

function CrowSeq:update_crow(is_accent)
  -- pitch envelope output: Sharp attack, exponential decay, fixed decay and rather long time
  -- envelope is increased if accented
  local env_max=util.clamp(5+(is_accent and params:get("acid_accent") or 0),0.01,10)
  crow.output[2].action="{ to("..env_max..",0.003,logarithmic), to(0.01,2,exponential) }"

  -- pitch envelope output: It too has sharp attack and exponential decay.
  local filt_max=util.clamp(params:get("acid_envmod")+(is_accent and params:get("acid_accent") or 0),0.01,10)
  if is_accent then
    -- On accented notes, decay runs relatively short time, corresponding to decay full CCW
    self.last_accent=self.last_accent+0.1
    filt_max=util.clamp(filt_max+self.last_accent,0,10)
  else
    -- On normal notes, there is a variable time, controlled by the Decay pot.
    self.last_accent=0
  end
  crow.output[3].action="{ to("..filt_max..",0.003,logarithmic), to(0.01,"..(params:get("acid_decay")/1000)..",exponential) }"
end

function CrowSeq:emit()
  local note=self.notes()
  if note==0 then
    do return end
  end
  if self.slide()==1 then
    crow.output[1].slew=clock.get_beat_sec()/4
  else
    crow.output[1].slew=0
  end
  local accent=self.accen()==1
  update_crow(accent)
  crow.output[1].volts=scale[note]/12
  crow.output[2]()
  crow.output[3]()
end

return CrowSeq
