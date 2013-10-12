global class PickleScenarios extends PickleAllScenarios {
    public Integer componentIdx { get; set; }
    public List<SelectOption> listComponents { get; private set; }
    public String testJobId { get; private set; }
    public String debug { get; private set; }
    public List<Pickle.Scenario> allScenarios { get; private set; }
    public Map<String, List<Pickle.Scenario>> scenariosByTestClass { get; private set; }
    transient public Map<String, String> testClass2error { get; private set; }
    public List<Pickle.Alias> aliases { get; private set; }
    public String className { get; set; }    
    public static Integer scenarioNb;
    public List<String> getTestClasses() { List<String> l = new List<String>(); l.addall(scenariosByTestClass.keySet()); l.sort(); return l; }
    List<Pickle> components;

    // INSTANCE METHODS
    private void createScenarioList() {
        allScenarios = components[componentIdx - 1].getScenarios();
        aliases = components[componentIdx - 1].getAliases();
        for (Integer nb=0; nb<aliases.size(); nb++) aliases[nb].nb = nb;

        Map<String, List<Integer>> scenarioIdxByTestClass = new Map<String, List<Integer>>();
        scenariosByTestClass = new Map<String, List<Pickle.Scenario>>();
        testClass2error = new Map<String, String>();
        List<Integer> l;
        List<Pickle.Scenario> l_sc;
        
        Pickle.Scenario sc;
        for (Integer nb=1; nb<=allScenarios.size(); nb++) {
            sc = allScenarios[nb - 1];
            sc.nb = nb-1;
            if (scenarioIdxByTestClass.containsKey(sc.testClass)) {
                l = scenarioIdxByTestClass.get(sc.testClass);
                l_sc = scenariosByTestClass.get(sc.testClass);
            }
            else {
                l = new List<Integer>();
                scenarioIdxByTestClass.put(sc.testClass, l);
                l_sc = new List<Pickle.Scenario>();
                scenariosByTestClass.put(sc.testClass, l_sc);
                testClass2error.put(sc.testClass, '');
            }
            l.add(nb);
            l_sc.add(sc);
        }
        
        // Step 2: check that the scenarios are actually called in the test classes
        Boolean isCovered = false;
        Integer idx1, idx2, idx3;
        
        for (ApexClass ac : [SELECT Name, body FROM ApexClass WHERE name IN :(scenariosByTestClass.keySet())]) {
        
            for (Integer nb : scenarioIdxByTestClass.get(ac.Name)) {
                isCovered = false;
                idx1 = ac.body.indexOfIgnoreCase('.runScenario(');
                while (idx1 >= 0 && isCovered == false) {
                    idx2 = ac.body.indexOf(');', idx1);
                    if (idx2 < 0) break;
                    idx3 = ac.body.lastIndexOfIgnoreCase('\n', idx1);
                    if (idx3 < 0) idx3 = 0; else idx3++;
                    if (ac.body.substring(idx3, idx3 + 2) != '//') {
                        isCovered = (ac.body.substring(idx1 + 13, idx2).trim() == String.valueOf(nb));
                    }
                    idx1 = ac.body.indexOfIgnoreCase('.runScenario(', idx2 + 1);
                }
                sc.isCoveredByTest(isCovered);
            }
        }
    }
    
    public PickleScenarios() {
        listComponents = new List<SelectOption>();
        testJobId = '';
        componentIdx = 1;
        
        components = new List<Pickle>();
        Type t;
        Pickle p;
        Integer nb = 0;
        for (String s : getPickles()) {
            t = Type.forName(s);
            if (t == null) throw new Pickle.PickleException('Class "' + s + '" unknown. Please check PickleAllScenarios apex class');
            p = (Pickle)t.newInstance();
            components.add(p);
            nb++;
            listComponents.add(new SelectOption(String.valueOf(nb), p.getName()));
        }
        
        if (listComponents.size() == 0) throw new Pickle.PickleException('No component returned by apex class PickleAllScenarios');
        createScenarioList();
    }
    
    Boolean containsPickeScenarioCall(String lineOfCode, String component, Integer nb) {
        Integer idx1, idx2;
        lineOfCode = lineOfCode.trim();
        if (lineOfCode.startsWith('//')) return false;
        idx1 = lineOfCode.indexOfIgnoreCase('PickleScenario.run');
        if (idx1 < 0) return false;
        return true;
    }
    public List<Pickle.Scenario> getScenarios() { return allScenarios; }

    // Running the test    
    public PageReference runTest() {
        String testClassName = className;
        Id testClassId = [SELECT Id FROM ApexClass WHERE Name = :testClassName LIMIT 1].Id;
        ApexTestQueueItem[] queueItems = new ApexTestQueueItem[] { new ApexTestQueueItem(ApexClassId=testClassId) };
        insert queueItems;

        for (Pickle.Scenario sc : scenariosByTestClass.get(testClassName)) sc.init();
        for (Pickle.Alias a : aliases) a.init();

        // Get the job ID of the first queue item returned.
        ApexTestQueueItem item = 
           [SELECT ParentJobId FROM ApexTestQueueItem 
            WHERE Id=:queueItems[0].Id LIMIT 1];
        testJobId = item.parentjobid;    
        return null;
    }
 
    @RemoteAction
    global static String getTestStatus(String jobId) {
        ApexTestQueueItem[] items = [SELECT ApexClass.Name, Status, ExtendedStatus FROM ApexTestQueueItem WHERE ParentJobId=:jobId];
        for (ApexTestQueueItem item : items) {
            String extStatus = item.extendedstatus == null ? '' : item.extendedStatus;
//            if (!item.Status.startsWith('Completed')) return item.Status;
            return item.Status;
        }

        ApexTestResult[] results = 
           [SELECT Outcome, ApexClass.Name, MethodName, Message, StackTrace, ApexLogId
            FROM ApexTestResult 
            WHERE AsyncApexJobId=:jobId];
        for (ApexTestResult atr : results) {
            String result = 'Completed - ' + atr.Outcome + ' ' + atr.Message;
            if (atr.StackTrace != null) result += '<pre>' + atr.StackTrace + '</pre>';
            if (atr.ApexLogId != null) result += '<a href="/p/setup/layout/ApexDebugLogDetailEdit/d?apex_log_id=' + atr.ApexLogId + '" target="_blank">see log</a>';
            return result;
        }
        
        return '';
    } 
 
    public PageReference refresh() {
        createScenarioList();
        return null;
    }
    
    public PageReference checkTestStatus() {
        testClass2error = new Map<String, String>();
        for (String tc : getTestClasses()) testClass2error.put(tc, '');
        Set<Id> allApexLogIds = new Set<Id>();
        
        debug = '';
        Integer i, j, lineNb, scenarioNbErr, lineNbErr, aliasNbErr, aliasLineNbErr;
        String label, msg, errMsg, aliasErrMsg;
        Boolean pass = true;
        
        ApexTestResult[] results = 
           [SELECT Outcome, ApexClass.Name, MethodName, Message, StackTrace, ApexLogId
            FROM ApexTestResult 
            WHERE AsyncApexJobId=:testJobId ORDER BY Outcome DESC];
        for (ApexTestResult atr : results) {
            if (atr.message != null && atr.message.startsWith('Pickle.PickleException: ')) {
                msg = atr.message.substring(24);
                debug += msg + '<br/><br/>';
                try {
                    i = msg.indexOf(':');
                    errMsg = msg.substring(i + 1);
                    List<String> l = msg.substring(0, i).split(',');
                    if (l[0].startsWith('Scenario ')) {
                        j = l[0].indexOf(' Line ');
                        scenarioNbErr = Integer.valueOf(l[0].substring(9, j));
                        lineNbErr = Integer.valueOf(l[0].substring(j + 6));
                    }
                    if (l.size() > 1 && l[1].startsWith('Alias ')) {
                        errMsg = 'Error in alias';
                        aliasErrMsg = msg.substring(i + 1);
                        j = l[1].indexOf(' Line ');
                        aliasNbErr = Integer.valueOf(l[1].substring(6, j));
                        aliasLineNbErr = Integer.valueOf(l[1].substring(j + 6));
                    }
                }
                catch (Exception e) { }
                 
                Pickle.Scenario sc = allScenarios[scenarioNbErr - 1];
                if (sc != null) sc.displayError(lineNbErr, errMsg);
                
                if (aliasNbErr != null) {
                    Pickle.Alias a = aliases[aliasNbErr - 1];
                    if (a != null) a.displayError(aliasLineNbErr, aliasErrMsg);
                }
                
                pass = false;
            }
            else if (atr.outcome == 'Pass') {
                if (pass) {
                    for (Pickle.Scenario sc : scenariosByTestClass.get(atr.ApexClass.Name)) sc.testPasses();
                }
            }
            else {
                debug += atr.outcome + ' ' + atr.message + '<br/>' + atr.StackTrace.replace('\n', '<br/>') + '<br/><br/>';
                pass = false;
            }

            if (atr.ApexLogId != null && allApexLogIds.contains(atr.ApexLogId) == false) {
                debug = '(<a href="/p/setup/layout/ApexDebugLogDetailEdit/d?apex_log_id=' + atr.ApexLogId + '" target="_blank">View Log</a>) ' + debug;
                allApexLogIds.add(atr.ApexLogId);
            }
            testClass2error.put(atr.ApexClass.Name, debug);
        }    
        testJobId = '';
       
        return null;
    }
}