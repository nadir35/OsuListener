function fif(test, if_true, if_false)
  if test then return if_true else return if_false end
end


chestHeight = 1.3 -- 1.25
curveFactorX = 100
curveFactorY = 100 -- 170 -- 65 -- 55
curveY_Max = 75
curveY_Min = 17
curveY_tiltInfluence = .8 -- .75
minSpacingSeconds = 0.35 -- .35
maxNodeDistShown = 2000
impactX_Scaler = 1.7 -- this needs to adapt downwards for shorter people (less armspan)
meteorSpeed = .05 -- .05

blueMaxX = .1
blueSpanX = -.45
redMinX = -.1
redSpanX = .45
purpleMaxX = .4
purpleSpanX = -.8
yImpactSpan = .47
yImpactSpan_MaxRandomExtra = .05
zImpact = .7 -- .35 -- .7
maxNeighborXspan = .95
maxMirroredX = .4

convertPurplesToCrossUps = false

allowMusicCutOutOnFail=false



GameplaySettings{
    allowmusicdroponfail = allowMusicCutOutOnFail,
    --track generation settings
    jumpmode="none",
    gravity=-.45,
        playerminspeed = 0.1,--so the player is always moving somewhat
        playermaxspeed = 2.9,--2.5
        minimumbestjumptime = 2.5,--massage the track until a jump of at least this duration is possible
        uphilltiltscaler = 0.8,--set to 1 for normal track. higher for steeper
        downhilltiltscaler = 1.55,--set to 1 for normal track. higher for steeper
        uphilltiltsmoother = 0.03,
        downhilltiltsmoother = 0.06,
        useadvancedsteepalgorithm = true,--set false for a less extreme track
        alldownhill = false,
        usepuzzlegrid = false,
        usetraffic = false,
        towropes = false
    --end track generation settings
}

nodes = nodes or {} --create the array of node markers ("jump", "duck", "rave" or "dirty") only if it doesn't exist yet
nodechaincount = nodechaincount or {}

function FindTrackSpan(start, preseconds, postseconds)
    local bound = start
    local newstart = start

    local preTime = track[start].seconds + preseconds
    for i = start, 1,-1 do
        if track[i].seconds <= preTime then
            newstart = i
            break
        end
    end

    local postTime = track[start].seconds + postseconds;
    for i = start, #track do
        if track[i].seconds >= postTime then
            bound = i
            break
        end
    end

    return newstart, bound
end

function TryMarkSpan(start, bound, jumporduck)
  --local flag = false
  --if start > 5300 and bound < 5500 then
  --  flag = true
  --end

  --if flag then print("TryMarkSpan start:"..start.." bound:"..bound.." type:"..jumporduck) end
  --whenever a span is placed, it's responsible for blocking spacing time in front of itself
  local preStart, postBound = FindTrackSpan(start,-minSpacingSeconds,0)
  --Highway.TwoInts ti = Highway.Instance.FindStartEndSpanForDuration(start, -minSpacingSeconds, 0)
  --int preStart = ti.start;
  if (preStart == start) or (preStart==(start-1)) then
    preStart = math.max(1, start - 2)
  end

  if start==bound then--just wants to add a single block, special case to make sure only one block is added
    --if flag then print("solo path") end
    local allgood=true
    for i=preStart,start do
      if nodes[i] ~= nil then
        allgood=false
        break
      end
    end

    if allgood then
      for i=preStart,start do
        --if flag then print("add dirty at "..i) end
        nodes[i] = 'dirty'
        nodechaincount[i] = -1
      end
      --if flag then print("add "..jumporduck.." at "..start) end
      nodes[start] = jumporduck
      nodechaincount[start] = -1
    end
  else
    --if flag then print("multi path") end
    local startTime = -1;
    local started = false;
    for i = preStart, bound do
      if nodes[i] == nil then --this node is not claimed by a jump, duck, or buffer yet
        if not started then
          started = true
          startTime = track[i].seconds
          nodes[i] = 'dirty'--at least one empty node in front of the span
          --if flag then print("add dirty at "..i) end
          nodechaincount[i] = -1
        else
          if (track[i].seconds >= (startTime + minSpacingSeconds)) and (i>=start) then
            nodes[i] = jumporduck
            --if flag then print("add "..jumporduck.." at "..i) end
          else
            nodes[i] = 'dirty'
            --if flag then print("add dirty at "..i) end
          end
          if bound - preStart > 4 then
            nodechaincount[i] = bound - i
          else
            nodechaincount[i] = -1
          end
        end
      else
        if started then
          break--stop marking, ran into another (higher priority) span
        end
      end
    end
  end
end

function CompareJumpTimes(a,b) --used to sort the track nodes by jump duration
  return a.jumpairtime > b.jumpairtime
end

function CompareStrengths(a,b) --used to sort the track nodes by jump duration
  return a.strength > b.strength
end

powernodes = powernodes or {}
track = track or {}
traffic = traffic or {}
maxTilt = 0
minTilt = 0

