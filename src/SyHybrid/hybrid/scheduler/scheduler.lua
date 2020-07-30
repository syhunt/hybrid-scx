ScanScheduler = {
 title = 'Scan Scheduler'
}

-- Returns the name of the app associated with tracker (Jira, GitHub, etc)
function ScanScheduler:GetScheduledScan(name)
  local jsonfile = symini.info.configdir..'\\Scheduler\\'..name..'.json'
  local j = ctk.json.object:new()
  local app = ''
  j:loadfromfile(jsonfile)
  app = j['tracker.defaultapp']
  j:release()
  return app
end

function ScanScheduler:EditSchedulePreferences(name)
  local jsonfile = symini.info.configdir..'\\Scheduler\\'..name..'.json'
  local slp = ctk.string.loop:new()
  local hs = symini.hybrid:new()
  hs:start()
  slp:load(hs.options)
  while slp:parsing() do
    prefs.regdefault(slp.current,hs:prefs_getdefault(slp.current))
  end
  local t = {}
  t.html = SyHybrid:getfile('hybrid/prefs_scheduler/prefs.html')
  t.html = ctk.string.replace(t.html,'%dynamic_targets%',SyhuntDynamic:GetTargetListHTML())
  t.html = ctk.string.replace(t.html,'%code_targets%',SyhuntCode:GetTargetListHTML())
  t.html = ctk.string.replace(t.html,'%email_trackers%',TrackerManager:gettrackeroptionlist('EMAIL'))
  t.id = 'syhuntschedulerprefs'
  t.options = hs.options
  t.jsonfile = jsonfile
  hs:release()
  slp:release()  
  return Sandcat.Preferences:EditCustomFile(t)
end

function ScanScheduler:EditScheduleTargetPreferences(name)
  local hs = symini.hybrid:new()
  hs:start()
  local res = hs:scheduler_getscheduledscandetails(name)
  if res.success == true then  
    if res.target_type == 'url' then
      SyhuntDynamic:EditSitePreferences(res.target_url)
    else
      app.showmessage('Target preferences not supported for this type of target.')
    end
  else
    app.showmessage('Failed! '..res.errormsg)
  end    
  hs:release()  
end

function ScanScheduler:ShowScheduledScanCommandLine(name, action)
  action = action or "show"
  local hs = symini.hybrid:new()
  hs:start()
  local res = hs:scheduler_getscheduledscancmdln(name)
    if res.success == true then
      if action == 'show' then
        app.showalerttext(res.filename..' '..res.params)
      elseif action == 'copyfilename' then
        ctk.utils.clipboard_settext(res.filename)
      elseif action == 'copyfilenamenparams' then
        local sl = ctk.string.list:new()
        sl:add('Filename: '..res.filename)
        sl:add('Parameters: '..res.params)
        ctk.utils.clipboard_settext(sl.text)
        sl:release()
      elseif action == 'copyparams' then
        ctk.utils.clipboard_settext(res.params)
      end
    else
      app.showmessage('Failed! '..res.errormsg)
    end
  hs:release()
end

function ScanScheduler:TestScheduledScan(name)
  local hs = symini.hybrid:new()
  hs:start()
  local res = hs:scheduler_runscheduledscan(name)
  if res.success == false then
    app.showmessage('Failed! '..res.errormsg)
  end
  hs:release()
end

function ScanScheduler:AddScheduledScan()
  if SyHybridUser:IsOptionAvailable(true) == true then
    local name = app.showinputdialog('Enter name:','')
    name = ctk.file.cleanname(name)
    if name ~= '' then
      local item  = {}
      item.name = name
      item.url = ctk.convert.strtohex(name)
      item.repeatnameallow = false
      item.repeatnamewarn = true    
      if HistView:AddURLLogItem(item, symini.info.schedlistname) == true then
        self:EditSchedulePreferences(item.name, item.url)
        symini.scheduler_sendsignal('update')
        self:ViewScheduledScans(false)
      end
    end
  end
end

function ScanScheduler:DoSchedulerAction(action, itemid)
  local item = HistView:GetURLLogItem(itemid, symini.info.schedlistname)
  if item ~= nil then
    if action == 'editprefs' then
      local ok = self:EditSchedulePreferences(item.name, item.url)
      if ok == true then
        symini.scheduler_sendsignal('update')
        self:ViewScheduledScans(false)
      end
    end
    if action == 'editsiteprefs' then
      self:EditScheduleTargetPreferences(item.name)
    end    
    if action == 'showcmdln' then
      self:ShowScheduledScanCommandLine(item.name)
    end
    if action == 'copycmdln_filenamenparams' then
      self:ShowScheduledScanCommandLine(item.name, 'copyfilenamenparams')
    end
    if action == 'copycmdln_filename' then
      self:ShowScheduledScanCommandLine(item.name, 'copyfilename')
    end
    if action == 'copycmdln_params' then
      self:ShowScheduledScanCommandLine(item.name, 'copyparams')
    end    
    if action == 'test' then
      self:TestScheduledScan(item.name)
    end
    if action == 'delete' then
      HistView:DeleteURLLogItem(itemid,symini.info.schedlistname)
      local jsonfile = symini.info.configdir..'\\Scheduler\\'..item.name..'.json'
      ctk.file.delete(jsonfile)
    end
  end
end

function ScanScheduler:GetScheduledScansList()
  HistView = HistView or Sandcat:require('histview')  
  return HistView:GetURLLogItemNames(symini.info.schedlistname)
end

function ScanScheduler.GenSchedDescription(t)
  local desc = symini.getscheduledscandesc(t.name)
  desc = ctk.html.escape(desc)
  return desc
end

function ScanScheduler:ViewScheduledScans(newtab)
 local t = {}
 t.newtab = newtab
 t.toolbar = 'SyHybrid.scx#hybrid/scheduler/toolbar.html'
 t.histname = symini.info.schedlistname
 t.tabicon = 'url(SyHybrid.scx#images\\16\\date_task.png);'
 t.html = Sandcat:getfile('histview_list.html')
 t.genurlfunc = self.GenSchedDescription
 t.style = [[
  ]]
 t.menu = [[
  <li onclick="ScanScheduler:DoSchedulerAction('editprefs','%i')">Edit Schedule Preferences...</li>
  <hr/>
  <li onclick="ScanScheduler:DoSchedulerAction('editsiteprefs','%i')">Edit Assigned Target Preferences...</li>
  <hr/>
  <li>CLI Parameters
   <menu>
   <li onclick="ScanScheduler:DoSchedulerAction('copycmdln_filenamenparams','%i')">Copy Filename & Parameters</li>  
   <li onclick="ScanScheduler:DoSchedulerAction('copycmdln_filename','%i')">Copy Filename</li>  
   <li onclick="ScanScheduler:DoSchedulerAction('copycmdln_params','%i')">Copy Parameters</li>
   <hr/>
   <li onclick="ScanScheduler:DoSchedulerAction('showcmdln','%i')">Show Command Line</li>
   <hr/>
   <li onclick="ScanScheduler:DoSchedulerAction('test','%i')">Run Test Scan Now</li>
   </menu>
  </li>
  <hr/>
  <li onclick="ScanScheduler:DoSchedulerAction('delete','%i')">Delete</li>
  ]]  
 HistView = HistView or Sandcat:require('histview')  
 HistView:ViewURLLogFile(t)
 if newtab == false then
   symini.scheduler_sendsignal('start')
 end
end