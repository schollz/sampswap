local CrowSeq={}

local musicutil=require("musicutil")

function CrowSeq:new (o)
  o=o or {}
  setmetatable(o,self)
  self.__index=self
  o.last_accent=0

  crow.output[1].volts=1
  params:add_group("crowseq",4)
  params:add_control("acid_slide","slide",controlspec.new(0,0.5,'lin',0.01,0.0,'s',0.01/0.5))
  params:add_control("acid_envmod","env mod",controlspec.new(0.1,10,'lin',0.1,5,'v',0.1/10))
  params:add_control("acid_accent","accent",controlspec.new(0.01,6,'lin',0.01,0.7,'v',0.01/5))
  params:add_control("acid_decay","decay",controlspec.new(0,1000,'lin',1,210,'ms',1/1000))

  o.scale={11,9,8,6,4,3,2,1}--{1,2,3,4,6,8,9,11}
  o.notes={6,2,2,0,6,0,8,7,2,0,2,0,3,7,3,0}
  o.accen={1,0,0,0,0,0,0,1,0,0,0,0,0,0,0,1}
  o.slide={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
  o.ind=1

  -- setup the grid 
  local grid=util.file_exists(_path.code.."midigrid") and include "midigrid/lib/mg_128" or grid
  o.g=grid.connect()
  o.grid_on=true
  o.g.key=function(x,y,z)
    if o.grid_on then
      o:grid_key(x,y,z)
    end
  end
  print("grid columns: "..o.g.cols)

  o.pressed_buttons={}
  o.visual={}
  o.grid_width=16
  for i=1,8 do
    o.visual[i]={}
    for j=1,o.grid_width do
      o.visual[i][j]=0
    end
  end

  -- grid refreshing
  o.grid_refresh=metro.init()
  o.grid_refresh.time=0.03
  o.grid_refresh.event=function()
    if o.grid_on then
      o:grid_redraw()
    end
  end
  o.grid_refresh:start()
  
  return o
end


function CrowSeq:get_visual()
  -- clear visual
  for row=1,8 do
    for col=1,self.grid_width do
        self.visual[row][col]=0
    end
  end

  for col=1,16 do 
    local row=self.notes[col]
    if row>0 then 
      self.visual[row][col]=10
      if self.accen[col]==1 then 
        if row+1<=8 then 
          self.visual[row+1][col]=self.visual[row+1][col]+3
        end
        if row-1>=1 then 
          self.visual[row-1][col]=self.visual[row-1][col]+3
        end
      end
      if self.slide[col]==1 then 
        if col+1<=16 then 
          self.visual[row][col+1]=self.visual[row][col+1]+3
        end
        if col-1>=1 then 
          self.visual[row][col-1]=self.visual[row-1][col-1]+3
        end
      end
    end
  end

  for row=1,8 do 
    self.visual[row][self.ind]=self.visual[row][self.ind]+2
  end

  return self.visual
end

function CrowSeq:grid_redraw()
  local gd=self:get_visual()
  if self.g.rows==0 then
    do return end
  end
  self.g:all(0)
  local s=1
  local e=self.grid_width
  local adj=0
  for row=1,8 do
    for col=s,e do
      if gd[row][col]~=0 then
        self.g:led(col+adj,row,gd[row][col])
      end
    end
  end
  self.g:refresh()
end

function CrowSeq:key_press(row,col,on)
  if on then
    self.pressed_buttons[row..","..col]=1
  else
    self.pressed_buttons[row..","..col]=nil
  end
  if on then 
    self:grid_press(row,col)
  end
end

function CrowSeq:grid_key(x,y,z)
  self:key_press(y,x,z==1)
end

function CrowSeq:reset()
  self.ind=1
end

function CrowSeq:grid_press(row,col)
  if self.notes[col]==row then
    -- changing notes: first accent, then slide, then accent+slide, then note off
    if self.accen[col]==1 and self.slide[col]==1 then
      self.slide[col]=0
      self.accen[col]=0
      self.notes[col]=0
    elseif self.slide[col]==1 then 
      self.accen[col]=1
    elseif self.accen[col]==1 then 
      self.accen[col]=0 
      self.slide[col]=1
    else
      self.accen[col]=1
    end
  else
    self.notes[col]=row
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
  local note=self.notes[self.ind]
  if note>0 then
    if self.slide[self.ind]==1 then
      crow.output[1].slew=clock.get_beat_sec()/4
    else
      crow.output[1].slew=0
    end
    local accent=self.accen[self.ind]==1
    self:update_crow(accent)
    crow.output[1].volts=self.scale[note]/12
    crow.output[2]()
    crow.output[3]()
  end
  self.ind=self.ind+1 
  if self.ind>16 then 
    self.ind=1 
  end
end

return CrowSeq