function OnTrackCreated(theTrack)--track is created before the traffic
  print("LUA OnTrackCreated")
  track = theTrack --store globally

  local songMinutes = track[#track].seconds / 60

  for i=1,#track do
    track[i].jumpedOver = false -- if this node was jumped over by a higher proiority jump
    track[i].origIndex = i
  end

  --find the best jumps path in this song
  local strack = deepcopy(track)
  table.sort(strack, CompareJumpTimes)

  for i=1,#strack do
    maxTilt = math.max(maxTilt, strack[i].tilt)
    minTilt = math.min(minTilt, strack[i].tilt)
    if strack[i].jumpairtime >= 2.5 then --only consider jumps of at least this amount of air time
      if not track[strack[i].origIndex].jumpedOver then
        local flightPathClear = true
        local jumpEndSeconds = strack[i].seconds + strack[i].jumpairtime + 10
        for j=strack[i].origIndex, #track do --make sure a higher priority jump doesn't happen while this one would be airborne
          if track[j].seconds <= jumpEndSeconds then
            if track[j].jumpedOver then
              flightPathClear = false
            end
          else
            break
          end
        end
        if flightPathClear then
          -- if #powernodes < (songMinutes + 2) then -- allow about one power node per minute of music
          if #powernodes < (songMinutes+2) then -- allow about one power node per minute of music
            if strack[i].origIndex > 300 then
              --check if this is a real transition point in the song. The nodes before it should be uphill and the nodes after it should be downhill
              local avgSlopePrev = 0
              local avgSlopePost = 0
              local slopeTestCount = 100

              local strt = math.max(1, strack[i].origIndex-slopeTestCount)
              local bnd = strack[i].origIndex
              for ii=strt,bnd do
                avgSlopePrev = avgSlopePrev + track[ii].tilt
              end
              strt = strack[i].origIndex
              bnd = math.min(#track-1, strack[i].origIndex+slopeTestCount)
              for ii=strt,bnd do
                avgSlopePost = avgSlopePost + track[ii].tilt
              end

              avgSlopePrev = avgSlopePrev / slopeTestCount
              avgSlopePost = avgSlopePost / slopeTestCount
              --print("avgSlopePrev:"..avgSlopePrev)
              --print("avgSlopePost:"..avgSlopePost)

              if (avgSlopePrev < 5 and avgSlopePost >15) or (i==1) then -- only take slope qualifiers. Also, always take the biggest jump
                powernodes[#powernodes+1] = strack[i].origIndex
              end
            end
            local extraJumpOverBufferSec = 10
            jumpEndSeconds = strack[i].seconds + strack[i].jumpairtime + extraJumpOverBufferSec
            for j=strack[i].origIndex, #track do
              if track[j].seconds <= jumpEndSeconds then
                track[j].jumpedOver = true --mark this node as jumped over (a better jump took priority) so it is not marked as a powernode
              else
                break
              end
            end
          end
        end
      end
    end
  end
end

meteorNodes = meteorNodes or {} -- declare tables this way to support (possible) future live code reloading
meteorImpacts = meteorImpacts or {}
meteorSpeeds = meteorSpeeds or {}
meteorDirections = meteorDirections or {}
meteorCurveMaximums = meteorCurveMaximums or {}
meteorScales = meteorScales or {}
meteorColors = meteorColors or {}
meteorAlbedoColors = {}
meteorTypes = {}
--nodeAttackAngles = nodeAttackAngles or {} -- for each track node, a list of what angles meteors attack from
--nodeAttackSizes = nodeAttackSizes or {} -- for each track node, what size the metoers impacting at that time are

meteorNodes_tails = meteorNodes_tails or {} -- declare tables this way to support (possible) future live code reloading
meteorImpacts_tails = meteorImpacts_tails or {}
meteorSpeeds_tails = meteorSpeeds_tails or {}
meteorDirections_tails = meteorDirections_tails or {}
meteorCurveMaximums_tails = meteorCurveMaximums_tails or {}
meteorScales_tails = meteorScales_tails or {}
meteorColors_tails = meteorColors_tails or {}
meteorAlbedoColors_tails = {}
meteorTypes_tails = {}

function OnTrafficCreated(theTraffic)
  traffic = theTraffic --store globally
  
  math.randomseed(GetMillisecondsSinceStartup())
  --math.randomseed(11)

  local minimapMarkers = {}
  for j=1,#powernodes do --insert powernode spans. They're top priority, so do them first
    local prev = 2
    for i=prev, #traffic do
      if traffic[i].chainend >= powernodes[j] then
        local spanDist = traffic[i].chainend - traffic[i].chainstart
        if spanDist > 5 then -- never make a tiny chain into a rave
          --if traffic[i].chainstart <= powernodes[j] then
          TryMarkSpan(traffic[i].chainstart, traffic[i].chainend, 'rave')
          --else
          --  local strt = math.max(1,powernodes[j]-3)
          --  local bnd = math.min(#track-1, powernodes[j]+3)
          --  TryMarkSpan(strt, bnd, 'rave')
          --end
          prev = i
          table.insert(minimapMarkers, {tracknode=powernodes[j], startheight=0, endheight=fif(j==1, 15, 11), color={233,233,233}})
        end

        break
      end
    end
  end

  --figure out where to put jumps and ducks
  local longestSpan = 0
  local longestSpanStart = 0
  local longestSpanEnd = 0
    for i = 1, #traffic do
        local spanDist = traffic[i].chainend - traffic[i].chainstart
        if spanDist > longestSpan then
          longestSpan = spanDist
          longestSpanStart = traffic[i].chainstart
          longestSpanEnd = traffic[i].chainend
        end
        if spanDist > 2 then
            if spanDist > 10 then --long ones are more likely ducks
              local spanType = (math.random() > 0.5) and 'jump' or 'duck'
              --if (traffic[i].strength > .95) and (math.random()>.9) then -- high speed areas may get additional rave sections
              --  spanType = 'rave'
              --  table.insert(minimapMarkers, {tracknode=traffic[i].chainstart, startheight=0, endheight=11, color={233,233,233}})
              --end
                TryMarkSpan(traffic[i].chainstart, traffic[i].chainend, spanType)
            else --shorter ones are more likely jumps
                TryMarkSpan(traffic[i].chainstart, traffic[i].chainend, (math.random() > 0.5) and 'jump' or 'duck')
            end
        end
    end

    --if longestSpan > 0 then
  --    for i=longestSpanStart, longestSpanEnd do -- turn the longest span into a rave (if it isn't already)
  --      if nodes[i]=='jump' or nodes[i]=='duck' then
  --        nodes[i] = 'rave'
  --      end
  --    end
  --
  --    table.insert(minimapMarkers, {tracknode=longestSpanStart, startheight=0, endheight=11, color={233,233,233}})
  --end

  local straffic = deepcopy(traffic)
  table.sort(straffic, CompareStrengths)

    for i = 1,#straffic do --mark these in their own loop. they're lower priority. place them in strength order to make sure the most important ones aren't overlapped and removed
        if (straffic[i].chainend - straffic[i].chainstart) < 3 then
            TryMarkSpan(straffic[i].impactnode, straffic[i].impactnode, (math.random() > 0.5) and 'jump' or 'duck')
        end
    end

    for i=1,#traffic do
      --if nodes[i]==nil or nodes[i]=='dirty'
      if (nodes[i] ~= 'jump') and (nodes[i]~='duck') and (nodes[i]~='rave') then
        nodes[i] = 'run' -- all non-action nodes get marked as 'run' in order to track the player's efficiency bonus
      end
    end

    --print("initialized player nodestates")
    --for jj=1, #players do
    --  local player = players[jj]
    --  for ii=1,#track do
    --    player.nodestates[ii] = 'run'
    --  end
    --end

    AddMinimapMarkers(minimapMarkers)

--[[

    local playerHeadHeight = GetMaxHMDHeightSinceSceneChange()
    local baseHeight = 1.8 -- game dev height
    local playerHeight_impactYCompensator = .5*(playerHeadHeight - baseHeight)
    --print("playerHeadHeight:"..playerHeadHeight)


  local sqrt = math.sqrt --making a local copy of global functions improves performance a bit
  local rand = math.random
  local min = math.min
  local max = math.max
  local sin = math.sin
  local cos = math.cos
  local degreesToRadians = .0174532925


    local chainstarter = true
  local angleD
  local angle
  local heading
  local mag
  local headingNormalized
  local impactRadius
  local impactPosition  
  local lastSentNode
  local color = {255,255,255}
  local scale = {.04,.04,.04}
  local prevBlockType = "jump"
  local prevBlockSongTime = 0
  local prevBlockImpactX = 0
  local renderThisChain = true
  local mirrorThisChain = false
  local mirrorColor
  local mirrorScale
  local jumpColor = {53,141,173}
  local jumpScale = {.035,.035,.035}
  local duckColor = {176,53,53}
  local duckScale = {.035,.035,.035}
  local raveColor = {103,53,176}
  local raveScale = {.06,.06,.06}
  local impactX, impactY, impactZ
  local isGroundTroop = false
  --local curveFactorX = 100
  --local curveFactorY = 35
  local impactY_BeyondChestHeight = 0
  local tiltFactor = 0
  local intensityFactor = 0
  local intensityFactorExp = 0
    for i=1,#track do
      if nodes[i]~=nil and nodes[i]~='run' and nodes[i]~='dirty' then
        if chainstarter then -- bring all meteors in this chain from the same direction
          tiltFactor = 0
          intensityFactor = 0
          intensityFactorExp = 0

          local k=i
          while k<=#track and nodes[k]~=nil and nodes[k]~='run' and nodes[k]~='dirty' do --use the biggest intensity found in the span
            local maxTiltSpan = maxTilt - minTilt
            local myTiltSpan = track[k].tilt - minTilt
            tiltFactor = math.max(tiltFactor, myTiltSpan/maxTiltSpan)
            intensityFactor = math.max(intensityFactor, track[k].intensity)
            k = k + 1
          end

          intensityFactorExp = intensityFactor*intensityFactor*intensityFactor

        --heading = {-.5*rand() + .5, -.5*rand(), -2*rand()}
        heading = {0, 0, -1}
        headingNormalized = heading

        if nodes[i] == 'duck' then
          --impactX = -.5*rand() + .75
          impactX = redMinX + rand() * redSpanX
        elseif nodes[i] == 'jump' then
          --impactX = .5 - rand() * .75
          impactX = blueMaxX + rand() * blueSpanX
        else
          impactX = purpleSpanX*rand() + purpleMaxX
        end

        impactX = impactX * impactX_Scaler -- 1.7
        
        --impactY_BeyondChestHeight = rand()*yImpactSpan
        impactY_BeyondChestHeight = tiltFactor*tiltFactor*yImpactSpan + rand()*yImpactSpan_MaxRandomExtra
        impactY = chestHeight + impactY_BeyondChestHeight

        local impactDir = {impactX, impactY_BeyondChestHeight, 0}

        local targetMagSq = zImpact * zImpact
        impactZ = zImpact
        local impactXSq=impactX*impactX;
        local impactYSq = impactY_BeyondChestHeight*impactY_BeyondChestHeight
        for k=1, 9 do
          local mag = impactXSq + impactYSq + impactZ*impactZ
          if mag <= targetMagSq then
            break
          else
            impactZ = impactZ - .05
          end
        end
        --impactZ = zImpact -- .5 -- the player's arm reach ideally

        --impactMag = sqrt(impactX*impactX + impactY*impactY + impactY*impactY)
        --impactNormalized = {impactX / impactMag, impactY / impactMag, impactZ / impactMag}
        --headingNormalized = {heading[1] / mag, heading[2] / mag, heading[3] / mag}
        --impactRadius = -1 -- this should be the player's arm reach
        --impactPosition = {headingNormalized[1]*impactRadius, headingNormalized[2]*impactRadius, headingNormalized[3]*impactRadius} 

        --local armsReach = .5
        --local impactAbsolute = deepcopy(impactNormalized)
        --impactAbsolute[1] = impactAbsolute[1] * armsReach;
        --impactAbsolute[2] = impactAbsolute[2] * armsReach;
        --impactAbsolute[3] = impactAbsolute[3] * armsReach;
        --impactAbsolute[2] = impactAbsolute[2]+chestHeight
        --impactPosition = impactAbsolute

        --impactPosition = {impactX, impactY, impactZ}

        local minSameBlockTypeSpacing = 0.3

        local chainType = nodes[i]

        renderThisChain = true
        mirrorThisChain = false
        isGroundTroop = false

        --if track[i].intensity < .5 and rand()>.4 then
        --if chainType == 'rave' then
        --  --this one is a ground troop
        --  isGroundTroop = true
        --  impactY = chestHeight - .1
        --  if chainType == 'jump' then
        --    impactX = -1*math.abs(impactX)
        --  elseif chainType == 'duck' then
        --    impactX = math.abs(impactX)
        --  end
        --end

        local minSpacingAfterRaveBlock = 0.3

        --if i<1000 then
        --  print(chainType.."."..track[i].seconds.." prevTime:"..prevBlockSongTime)
        --end

        if prevBlockType == 'rave' then
          if  not ((track[i].seconds - prevBlockSongTime) >= minSpacingAfterRaveBlock) then
            renderThisChain = false -- don't render anything too close right after a rave
          elseif not ((track[i].seconds - prevBlockSongTime) >= 1.5) then
            --if we follow a rave, make sure we're not hidden behind it
            if chainType == 'rave' then
              impactX = prevBlockImpactX
            elseif chainType == 'jump' then
              if prevBlockImpactX < .2 then
                impactX = .35
              else
                impactX = 0
              end
            elseif chainType == 'duck' then
              if prevBlockImpactX > -.2 then
                impactX = -.35
              else
                impactX = 0
              end
            end
          end
        end

        if  not ((track[i].seconds - prevBlockSongTime) >= minSameBlockTypeSpacing) then
          --needs to change to the other type, these two are too close together
          if prevBlockType == 'rave' then
            --renderThisChain = false -- don't render anything too close right after a rave
          elseif prevBlockType == 'jump' then
            chainType = 'jump'
            impactX = prevBlockImpactX
          elseif prevBlockType == 'duck' then
            chainType = 'duck'
            impactX = prevBlockImpactX
          end
        else
          if chainType ~= 'rave' then
            if intensityFactor > .75 then
              if math.abs(impactX) > .25 then
                if rand() > .8 then
                  mirrorThisChain = true
                  if chainType=='jump' then
                    impactX = -1 * math.abs(impactX) -- make sure the blue is on the left
                    mirrorScale = duckScale
                    mirrorColor = duckColor
                  else
                    impactX = math.abs(impactX) -- make sure the red is on the right
                    mirrorScale = jumpScale
                    mirrorColor = jumpColor
                  end
                end
              end
            end
          end
        end

        if chainType=='jump' then
          color = jumpColor
          scale = jumpScale
        elseif chainType=='duck' then
          color = duckColor
          scale = duckScale
        elseif chainType=='rave' then
          color = raveColor
          scale = raveScale
        end

        chainstarter = false
        end

        local yCurve = impactY_BeyondChestHeight*curveFactorY
        yCurve = math.min(yCurve, curveY_Max)
        yCurve = math.max(yCurve, curveY_Min)
        --yCurve = curveY_Max
        --local yCurve = impactY*curveFactorY
        --local yCurve = impactY*curveFactorY*((1.0-curveY_tiltInfluence)+curveY_tiltInfluence*tiltFactor)
        --local yCurve = impactY*curveFactorY*((1.0-curveY_tiltInfluence)+curveY_tiltInfluence*intensityFactorExp)

        if renderThisChain then
          prevBlockSongTime = track[i].seconds
          prevBlockType = chainType -- nodes[i]
          prevBlockImpactX = impactX

          local adjustedImpactY = impactY + playerHeight_impactYCompensator

            meteorNodes[#meteorNodes+1] = i
            lastSentNode = i
          meteorDirections[#meteorDirections+1] = headingNormalized -- {math.random() - .5, 0, math.random() - .5} -- the game normalizes these for us
          meteorImpacts[#meteorImpacts+1] = {impactX, adjustedImpactY, impactZ}
          meteorScales[#meteorScales+1] = scale
          --meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{impactX*curveFactorX, impactY*curveFactorY, 0})--impactY*60
          meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{impactX*curveFactorX, yCurve, 0})--impactY*60
          meteorColors[#meteorColors+1] = color
          meteorSpeeds[#meteorSpeeds+1] = .05 -- fif(isGroundTroop, .025,.05)

          if mirrorThisChain then
              meteorNodes[#meteorNodes+1] = i
            meteorDirections[#meteorDirections+1] = headingNormalized -- {math.random() - .5, 0, math.random() - .5} -- the game normalizes these for us
            meteorImpacts[#meteorImpacts+1] = {-1*impactX, adjustedImpactY, impactZ}
            meteorScales[#meteorScales+1] = mirrorScale
            --meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{-1*impactX*curveFactorX, impactY*curveFactorY, 0})
            meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{-1*impactX*curveFactorX, yCurve, 0})
            meteorColors[#meteorColors+1] = mirrorColor
            meteorSpeeds[#meteorSpeeds+1] = .05 -- fif(isGroundTroop, .025,.05)
          end
        end
      else
        chainstarter = true
      end
    end

    print("...............................")
    print("track length:"..#track)
    print("last meteor node"..lastSentNode)

    --]]
end

function InitMeteorsOld()
    --local playerHeadHeight = GetMaxHMDHeightSinceSceneChange()
    --local baseHeight = 1.71 -- 1.8 -- dev
    --local normalImpactPointAsPercentOfBodyHeight = .8
    --local baseExpectedImpactHeight = baseHeight * normalImpactPointAsPercentOfBodyHeight
    --local playerHeightRatio = playerHeadHeight/baseHeight
    --local thisPlayer_DesiredImpactHeight = baseExpectedImpactHeight * playerHeightRatio
    --local playerHeight_impactYCompensator = thisPlayer_DesiredImpactHeight - baseExpectedImpactHeight
    local playerHeight_impactYCompensator = 0 -- this is now handled in c#

    --local playerHeight_impactYCompensator = .5*(playerHeadHeight - baseHeight)
    --print("playerHeadHeight:"..playerHeadHeight)
    --print("playerHeight_CompensationDist:"..playerHeight_impactYCompensator)


  local sqrt = math.sqrt --making a local copy of global functions improves performance a bit
  local rand = math.random
  local min = math.min
  local max = math.max
  local sin = math.sin
  local cos = math.cos
  local degreesToRadians = .0174532925

    local chainstarter = true
  local angleD
  local angle
  local heading
  local mag
  local headingNormalized
  local impactRadius
  local impactPosition  
  local lastSentNode
  local color = {255,255,255}
  local typeID
  local mirrorTypeID
  local scale = {.04,.04,.04}
  local prevBlockType = "jump"
  local prevBlockSongTime = 0
  local prevBlockImpactX = 0
  local renderThisChain = true
  local mirrorThisChain = false
  local yDuplicateThisChain = false;
  local yDupOffset = 0;
  local xMirrorOffset = 0;
  local mirrorColor
  local mirrorScale
  local jumpColor = {53,141,255} -- {53,141,173}
  local jumpScale = {.035,.035,.035}
  --local duckColor = {255,53,53} -- {176,53,53}
  local duckColor = {255,52,0} 
  local duckScale = {.035,.035,.035}
  local raveColor = {103,53,176}
  local raveScale = {.06,.06,.06}
  local impactX, impactY, impactZ
  local isGroundTroop = false
  --local curveFactorX = 100
  --local curveFactorY = 35
  local impactY_BeyondChestHeight = 0
  local tiltFactor = 0
  local intensityFactor = 0
  local intensityFactorExp = 0

  local impactProxyScales = {}
  local impactProxyVelocities = {}
  local impactProxyScale = {.005,.005,.005}
  local idInThisChain = 1

  local myChainStarTime = 0
  local myChainEndTime = 0
  local nextChainStartTime = 0

  local isBallChain = false
  local isExtraLongBallChain = false
  local sweepDir = 1
  local sweepPosX = 0
  local prevBlockIsBallChain = false
  local prevBallChainDirection = 0
    for i=1,#track do
      if nodes[i]~=nil and nodes[i]~='run' and nodes[i]~='dirty' then
        if chainstarter then -- bring all meteors in this chain from the same direction
          tiltFactor = 0
          intensityFactor = 0
          intensityFactorExp = 0
          idInThisChain = 1
          isBallChain = false -- most of them are squids, not ball chains
          isExtraLongBallChain = false
          local chainLength = 0

          myChainStarTime = track[i].seconds

          local k=i
          while k<=#track and nodes[k]~=nil and nodes[k]~='run' and nodes[k]~='dirty' do --use the biggest intensity found in the span
            local maxTiltSpan = maxTilt - minTilt
            local myTiltSpan = track[k].tilt - minTilt
            tiltFactor = math.max(tiltFactor, myTiltSpan/maxTiltSpan)
            intensityFactor = math.max(intensityFactor, track[k].intensity)
            myChainEndTime = track[k].seconds
            chainLength = chainLength + 1
            k = k + 1
          end

          nextChainStartTime = -1
          local kk = k
          for kk=k,#track do
            if nodes[kk]~=nil and nodes[kk]~='run' and nodes[kk]~='dirty' then
              nextChainStartTime = track[kk].seconds
              break
            end
          end

          --if i<500 then
          --  print("myChainStart:"..myChainStarTime.." myChainEnd:"..myChainEndTime.." nextChainStart:"..nextChainStartTime)
          --end

          intensityFactorExp = intensityFactor*intensityFactor*intensityFactor

        --heading = {-.5*rand() + .5, -.5*rand(), -2*rand()}
        heading = {0, 0, -1}
        headingNormalized = heading

        if nodes[i] == 'duck' then
          --impactX = -.5*rand() + .75
          impactX = redMinX + rand() * redSpanX
        elseif nodes[i] == 'jump' then
          --impactX = .5 - rand() * .75
          impactX = blueMaxX + rand() * blueSpanX
        else
          impactX = purpleSpanX*rand() + purpleMaxX
        end

        impactX = impactX * impactX_Scaler -- 1.7

        local maxAllowedX = prevBlockImpactX + maxNeighborXspan
        local minAllowedX = prevBlockImpactX - maxNeighborXspan
        impactX = math.max(impactX, minAllowedX)
        impactX = math.min(impactX, maxAllowedX)
        
        --impactY_BeyondChestHeight = rand()*yImpactSpan
        impactY_BeyondChestHeight = tiltFactor*tiltFactor*yImpactSpan + rand()*yImpactSpan_MaxRandomExtra
        impactY = chestHeight + impactY_BeyondChestHeight

        local impactDir = {impactX, impactY_BeyondChestHeight, 0}

        local targetMagSq = zImpact * zImpact
        impactZ = zImpact
        local impactXSq=impactX*impactX;
        local impactYSq = impactY_BeyondChestHeight*impactY_BeyondChestHeight
        for k=1, 9 do
          local mag = impactXSq + impactYSq + impactZ*impactZ
          if mag <= targetMagSq then
            break
          else
            impactZ = impactZ - .05
          end
        end
        --impactZ = zImpact -- .5 -- the player's arm reach ideally

        --impactMag = sqrt(impactX*impactX + impactY*impactY + impactY*impactY)
        --impactNormalized = {impactX / impactMag, impactY / impactMag, impactZ / impactMag}
        --headingNormalized = {heading[1] / mag, heading[2] / mag, heading[3] / mag}
        --impactRadius = -1 -- this should be the player's arm reach
        --impactPosition = {headingNormalized[1]*impactRadius, headingNormalized[2]*impactRadius, headingNormalized[3]*impactRadius} 

        --local armsReach = .5
        --local impactAbsolute = deepcopy(impactNormalized)
        --impactAbsolute[1] = impactAbsolute[1] * armsReach;
        --impactAbsolute[2] = impactAbsolute[2] * armsReach;
        --impactAbsolute[3] = impactAbsolute[3] * armsReach;
        --impactAbsolute[2] = impactAbsolute[2]+chestHeight
        --impactPosition = impactAbsolute

        --impactPosition = {impactX, impactY, impactZ}

        local minSameBlockTypeSpacing = 0.3

        local chainType = nodes[i]

        renderThisChain = true
        mirrorThisChain = false
        isGroundTroop = false
        yDuplicateThisChain = false
        yDupOffset = 0
        xMirrorOffset = 0

        --if track[i].intensity < .5 and rand()>.4 then
        --if chainType == 'rave' then
        --  --this one is a ground troop
        --  isGroundTroop = true
        --  impactY = chestHeight - .1
        --  if chainType == 'jump' then
        --    impactX = -1*math.abs(impactX)
        --  elseif chainType == 'duck' then
        --    impactX = math.abs(impactX)
        --  end
        --end

        local minSpacingAfterRaveBlock = 0.3

        --if i<1000 then
        --  print(chainType.."."..track[i].seconds.." prevTime:"..prevBlockSongTime)
        --end

        if prevBlockType == 'rave' then
          if  not ((track[i].seconds - prevBlockSongTime) >= minSpacingAfterRaveBlock) then
            renderThisChain = false -- don't render anything too close right after a rave
          elseif not ((track[i].seconds - prevBlockSongTime) >= 1.5) then
            --if we follow a rave, make sure we're not hidden behind it
            if chainType == 'rave' then
              impactX = prevBlockImpactX
            elseif chainType == 'jump' then
              if prevBlockImpactX < .2 then
                impactX = .35
              else
                impactX = 0
              end
            elseif chainType == 'duck' then
              if prevBlockImpactX > -.2 then
                impactX = -.35
              else
                impactX = 0
              end
            end
          end
        end

        local timeGapUntilNextChain = nextChainStartTime - myChainEndTime
        local minRequiredStrafeForMirroring = .25
        local forceMirrorOn = (nextChainStartTime<0) or ((intensityFactor > .5) and (timeGapUntilNextChain>2.0)) or (timeGapUntilNextChain>4.0)
        local tooClose = false

        if  not ((track[i].seconds - prevBlockSongTime) >= minSameBlockTypeSpacing) then
          tooClose = true;
          --needs to change to the other type, these two are too close together
          if prevBlockType == 'rave' then
            --renderThisChain = false -- don't render anything too close right after a rave
          elseif prevBlockType == 'jump' then
            chainType = 'jump'
            impactX = prevBlockImpactX
          elseif prevBlockType == 'duck' then
            chainType = 'duck'
            impactX = prevBlockImpactX
          end
        end

        if (not tooClose) or forceMirrorOn then
          if chainType ~= 'rave' then
            if (intensityFactor > .75) or forceMirrorOn then -- big hit, end of song, or before a gap
              if forceMirrorOn then
                if math.abs(impactX)< minRequiredStrafeForMirroring then
                  impactX = minRequiredStrafeForMirroring + .01
                end
              end
              if math.abs(impactX) >= minRequiredStrafeForMirroring then
                if (rand() > .8) or forceMirrorOn then
                  mirrorThisChain = true
                  impactX = math.max(-1*maxMirroredX, math.min(maxMirroredX, impactX))
                  if chainType=='jump' then
                    impactX = -1 * math.abs(impactX) -- make sure the blue is on the left
                    mirrorScale = duckScale
                    mirrorColor = duckColor
                  else
                    impactX = math.abs(impactX) -- make sure the red is on the right
                    mirrorScale = jumpScale
                    mirrorColor = jumpColor
                  end
                end
              end
            end
          end
        end

        if chainType=='jump' then
          color = jumpColor
          scale = jumpScale
          typeID = 0
          mirrorTypeID = 1
        elseif chainType=='duck' then
          color = duckColor
          scale = duckScale
          typeID = 1
          mirrorTypeID = 0
        elseif chainType=='rave' then
          color = raveColor
          scale = raveScale
          typeID = 2
          mirrorTypeID = 2
        end


        --if i <1000 then
        --  print("intensity:"..intensityFactor)
        --end

        if (not mirrorThisChain) and (chainType~='rave') then
          --if (rand()>.9) and (chainLength>7) then
          --  isBallChain = true
          --end
          if (chainLength>11) and (intensityFactor<.6) then
            isBallChain = true
          end
          if (chainLength>22) and (intensityFactor<.9) then
            isBallChain = true
          end
          --if chainLength>22 then
          --  isBallChain = true
          --end
        end

        sweepDir = 1
        if impactX > 0 then sweepDir = -1 end
        sweepPosX = impactX

        if isBallChain and chainLength>66 then
          isExtraLongBallChain = true
        end

        if convertPurplesToCrossUps then
          if chainType=='rave' then -- try turning purples into double vertical hits
            impactX = math.abs(impactX)
            chainType = 'duck'
            color = duckColor
            typeID = 1
            mirrorTypeID = 0
            scale = duckScale
            mirrorThisChain = true
            mirrorScale = jumpScale
            mirrorColor = jumpColor
            --yDuplicateThisChain = true
            --yDupOffset = .2
            xMirrorOffset = .5 --put the blues on the wrong side
          end
        end

        chainstarter = false
        else
          idInThisChain = idInThisChain + 1
        end

        local yCurve = impactY_BeyondChestHeight*curveFactorY
        yCurve = math.min(yCurve, curveY_Max)
        yCurve = math.max(yCurve, curveY_Min)
        --yCurve = curveY_Max
        --local yCurve = impactY*curveFactorY
        --local yCurve = impactY*curveFactorY*((1.0-curveY_tiltInfluence)+curveY_tiltInfluence*tiltFactor)
        --local yCurve = impactY*curveFactorY*((1.0-curveY_tiltInfluence)+curveY_tiltInfluence*intensityFactorExp)

        --if renderThisChain and ((idInThisChain%2)==1) then -- only render every other ball in the chain
        if renderThisChain then
          prevBlockSongTime = track[i].seconds
          prevBlockType = chainType -- nodes[i]
          prevBlockImpactX = impactX
          prevBlockIsBallChain = isBallChain
          prevBallChainDirection = 1

          local adjustedImpactY = impactY + playerHeight_impactYCompensator

            lastSentNode = i

            if idInThisChain==1 or isBallChain or yDuplicateThisChain then --this is the head of a chain or a strafe chain (ballChain)
              local allowRender =  true
              if isExtraLongBallChain and (idInThisChain>1) and (idInThisChain%2==0) then
                allowRender = false -- for extra long chains, render only every other orb
              end
              
              if allowRender then
                local additionalX_SweepAcross = 0 -- -.005 + idInThisChain * .0015
                local sweptImpactX = impactX
                if isBallChain then
                  --additionalX_SweepAcross = -.025 + idInThisChain * .025
                  --if impactX > 0 then -- always move the trail towards center
                  --  additionalX_SweepAcross = additionalX_SweepAcross * -1
                  --  prevBallChainDirection = -1
                  --end
                  --sweptImpactX = sweptImpactX + additionalX_SweepAcross
                  --sweptImpactX = math.max(-1, math.min(sweptImpactX, 1)) -- contain them to a reseonable field size

                  sweepPosX = sweepPosX + .025 * sweepDir
                  if sweepPosX > 1 then
                    sweepPosX = 1
                    sweepDir = -1
                  elseif sweepPosX < -1 then
                    sweepPosX = -1
                    sweepDir = 1
                  end
                  sweptImpactX = sweepPosX

                  prevBlockImpactX = sweptImpactX
                end

                meteorNodes[#meteorNodes+1] = i
              meteorDirections[#meteorDirections+1] = headingNormalized -- {math.random() - .5, 0, math.random() - .5} -- the game normalizes these for us
              meteorImpacts[#meteorImpacts+1] = {sweptImpactX, adjustedImpactY, impactZ}
              meteorScales[#meteorScales+1] = scale
              --meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{impactX*curveFactorX, impactY*curveFactorY, 0})--impactY*60
              meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{sweptImpactX*curveFactorX, yCurve, 0})--impactY*60
              meteorColors[#meteorColors+1] = color
              meteorAlbedoColors[#meteorAlbedoColors+1] = {255,255,255}
              meteorSpeeds[#meteorSpeeds+1] = meteorSpeed -- fif(isGroundTroop, .025,.05)
              meteorTypes[#meteorTypes+1] = typeID

              impactProxyScales[#impactProxyScales+1] = impactProxyScale
              impactProxyVelocities[#impactProxyVelocities+1] = {0,0,0}

              if yDuplicateThisChain then
                  meteorNodes[#meteorNodes+1] = i
                meteorDirections[#meteorDirections+1] = headingNormalized -- {math.random() - .5, 0, math.random() - .5} -- the game normalizes these for us
                meteorImpacts[#meteorImpacts+1] = {sweptImpactX, adjustedImpactY+yDupOffset, impactZ}
                meteorScales[#meteorScales+1] = scale
                --meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{impactX*curveFactorX, impactY*curveFactorY, 0})--impactY*60
                meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{sweptImpactX*curveFactorX, yCurve, 0})--impactY*60
                meteorColors[#meteorColors+1] = color
                meteorAlbedoColors[#meteorAlbedoColors+1] = {255,255,255}
                meteorSpeeds[#meteorSpeeds+1] = meteorSpeed -- fif(isGroundTroop, .025,.05)
                meteorTypes[#meteorTypes+1] = typeID

                impactProxyScales[#impactProxyScales+1] = impactProxyScale
                impactProxyVelocities[#impactProxyVelocities+1] = {0,0,0}
              end

              if mirrorThisChain then
                local mirrorImpactX = -1*impactX
                if xMirrorOffset ~= 0 then
                  mirrorImpactX = impactX + xMirrorOffset
                end
                  meteorNodes[#meteorNodes+1] = i
                meteorDirections[#meteorDirections+1] = headingNormalized -- {math.random() - .5, 0, math.random() - .5} -- the game normalizes these for us
                meteorImpacts[#meteorImpacts+1] = {mirrorImpactX, adjustedImpactY, impactZ}
                meteorScales[#meteorScales+1] = mirrorScale
                --meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{-1*impactX*curveFactorX, impactY*curveFactorY, 0})
                meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{mirrorImpactX*curveFactorX, yCurve, 0})
                meteorColors[#meteorColors+1] = mirrorColor
                meteorAlbedoColors[#meteorAlbedoColors+1] = {255,255,255}
                meteorSpeeds[#meteorSpeeds+1] = meteorSpeed -- fif(isGroundTroop, .025,.05)
                meteorTypes[#meteorTypes+1] = mirrorTypeID

                impactProxyScales[#impactProxyScales+1] = impactProxyScale
                impactProxyVelocities[#impactProxyVelocities+1] = {0,0,0}

                if yDuplicateThisChain then
                  meteorNodes[#meteorNodes+1] = i
                  meteorDirections[#meteorDirections+1] = headingNormalized -- {math.random() - .5, 0, math.random() - .5} -- the game normalizes these for us
                  meteorImpacts[#meteorImpacts+1] = {mirrorImpactX, adjustedImpactY+yDupOffset, impactZ}
                  meteorScales[#meteorScales+1] = mirrorScale
                  --meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{-1*impactX*curveFactorX, impactY*curveFactorY, 0})
                  meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{mirrorImpactX*curveFactorX, yCurve, 0})
                  meteorColors[#meteorColors+1] = mirrorColor
                  meteorAlbedoColors[#meteorAlbedoColors+1] = {255,255,255}
                  meteorSpeeds[#meteorSpeeds+1] = meteorSpeed -- fif(isGroundTroop, .025,.05)
                  meteorTypes[#meteorTypes+1] = mirrorTypeID

                  impactProxyScales[#impactProxyScales+1] = impactProxyScale
                  impactProxyVelocities[#impactProxyVelocities+1] = {0,0,0}
                end
              end
            end
          else -- this is part of a chain tail
            --.035 -> .06
            local additionalScale = -.005 + idInThisChain * .0015
            additionalScale = math.min(additionalScale, .09)
            local tailScale = {1,1,1}
            tailScale[1] = scale[1] + additionalScale
            tailScale[2] = scale[2] + additionalScale
            tailScale[3] = scale[3] + additionalScale

            --if i<1000 then
            --  print("idInThisChain "..idInThisChain)
            --  print("additionalScale "..additionalScale)
            --  print("scaleX "..tailScale[1])
            --end

              meteorNodes_tails[#meteorNodes_tails+1] = i
            meteorDirections_tails[#meteorDirections_tails+1] = headingNormalized -- {math.random() - .5, 0, math.random() - .5} -- the game normalizes these for us
            meteorImpacts_tails[#meteorImpacts_tails+1] = {impactX, adjustedImpactY, impactZ}
            meteorScales_tails[#meteorScales_tails+1] = tailScale
            --meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{impactX*curveFactorX, impactY*curveFactorY, 0})--impactY*60
            meteorCurveMaximums_tails[#meteorCurveMaximums_tails+1] = fif(isGroundTroop,{0,0,0},{impactX*curveFactorX, yCurve, 0})--impactY*60
            meteorColors_tails[#meteorColors_tails+1] = color
            meteorAlbedoColors_tails[#meteorAlbedoColors_tails+1] = {255,255,255}
            meteorSpeeds_tails[#meteorSpeeds_tails+1] = meteorSpeed -- fif(isGroundTroop, .025,.05)
            meteorTypes_tails[#meteorTypes_tails+1] = typeID

            impactProxyScales[#impactProxyScales+1] = impactProxyScale
            impactProxyVelocities[#impactProxyVelocities+1] = {0,0,0}

            if mirrorThisChain then
              local mirrorImpactX = -1*impactX
              if xMirrorOffset ~= 0 then
                mirrorImpactX = impactX + xMirrorOffset
              end
                meteorNodes_tails[#meteorNodes_tails+1] = i
              meteorDirections_tails[#meteorDirections_tails+1] = headingNormalized -- {math.random() - .5, 0, math.random() - .5} -- the game normalizes these for us
              meteorImpacts_tails[#meteorImpacts_tails+1] = {mirrorImpactX, adjustedImpactY, impactZ}
              meteorScales_tails[#meteorScales_tails+1] = tailScale -- mirrorScale
              --meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{-1*impactX*curveFactorX, impactY*curveFactorY, 0})
              meteorCurveMaximums_tails[#meteorCurveMaximums_tails+1] = fif(isGroundTroop,{0,0,0},{mirrorImpactX*curveFactorX, yCurve, 0})
              meteorColors_tails[#meteorColors_tails+1] = mirrorColor
              meteorAlbedoColors_tails[#meteorAlbedoColors_tails+1] = {255,255,255}
              meteorSpeeds_tails[#meteorSpeeds_tails+1] = meteorSpeed -- fif(isGroundTroop, .025,.05)
              meteorTypes_tails[#meteorTypes_tails+1] = mirrorTypeID

              impactProxyScales[#impactProxyScales+1] = impactProxyScale
              impactProxyVelocities[#impactProxyVelocities+1] = {0,0,0}
            end
          end
        end
      else
        chainstarter = true
      end
    end

    print("...............................")
    print("track length:"..#track)
    print("last meteor node"..lastSentNode)

    BatchRenderEveryFrame{prefabName="Meteor",
                locations = meteorNodes,
                maxShown = 100, --500, -- 1000,
                emissivecolors = deepcopy(meteorColors), -- "nodecolor", -- "highway" for them to all be the same shifting color
                colors = deepcopy(meteorColors),
                --colors = meteorAlbedoColors, -- meteorColors, -- "nodecolor", -- "highway" for them to all be the same shifting color
                scales = meteorScales,
                maxDistanceShown = maxNodeDistShown,
                broadcastimpactvelocities = true,
                --songspeedratio = .05, -- amount of speed compression
                songspeedratios = meteorSpeeds,
                typeids = meteorTypes,
                afternodereached_numbernodesrendered = 9,
                override_impactpositions = meteorImpacts,
                override_velocities = meteorDirections,
                sinCurvePositionDistortionPeaks = meteorCurveMaximums,
                override_velocities_scaledbytrackspeed = true}

    BatchRenderEveryFrame{prefabName="Meteor_Tail",
                ismeteortail = true,
                locations = meteorNodes_tails,
                maxShown = 1500, --500, -- 1000,
                emissivecolors = deepcopy(meteorColors_tails), -- "nodecolor", -- "highway" for them to all be the same shifting color
                colors = deepcopy(meteorColors_tails),
                --colors = meteorAlbedoColors_tails, -- meteorColors, -- "nodecolor", -- "highway" for them to all be the same shifting color
                --colors = deepcopy(meteorColors_tails),
                scales = meteorScales_tails,
                maxDistanceShown = maxNodeDistShown,
                broadcastimpactvelocities = true,
                --songspeedratio = .05, -- amount of speed compression
                songspeedratios = meteorSpeeds_tails,
                typeids = meteorTypes_tails,
                afternodereached_numbernodesrendered = 9,
                override_impactpositions = meteorImpacts_tails,
                override_velocities = meteorDirections_tails,
                sinCurvePositionDistortionPeaks = meteorCurveMaximums_tails,
                override_velocities_scaledbytrackspeed = true}

    --render impact positions to help debug hit timing
    local showDebugImpactPoints = false
    if showDebugImpactPoints then
      BatchRenderEveryFrame{prefabName="Meteor",
                  locations = meteorNodes,
                  maxShown = 50,
                  emissivecolors = deepcopy(meteorColors), -- "nodecolor", -- "highway" for them to all be the same shifting color
                  colors = meteorColors, -- "nodecolor", -- "highway" for them to all be the same shifting color
                  scales = impactProxyScales,
                  maxDistanceShown = maxNodeDistShown,
                  typeids = meteorTypes,
                  --broadcastimpactvelocities = true,
                  --songspeedratio = .05, -- amount of speed compression
                  --songspeedratios = meteorSpeeds,
                  afternodereached_numbernodesrendered = 1,
                  override_impactpositions = meteorImpacts,
                  override_velocities = impactProxyVelocities
      }
  end
                --sinCurvePositionDistortionPeaks = meteorCurveMaximums,
                --override_velocities_scaledbytrackspeed = true}
end
function InitMeteors()
      --local playerHeadHeight = GetMaxHMDHeightSinceSceneChange()
    --local baseHeight = 1.71 -- 1.8 -- dev
    --local normalImpactPointAsPercentOfBodyHeight = .8
    --local baseExpectedImpactHeight = baseHeight * normalImpactPointAsPercentOfBodyHeight
    --local playerHeightRatio = playerHeadHeight/baseHeight
    --local thisPlayer_DesiredImpactHeight = baseExpectedImpactHeight * playerHeightRatio
    --local playerHeight_impactYCompensator = thisPlayer_DesiredImpactHeight - baseExpectedImpactHeight
    local playerHeight_impactYCompensator = 0 -- this is now handled in c#

    --local playerHeight_impactYCompensator = .5*(playerHeadHeight - baseHeight)
    --print("playerHeadHeight:"..playerHeadHeight)
    --print("playerHeight_CompensationDist:"..playerHeight_impactYCompensator)


  local sqrt = math.sqrt --making a local copy of global functions improves performance a bit
  local rand = math.random
  local min = math.min
  local max = math.max
  local sin = math.sin
  local cos = math.cos
  local degreesToRadians = .0174532925

    local chainstarter = true
  local angleD
  local angle
  local heading
  local mag
  local headingNormalized
  local impactRadius
  local impactPosition  
  local lastSentNode
  local color = {255,255,255}
  local typeID
  local mirrorTypeID
  local scale = {.04,.04,.04}
  local prevBlockType = "jump"
  local prevBlockSongTime = 0
  local prevBlockImpactX = 0
  local renderThisChain = true
  local mirrorThisChain = false
  local yDuplicateThisChain = false;
  local yDupOffset = 0;
  local xMirrorOffset = 0;
  local mirrorColor
  local mirrorScale
  local jumpColor = {53,141,255} -- {53,141,173}
  local jumpScale = {.035,.035,.035}
  --local duckColor = {255,53,53} -- {176,53,53}
  local duckColor = {255,52,0} 
  local duckScale = {.035,.035,.035}
  local raveColor = {103,53,176}
  local raveScale = {.06,.06,.06}
  local impactX, impactY, impactZ
  local isGroundTroop = false
  --local curveFactorX = 100
  --local curveFactorY = 35
  local impactY_BeyondChestHeight = 0
  local tiltFactor = 0
  local intensityFactor = 0
  local intensityFactorExp = 0

  local impactProxyScales = {}
  local impactProxyVelocities = {}
  local impactProxyScale = {.005,.005,.005}
  local idInThisChain = 1

  local myChainStarTime = 0
  local myChainEndTime = 0
  local nextChainStartTime = 0

  local isBallChain = false
  local isExtraLongBallChain = false
  local sweepDir = 1
  local sweepPosX = 0
  local prevBlockIsBallChain = false
  local prevBallChainDirection = 0
  
  
    for i=1,500 do
      
      if nodes[i]~=nil and nodes[i]~='run' and nodes[i]~='dirty' then
        if chainstarter then -- bring all meteors in this chain from the same direction
          tiltFactor = 0
          intensityFactor = 0
          intensityFactorExp = 0
          idInThisChain = 1
          isBallChain = false -- most of them are squids, not ball chains
          isExtraLongBallChain = false
          local chainLength = 0

          myChainStarTime = track[i].seconds

          local k=i
          while k<=#track and nodes[k]~=nil and nodes[k]~='run' and nodes[k]~='dirty' do --use the biggest intensity found in the span
            local maxTiltSpan = maxTilt - minTilt
            local myTiltSpan = track[k].tilt - minTilt
            tiltFactor = math.max(tiltFactor, myTiltSpan/maxTiltSpan)
            intensityFactor = math.max(intensityFactor, track[k].intensity)
            myChainEndTime = track[k].seconds
            chainLength = chainLength + 1
            k = k + 1
          end

          nextChainStartTime = -1
          local kk = k
          for kk=k,#track do
            if nodes[kk]~=nil and nodes[kk]~='run' and nodes[kk]~='dirty' then
              nextChainStartTime = track[kk].seconds
              break
            end
          end

          --if i<500 then
          --  print("myChainStart:"..myChainStarTime.." myChainEnd:"..myChainEndTime.." nextChainStart:"..nextChainStartTime)
          --end

          intensityFactorExp = intensityFactor*intensityFactor*intensityFactor

        --heading = {-.5*rand() + .5, -.5*rand(), -2*rand()}
        heading = {0, 0, -1}
        headingNormalized = heading

        if nodes[i] == 'duck' then
          --impactX = -.5*rand() + .75
          impactX = redMinX + rand() * redSpanX
        elseif nodes[i] == 'jump' then
          --impactX = .5 - rand() * .75
          impactX = blueMaxX + rand() * blueSpanX
        else
          impactX = purpleSpanX*rand() + purpleMaxX
        end

        impactX = impactX * impactX_Scaler -- 1.7

        local maxAllowedX = prevBlockImpactX + maxNeighborXspan
        local minAllowedX = prevBlockImpactX - maxNeighborXspan
        impactX = math.max(impactX, minAllowedX)
        impactX = math.min(impactX, maxAllowedX)
        
        --impactY_BeyondChestHeight = rand()*yImpactSpan
        impactY_BeyondChestHeight = tiltFactor*tiltFactor*yImpactSpan + rand()*yImpactSpan_MaxRandomExtra
        impactY = chestHeight + impactY_BeyondChestHeight

        local impactDir = {impactX, impactY_BeyondChestHeight, 0}

        local targetMagSq = zImpact * zImpact
        impactZ = zImpact
        local impactXSq=impactX*impactX;
        local impactYSq = impactY_BeyondChestHeight*impactY_BeyondChestHeight
        for k=1, 9 do
          local mag = impactXSq + impactYSq + impactZ*impactZ
          if mag <= targetMagSq then
            break
          else
            impactZ = impactZ - .05
          end
        end
        --impactZ = zImpact -- .5 -- the player's arm reach ideally

        --impactMag = sqrt(impactX*impactX + impactY*impactY + impactY*impactY)
        --impactNormalized = {impactX / impactMag, impactY / impactMag, impactZ / impactMag}
        --headingNormalized = {heading[1] / mag, heading[2] / mag, heading[3] / mag}
        --impactRadius = -1 -- this should be the player's arm reach
        --impactPosition = {headingNormalized[1]*impactRadius, headingNormalized[2]*impactRadius, headingNormalized[3]*impactRadius} 

        --local armsReach = .5
        --local impactAbsolute = deepcopy(impactNormalized)
        --impactAbsolute[1] = impactAbsolute[1] * armsReach;
        --impactAbsolute[2] = impactAbsolute[2] * armsReach;
        --impactAbsolute[3] = impactAbsolute[3] * armsReach;
        --impactAbsolute[2] = impactAbsolute[2]+chestHeight
        --impactPosition = impactAbsolute

        --impactPosition = {impactX, impactY, impactZ}

        local minSameBlockTypeSpacing = 0.3

        local chainType = nodes[i]

        renderThisChain = true
        mirrorThisChain = false
        isGroundTroop = false
        yDuplicateThisChain = false
        yDupOffset = 0
        xMirrorOffset = 0

        --if track[i].intensity < .5 and rand()>.4 then
        --if chainType == 'rave' then
        --  --this one is a ground troop
        --  isGroundTroop = true
        --  impactY = chestHeight - .1
        --  if chainType == 'jump' then
        --    impactX = -1*math.abs(impactX)
        --  elseif chainType == 'duck' then
        --    impactX = math.abs(impactX)
        --  end
        --end

        local minSpacingAfterRaveBlock = 0.3

        --if i<1000 then
        --  print(chainType.."."..track[i].seconds.." prevTime:"..prevBlockSongTime)
        --end

        if prevBlockType == 'rave' then
          if  not ((track[i].seconds - prevBlockSongTime) >= minSpacingAfterRaveBlock) then
            renderThisChain = false -- don't render anything too close right after a rave
          elseif not ((track[i].seconds - prevBlockSongTime) >= 1.5) then
            --if we follow a rave, make sure we're not hidden behind it
            if chainType == 'rave' then
              impactX = prevBlockImpactX
            elseif chainType == 'jump' then
              if prevBlockImpactX < .2 then
                impactX = .35
              else
                impactX = 0
              end
            elseif chainType == 'duck' then
              if prevBlockImpactX > -.2 then
                impactX = -.35
              else
                impactX = 0
              end
            end
          end
        end

        local timeGapUntilNextChain = nextChainStartTime - myChainEndTime
        local minRequiredStrafeForMirroring = .25
        local forceMirrorOn = (nextChainStartTime<0) or ((intensityFactor > .5) and (timeGapUntilNextChain>2.0)) or (timeGapUntilNextChain>4.0)
        local tooClose = false

        if  not ((track[i].seconds - prevBlockSongTime) >= minSameBlockTypeSpacing) then
          tooClose = true;
          --needs to change to the other type, these two are too close together
          if prevBlockType == 'rave' then
            --renderThisChain = false -- don't render anything too close right after a rave
          elseif prevBlockType == 'jump' then
            chainType = 'jump'
            impactX = prevBlockImpactX
          elseif prevBlockType == 'duck' then
            chainType = 'duck'
            impactX = prevBlockImpactX
          end
        end

        if (not tooClose) or forceMirrorOn then
          if chainType ~= 'rave' then
            if (intensityFactor > .75) or forceMirrorOn then -- big hit, end of song, or before a gap
              if forceMirrorOn then
                if math.abs(impactX)< minRequiredStrafeForMirroring then
                  impactX = minRequiredStrafeForMirroring + .01
                end
              end
              if math.abs(impactX) >= minRequiredStrafeForMirroring then
                if (rand() > .8) or forceMirrorOn then
                  mirrorThisChain = true
                  impactX = math.max(-1*maxMirroredX, math.min(maxMirroredX, impactX))
                  if chainType=='jump' then
                    impactX = -1 * math.abs(impactX) -- make sure the blue is on the left
                    mirrorScale = duckScale
                    mirrorColor = duckColor
                  else
                    impactX = math.abs(impactX) -- make sure the red is on the right
                    mirrorScale = jumpScale
                    mirrorColor = jumpColor
                  end
                end
              end
            end
          end
        end

        if chainType=='jump' then
          color = jumpColor
          scale = jumpScale
          typeID = 0
          mirrorTypeID = 1
        elseif chainType=='duck' then
          color = duckColor
          scale = duckScale
          typeID = 1
          mirrorTypeID = 0
        elseif chainType=='rave' then
          color = raveColor
          scale = raveScale
          typeID = 2
          mirrorTypeID = 2
        end


        --if i <1000 then
        --  print("intensity:"..intensityFactor)
        --end

        if (not mirrorThisChain) and (chainType~='rave') then
          --if (rand()>.9) and (chainLength>7) then
          --  isBallChain = true
          --end
          if (chainLength>11) and (intensityFactor<.6) then
            isBallChain = true
          end
          if (chainLength>22) and (intensityFactor<.9) then
            isBallChain = true
          end
          --if chainLength>22 then
          --  isBallChain = true
          --end
        end

        sweepDir = 1
        if impactX > 0 then sweepDir = -1 end
        sweepPosX = impactX

        if isBallChain and chainLength>66 then
          isExtraLongBallChain = true
        end

        if convertPurplesToCrossUps then
          if chainType=='rave' then -- try turning purples into double vertical hits
            impactX = math.abs(impactX)
            chainType = 'duck'
            color = duckColor
            typeID = 1
            mirrorTypeID = 0
            scale = duckScale
            mirrorThisChain = true
            mirrorScale = jumpScale
            mirrorColor = jumpColor
            --yDuplicateThisChain = true
            --yDupOffset = .2
            xMirrorOffset = .5 --put the blues on the wrong side
          end
        end

        chainstarter = false
        else
          idInThisChain = idInThisChain + 1
        end

        local yCurve = impactY_BeyondChestHeight*curveFactorY
        yCurve = math.min(yCurve, curveY_Max)
        yCurve = math.max(yCurve, curveY_Min)
        --yCurve = curveY_Max
        --local yCurve = impactY*curveFactorY
        --local yCurve = impactY*curveFactorY*((1.0-curveY_tiltInfluence)+curveY_tiltInfluence*tiltFactor)
        --local yCurve = impactY*curveFactorY*((1.0-curveY_tiltInfluence)+curveY_tiltInfluence*intensityFactorExp)

        --if renderThisChain and ((idInThisChain%2)==1) then -- only render every other ball in the chain
        if renderThisChain then
          prevBlockSongTime = track[i].seconds
          prevBlockType = chainType -- nodes[i]
          prevBlockImpactX = impactX
          prevBlockIsBallChain = isBallChain
          prevBallChainDirection = 1

          local adjustedImpactY = impactY + playerHeight_impactYCompensator

            lastSentNode = i

            if idInThisChain==1 or isBallChain or yDuplicateThisChain then --this is the head of a chain or a strafe chain (ballChain)
              local allowRender =  true
              if isExtraLongBallChain and (idInThisChain>1) and (idInThisChain%2==0) then
                allowRender = false -- for extra long chains, render only every other orb
              end
              
              if allowRender then
                local additionalX_SweepAcross = 0 -- -.005 + idInThisChain * .0015
                local sweptImpactX = impactX
                if isBallChain then
                  --additionalX_SweepAcross = -.025 + idInThisChain * .025
                  --if impactX > 0 then -- always move the trail towards center
                  --  additionalX_SweepAcross = additionalX_SweepAcross * -1
                  --  prevBallChainDirection = -1
                  --end
                  --sweptImpactX = sweptImpactX + additionalX_SweepAcross
                  --sweptImpactX = math.max(-1, math.min(sweptImpactX, 1)) -- contain them to a reseonable field size

                  sweepPosX = sweepPosX + .025 * sweepDir
                  if sweepPosX > 1 then
                    sweepPosX = 1
                    sweepDir = -1
                  elseif sweepPosX < -1 then
                    sweepPosX = -1
                    sweepDir = 1
                  end
                  sweptImpactX = sweepPosX

                  prevBlockImpactX = sweptImpactX
                end

--                meteorNodes[#meteorNodes+1] = i
--              meteorDirections[#meteorDirections+1] = headingNormalized -- {math.random() - .5, 0, math.random() - .5} -- the game normalizes these for us
--              meteorImpacts[#meteorImpacts+1] = {sweptImpactX, adjustedImpactY, impactZ}
--              meteorScales[#meteorScales+1] = scale
--              --meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{impactX*curveFactorX, impactY*curveFactorY, 0})--impactY*60
--              meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{sweptImpactX*curveFactorX, yCurve, 0})--impactY*60
--              meteorColors[#meteorColors+1] = color
--              meteorAlbedoColors[#meteorAlbedoColors+1] = {255,255,255}
--              meteorSpeeds[#meteorSpeeds+1] = meteorSpeed -- fif(isGroundTroop, .025,.05)
--              meteorTypes[#meteorTypes+1] = typeID
--
--              impactProxyScales[#impactProxyScales+1] = impactProxyScale
--              impactProxyVelocities[#impactProxyVelocities+1] = {0,0,0}

                  meteorNodes[#meteorNodes+1] = i
              meteorDirections[#meteorDirections+1] = {0, -0.3,-1}
              meteorImpacts[#meteorImpacts+1] = {0.5, adjustedImpactY, impactZ}
              meteorScales[#meteorScales+1] = scale
              --meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{impactX*curveFactorX, impactY*curveFactorY, 0})--impactY*60
              meteorCurveMaximums[#meteorCurveMaximums+1] = {0,0,0}
              meteorColors[#meteorColors+1] = {255,0,0}
              meteorAlbedoColors[#meteorAlbedoColors+1] = {255,255,255}
              meteorSpeeds[#meteorSpeeds+1] = meteorSpeed -- fif(isGroundTroop, .025,.05)
              meteorTypes[#meteorTypes+1] = 1

              impactProxyScales[#impactProxyScales+1] = impactProxyScale
              impactProxyVelocities[#impactProxyVelocities+1] = {0,0,0}

--              if yDuplicateThisChain then
--                  meteorNodes[#meteorNodes+1] = i
--                meteorDirections[#meteorDirections+1] = headingNormalized -- {math.random() - .5, 0, math.random() - .5} -- the game normalizes these for us
--                meteorImpacts[#meteorImpacts+1] = {sweptImpactX, adjustedImpactY+yDupOffset, impactZ}
--                meteorScales[#meteorScales+1] = scale
--                --meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{impactX*curveFactorX, impactY*curveFactorY, 0})--impactY*60
--                meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{sweptImpactX*curveFactorX, yCurve, 0})--impactY*60
--                meteorColors[#meteorColors+1] = color
--                meteorAlbedoColors[#meteorAlbedoColors+1] = {255,255,255}
--                meteorSpeeds[#meteorSpeeds+1] = meteorSpeed -- fif(isGroundTroop, .025,.05)
--                meteorTypes[#meteorTypes+1] = typeID
--
--                impactProxyScales[#impactProxyScales+1] = impactProxyScale
--                impactProxyVelocities[#impactProxyVelocities+1] = {0,0,0}
--              end
--
--              if mirrorThisChain then
--                local mirrorImpactX = -1*impactX
--                if xMirrorOffset ~= 0 then
--                  mirrorImpactX = impactX + xMirrorOffset
--                end
--                  meteorNodes[#meteorNodes+1] = i
--                meteorDirections[#meteorDirections+1] = headingNormalized -- {math.random() - .5, 0, math.random() - .5} -- the game normalizes these for us
--                meteorImpacts[#meteorImpacts+1] = {mirrorImpactX, adjustedImpactY, impactZ}
--                meteorScales[#meteorScales+1] = mirrorScale
--                --meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{-1*impactX*curveFactorX, impactY*curveFactorY, 0})
--                meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{mirrorImpactX*curveFactorX, yCurve, 0})
--                meteorColors[#meteorColors+1] = mirrorColor
--                meteorAlbedoColors[#meteorAlbedoColors+1] = {255,255,255}
--                meteorSpeeds[#meteorSpeeds+1] = meteorSpeed -- fif(isGroundTroop, .025,.05)
--                meteorTypes[#meteorTypes+1] = mirrorTypeID
--
--                impactProxyScales[#impactProxyScales+1] = impactProxyScale
--                impactProxyVelocities[#impactProxyVelocities+1] = {0,0,0}
--
--                if yDuplicateThisChain then
--                  meteorNodes[#meteorNodes+1] = i
--                  meteorDirections[#meteorDirections+1] = headingNormalized -- {math.random() - .5, 0, math.random() - .5} -- the game normalizes these for us
--                  meteorImpacts[#meteorImpacts+1] = {mirrorImpactX, adjustedImpactY+yDupOffset, impactZ}
--                  meteorScales[#meteorScales+1] = mirrorScale
--                  --meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{-1*impactX*curveFactorX, impactY*curveFactorY, 0})
--                  meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{mirrorImpactX*curveFactorX, yCurve, 0})
--                  meteorColors[#meteorColors+1] = mirrorColor
--                  meteorAlbedoColors[#meteorAlbedoColors+1] = {255,255,255}
--                  meteorSpeeds[#meteorSpeeds+1] = meteorSpeed -- fif(isGroundTroop, .025,.05)
--                  meteorTypes[#meteorTypes+1] = mirrorTypeID
--
--                  impactProxyScales[#impactProxyScales+1] = impactProxyScale
--                  impactProxyVelocities[#impactProxyVelocities+1] = {0,0,0}
--                end
--              end
--            end
--          else -- this is part of a chain tail
--            --.035 -> .06
--            local additionalScale = -.005 + idInThisChain * .0015
--            additionalScale = math.min(additionalScale, .09)
--            local tailScale = {1,1,1}
--            tailScale[1] = scale[1] + additionalScale
--            tailScale[2] = scale[2] + additionalScale
--            tailScale[3] = scale[3] + additionalScale
--
--            --if i<1000 then
--            --  print("idInThisChain "..idInThisChain)
--            --  print("additionalScale "..additionalScale)
--            --  print("scaleX "..tailScale[1])
--            --end
--
--              meteorNodes_tails[#meteorNodes_tails+1] = i
--            meteorDirections_tails[#meteorDirections_tails+1] = headingNormalized -- {math.random() - .5, 0, math.random() - .5} -- the game normalizes these for us
--            meteorImpacts_tails[#meteorImpacts_tails+1] = {impactX, adjustedImpactY, impactZ}
--            meteorScales_tails[#meteorScales_tails+1] = tailScale
--            --meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{impactX*curveFactorX, impactY*curveFactorY, 0})--impactY*60
--            meteorCurveMaximums_tails[#meteorCurveMaximums_tails+1] = fif(isGroundTroop,{0,0,0},{impactX*curveFactorX, yCurve, 0})--impactY*60
--            meteorColors_tails[#meteorColors_tails+1] = color
--            meteorAlbedoColors_tails[#meteorAlbedoColors_tails+1] = {255,255,255}
--            meteorSpeeds_tails[#meteorSpeeds_tails+1] = meteorSpeed -- fif(isGroundTroop, .025,.05)
--            meteorTypes_tails[#meteorTypes_tails+1] = typeID
--
--            impactProxyScales[#impactProxyScales+1] = impactProxyScale
--            impactProxyVelocities[#impactProxyVelocities+1] = {0,0,0}
--
--            if mirrorThisChain then
--              local mirrorImpactX = -1*impactX
--              if xMirrorOffset ~= 0 then
--                mirrorImpactX = impactX + xMirrorOffset
--              end
--                meteorNodes_tails[#meteorNodes_tails+1] = i
--              meteorDirections_tails[#meteorDirections_tails+1] = headingNormalized -- {math.random() - .5, 0, math.random() - .5} -- the game normalizes these for us
--              meteorImpacts_tails[#meteorImpacts_tails+1] = {mirrorImpactX, adjustedImpactY, impactZ}
--              meteorScales_tails[#meteorScales_tails+1] = tailScale -- mirrorScale
--              --meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{-1*impactX*curveFactorX, impactY*curveFactorY, 0})
--              meteorCurveMaximums_tails[#meteorCurveMaximums_tails+1] = fif(isGroundTroop,{0,0,0},{mirrorImpactX*curveFactorX, yCurve, 0})
--              meteorColors_tails[#meteorColors_tails+1] = mirrorColor
--              meteorAlbedoColors_tails[#meteorAlbedoColors_tails+1] = {255,255,255}
--              meteorSpeeds_tails[#meteorSpeeds_tails+1] = meteorSpeed -- fif(isGroundTroop, .025,.05)
--              meteorTypes_tails[#meteorTypes_tails+1] = mirrorTypeID
--
--              impactProxyScales[#impactProxyScales+1] = impactProxyScale
--              impactProxyVelocities[#impactProxyVelocities+1] = {0,0,0}
            end
          end
        end
      else
        chainstarter = true
      end
    end

    
    
              local f = io.open("D:\\Programs_new\\Songs\\2355 Iori - Kimi ga Ireba\\Iori - Kimi ga Ireba (dipsy) [Hattori Heiji].osu", "rb")

             --if f then 
             -- f:close()
              
              meteorNodes[#meteorNodes+1] = 700
              meteorDirections[#meteorDirections+1] = {0, 0,-1}
              meteorImpacts[#meteorImpacts+1] = {0.5, adjustedImpactY, impactZ}
              meteorScales[#meteorScales+1] = scale
              --meteorCurveMaximums[#meteorCurveMaximums+1] = fif(isGroundTroop,{0,0,0},{impactX*curveFactorX, impactY*curveFactorY, 0})--impactY*60
              meteorCurveMaximums[#meteorCurveMaximums+1] = {0,0,0}
              meteorColors[#meteorColors+1] = {255,0,0}
              meteorAlbedoColors[#meteorAlbedoColors+1] = {255,255,255}
              meteorSpeeds[#meteorSpeeds+1] = meteorSpeed -- fif(isGroundTroop, .025,.05)
              meteorTypes[#meteorTypes+1] = 1

              impactProxyScales[#impactProxyScales+1] = impactProxyScale
              impactProxyVelocities[#impactProxyVelocities+1] = {0,0,0}
             --end
    
    print("...............................")
    print("track length:"..#track)
    print("last meteor node"..lastSentNode)

    BatchRenderEveryFrame{prefabName="Meteor",
                locations = meteorNodes,
                maxShown = 100, --500, -- 1000,
                emissivecolors = deepcopy(meteorColors), -- "nodecolor", -- "highway" for them to all be the same shifting color
                colors = deepcopy(meteorColors),
                --colors = meteorAlbedoColors, -- meteorColors, -- "nodecolor", -- "highway" for them to all be the same shifting color
                scales = meteorScales,
                maxDistanceShown = maxNodeDistShown,
                broadcastimpactvelocities = true,
                --songspeedratio = .05, -- amount of speed compression
                songspeedratios = meteorSpeeds,
                typeids = meteorTypes,
                afternodereached_numbernodesrendered = 9,
                override_impactpositions = meteorImpacts,
                override_velocities = meteorDirections,
                sinCurvePositionDistortionPeaks = meteorCurveMaximums,
                override_velocities_scaledbytrackspeed = true}

    BatchRenderEveryFrame{prefabName="Meteor_Tail",
                ismeteortail = true,
                locations = meteorNodes_tails,
                maxShown = 1500, --500, -- 1000,
                emissivecolors = deepcopy(meteorColors_tails), -- "nodecolor", -- "highway" for them to all be the same shifting color
                colors = deepcopy(meteorColors_tails),
                --colors = meteorAlbedoColors_tails, -- meteorColors, -- "nodecolor", -- "highway" for them to all be the same shifting color
                --colors = deepcopy(meteorColors_tails),
                scales = meteorScales_tails,
                maxDistanceShown = maxNodeDistShown,
                broadcastimpactvelocities = true,
                --songspeedratio = .05, -- amount of speed compression
                songspeedratios = meteorSpeeds_tails,
                typeids = meteorTypes_tails,
                afternodereached_numbernodesrendered = 9,
                override_impactpositions = meteorImpacts_tails,
                override_velocities = meteorDirections_tails,
                sinCurvePositionDistortionPeaks = meteorCurveMaximums_tails,
                override_velocities_scaledbytrackspeed = true}

end

camHeightMax = 1100
camHeightMin = 750
camHeight = camHeightMax
score = score or 10000

skinHasLoaded = skinHasLoaded or false
function OnSkinLoaded()-- called after OnTrafficCreated
--[[
    BatchRenderEveryFrame{prefabName="Meteor",
                locations = meteorNodes,
                maxShown = 1000,
                emissivecolors = deepcopy(meteorColors), -- "nodecolor", -- "highway" for them to all be the same shifting color
                colors = meteorColors, -- "nodecolor", -- "highway" for them to all be the same shifting color
                scales = meteorScales,
                maxDistanceShown = maxNodeDistShown,
                broadcastimpactvelocities = true,
                --songspeedratio = .05, -- amount of speed compression
                songspeedratios = meteorSpeeds,
                afternodereached_numbernodesrendered = 9,
                override_impactpositions = meteorImpacts,
                override_velocities = meteorDirections,
                sinCurvePositionDistortionPeaks = meteorCurveMaximums,
                override_velocities_scaledbytrackspeed = true}
--]]



  HideBuiltinPlayerObjects()

  SetCamera{ -- calling this function (even just once) overrides the camera settings from the skin script
    pos = {0,0,0},
    rot = {0,0,0},
    railoffset = "detached" -- this camera will not move along the track
  }

  skinHasLoaded = true

  InitMeteors()
  hasInitedMeteors = true
end

--function OnPlayerHeightEstablished(playerHeight)
--  InitMeteors()
--  hasInitedMeteors = true
--end

dinoAngle = 0
hittable = true
invulnTicker = 0
invulnDuration = .7
hitsSuffered = 0
timeMoving = 0
timeTotal = 0

function GetScore()
  local numMissed = GetNumShieldMisses()
  return math.max(1, 1000 - 1 * numMissed)
end

quarterSecondCounter = 0
function UpdateEachQuarterSecond()
  local scoref = GetScore()
  SetGlobalScore{score=scoref,showdelta=false}
end

updatesRun = updatesRun or 0
hasInitedMeteors = hasInitedMeteors or false
--[[
function Update(dt, tracklocation, strafe, input, jumpheight) --called every frame by the game engine
  local paused = (dt==0)
  --if (not paused) and (updatesRun > 20) and (not hasInitedMeteors) and skinHasLoaded then
  if (updatesRun > 4) and (not hasInitedMeteors) and skinHasLoaded then
    --InitMeteors()
    --hasInitedMeteors = true
  end

  local iCurrentRing = math.floor(tracklocation)

  local input = GetInput()
  local player1input = input.players[1]
  local keyHorizontal = player1input["Horizontal"]

  dinoAngle = dinoAngle + 150 * keyHorizontal * dt

  timeTotal = timeTotal + dt
  if math.abs(keyHorizontal) > .5 then
    timeMoving = timeMoving + dt
  end

  quarterSecondCounter = quarterSecondCounter + dt
  if quarterSecondCounter>.25 then
    quarterSecondCounter = quarterSecondCounter - .25
    UpdateEachQuarterSecond()
  end 

  updatesRun = updatesRun + 1
end
--]]

function OnRequestFinalScoring()
  AssignBuiltInAudioshieldScoring()
  --[[
  local numMisses = GetNumShieldMisses()
  local numSuccesses = (#meteorNodes)-numMisses
  local scoref = GetScore()
  local numErroneousPurpleOverlapsOnSuccessfulBlocks = GetNumRaveShieldOverlaps()
  local numErroneousWrongShieldOverlapsOnSuccessfulBlocks = GetNumOtherSingleShieldOverlaps()

  --local efficiencyBonus = math.max(0,50 - numErroneousPurpleOverlapsOnSuccessfulBlocks - numErroneousWrongShieldOverlapsOnSuccessfulBlocks);
  local efficiencyBonus = math.max(0,50 - numErroneousWrongShieldOverlapsOnSuccessfulBlocks);

  local maxShieldPunchSpeed = GetMaxPunchStrength();
  local averagePunchSpeed = GetAveragePunchStrength();
  local styleBonus = math.floor(.5 + (maxShieldPunchSpeed/2 + averagePunchSpeed*2))

  return {
    rawscore = scoref,
    bonuses = {
      "Shield Blocks: "..numSuccesses,
      "Shield Misses: "..numMisses,
      " ",
      "--- Style Bonus ---",
      --"Super Used Unecessarily: "..numErroneousPurpleOverlapsOnSuccessfulBlocks,
      --"Wrong Shield Blocked First: "..numErroneousWrongShieldOverlapsOnSuccessfulBlocks,
      --"Efficiency Bonus: "..efficiencyBonus,
      --"--- The More Your Know ---",
      "Average Punch Strength: "..averagePunchSpeed,
      "Max Punch Strength: "..maxShieldPunchSpeed,
      "Style Bonus: "..styleBonus,
      " "
    },
    finalscore = scoref + styleBonus -- efficiencyBonus
  }
  --]]
end