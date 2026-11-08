local _, SD = ...
local function publicNumber(value)
    return type(value)=="number" and (not issecretvalue or not issecretvalue(value))
end
local function scale(map)
    local width,height
    if C_Map and C_Map.GetMapWorldSize then width,height=C_Map.GetMapWorldSize(map) end
    if not (publicNumber(width) and publicNumber(height) and width>0 and height>0)
        and C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D then
        local function point(x,y)
            local _,p=C_Map.GetWorldPosFromMapPos(map,CreateVector2D(x,y))
            if p then local a,b=p:GetXY() if publicNumber(a) and publicNumber(b) then return a,b end end
        end
        local x,y=point(0,0) local xx,xy=point(1,0) local yx,yy=point(0,1)
        if x and xx and yx then width=((xx-x)^2+(xy-y)^2)^.5 height=((yx-x)^2+(yy-y)^2)^.5 end
    end
    if publicNumber(width) and publicNumber(height) and width>0 and height>0 then return width/100,height/100,true end
    return 1,1,false
end
function SD:GatheringDistanceYards(a,b)
    if not a or not b or a.map~=b.map then return end
    local sx,sy,yards=scale(a.map)
    if yards then return (((a.x-b.x)*sx)^2+((a.y-b.y)*sy)^2)^.5 end
    if a.x==b.x and a.y==b.y then return 0 end
end
local function length(a,b,sx,sy)
    return (((a.x-b.x)*sx)^2+((a.y-b.y)*sy)^2)^.5
end
local function turn(dx,dy,x,y)
    local denominator=(dx*dx+dy*dy)^.5*(x*x+y*y)^.5
    return denominator>0 and 1-math.max(-1,math.min(1,(dx*x+dy*y)/denominator)) or 0
end
function SD:PlanGatheringRoute(points,origin)
    local sx,sy,yards=scale(origin.map)
    local radius=yards and 125 or .75
    local sorted={}
    for _,p in ipairs(points) do sorted[#sorted+1]=p end
    table.sort(sorted,function(a,b) if a.x==b.x then return a.y<b.y end return a.x<b.x end)
    local clusters,buckets={},{}
    -- Fixed seed radius prevents a long chain of neighboring spawns merging
    -- into one zone-wide hotspot. The waypoint is their arithmetic center.
    for _,p in ipairs(sorted) do
        local best,nearest
        local cellX,cellY=math.floor(p.x*sx/radius),math.floor(p.y*sy/radius)
        for x=cellX-1,cellX+1 do for y=cellY-1,cellY+1 do
            for _,c in ipairs(buckets[x..":"..y] or {}) do
                local d=length(p,c.seed,sx,sy)
                if d<=radius and (not nearest or d<nearest) then best,nearest=c,d end
            end
        end end
        if best then
            best.count=best.count+1 best.x=best.x+(p.x-best.x)/best.count best.y=best.y+(p.y-best.y)/best.count
        else
            local c={map=p.map,x=p.x,y=p.y,count=1,seed=p}
            clusters[#clusters+1]=c
            local key=cellX..":"..cellY buckets[key]=buckets[key] or {} buckets[key][#buckets[key]+1]=c
        end
    end
    table.sort(clusters,function(a,b)
        local da,db=length(a,origin,sx,sy),length(b,origin,sx,sy)
        if da==db then return a.x==b.x and a.y<b.y or a.x<b.x end return da<db
    end)
    -- Bound planning work and keep the loop local to the player.
    local remaining={}
    for i=1,math.min(24,#clusters) do remaining[i]=clusters[i] end
    local route,here={},origin
    local dx,dy=0,0
    local facing=GetPlayerFacing and GetPlayerFacing()
    if publicNumber(facing) then dx,dy=-math.sin(facing),-math.cos(facing) end
    while #remaining>0 do
        local best,score=1,nil
        for i,p in ipairs(remaining) do
            local x,y=(p.x-here.x)*sx,(p.y-here.y)*sy
            local cost=(x*x+y*y)^.5*(1+1.25*turn(dx,dy,x,y))
            if not score or cost<score then best,score=i,cost end
        end
        local p=table.remove(remaining,best)
        dx,dy=(p.x-here.x)*sx,(p.y-here.y)*sy
        route[#route+1]=p here=p
    end
    local penalty=yards and 65 or .4
    local function cost()
        local total,previous=0,origin
        local vx,vy=0,0
        if publicNumber(facing) then vx,vy=-math.sin(facing),-math.cos(facing) end
        for _,p in ipairs(route) do
            local x,y=(p.x-previous.x)*sx,(p.y-previous.y)*sy
            total=total+(x*x+y*y)^.5+penalty*turn(vx,vy,x,y)
            vx,vy=x,y previous=p
        end
        if #route>1 then total=total+length(route[#route],route[1],sx,sy) end
        return total
    end
    -- Three bounded 2-opt passes remove crossing detours and needless turns;
    -- keep the first forward-selected hotspot fixed.
    local bestCost=cost()
    local function reverse(a,b) while a<b do route[a],route[b]=route[b],route[a] a=a+1 b=b-1 end end
    for _=1,3 do
        local improved=false
        for a=2,#route-1 do for b=a+1,#route do
            reverse(a,b) local candidate=cost()
            if candidate<bestCost-.001 then bestCost=candidate improved=true else reverse(a,b) end
        end end
        if not improved then break end
    end
    for _,p in ipairs(route) do p.seed=nil end
    return route,yards
end
