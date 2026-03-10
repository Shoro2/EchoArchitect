local addonName=...
EchoArchitect=EchoArchitect or {}
local EA=EchoArchitect
EA.Utils=EA.Utils or {}
local U=EA.Utils
function U.QualityName(q)
  q=tonumber(q or 0) or 0
  if q==0 then return "Common" end
  if q==1 then return "Uncommon" end
  if q==2 then return "Rare" end
  if q==3 then return "Epic" end
  if q==4 then return "Legendary" end
  return "Unknown"
end
function U.ParseKey(key)
  local sid=tonumber(string.match(key,"^(%d+):") or 0) or 0
  local q=tonumber(string.match(key,":(%d+)$") or 0) or 0
  return sid,q
end
function U.ReasonText(r)
  if r=="onlyBlacklisted" then return "Paused: Blacklisted / Negative Only" end
  if r=="multipleAbove" then return "Paused: Threshold Met" end
  if r=="sessionComplete" then return "Paused: Session Complete" end
  return "Paused"
end
function U.ShowSpellTooltip(owner,spellId)
  if not GameTooltip or not spellId or spellId==0 then return end
  GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
  if GameTooltip.SetSpellByID then
    GameTooltip:SetSpellByID(spellId)
  elseif GameTooltip.SetHyperlink then
    GameTooltip:SetHyperlink("spell:"..tostring(spellId))
  elseif GameTooltip.SetText then
    local name=GetSpellInfo and GetSpellInfo(spellId)
    if name then GameTooltip:SetText(name) end
  end
  GameTooltip:Show()
end
function U.GetRunData()
  if ProjectEbonhold and ProjectEbonhold.PlayerRunService then
    if ProjectEbonhold.PlayerRunService.GetCurrentData then
      local ok,res=pcall(ProjectEbonhold.PlayerRunService.GetCurrentData)
      if ok and type(res)=="table" then return res end
    end
    if ProjectEbonhold.PlayerRunService.Get then
      local ok,res=pcall(ProjectEbonhold.PlayerRunService.Get)
      if ok and type(res)=="table" then return res end
    end
  end
  if type(_G.EbonholdPlayerRunData)=="table" then return _G.EbonholdPlayerRunData end
  return {}
end
function U.RerollsRemaining(pr)
  local rd=U.GetRunData()
  local remField=tonumber(rd.remainingRerolls or rd.rerollsRemaining or rd.rerollsLeft or rd.rerollCharges or 0) or 0
  if remField>0 then return remField,remField,0 end
  local used=tonumber(rd.usedRerolls or rd.rerollsUsed or 0) or 0
  local total=tonumber(rd.totalRerolls or rd.rerollsTotal or 0) or 0
  if total>0 then return math.max(0,total-used),total,used end
  local maxRow=pr and pr.automation and tonumber(pr.automation.maxRerollsPerOffer) or nil
  if not maxRow then maxRow=10 end
  local thisOffer=EA.Engine and EA.Engine.state and tonumber(EA.Engine.state.rerollsThisOffer or 0) or 0
  local rem=math.max(0,maxRow-thisOffer)
  return rem,maxRow,thisOffer
end
function U.BanishesRemaining()
  if not (ProjectEbonhold and ProjectEbonhold.Constants and ProjectEbonhold.Constants.ENABLE_BANISH_SYSTEM) then return 0 end
  local rd=U.GetRunData()
  local remField=tonumber(rd.remainingBanishes or rd.banishesRemaining or rd.banishesLeft or rd.banishCharges or 0) or 0
  if remField>0 then return remField end
  local used=tonumber(rd.usedBanishes or rd.banishesUsed or 0) or 0
  local total=tonumber(rd.totalBanishes or rd.banishesTotal or 0) or 0
  if total>0 then
    local rem=total-used
    if rem<0 then rem=0 end
    return rem
  end
  return 0
end
