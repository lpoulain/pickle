global class PickleScenarios {
    public String component { get; set; }
    public List<SelectOption> listComponents { get; private set; }
    public String testJobId { get; private set; }
    public String debug { get; private set; }
    public List<Scenario> allScenarios { get; private set; }
    public Map<String, Map<String, List<Scenario>>> scenarios { get; private set; }
    Map<String, List<Scenario>> testclass2scenarios;
    
    public static Integer scenarioNb;

    public static List<Scenario> createScenarios() {
        return new Scenario[] {
            new Scenario('My Controller', 1, 'Creating SObject and testing them', 'PickleTest',
                         'Given the following Users:\r\n' +
                         '1|Laurent Poulain\r\n' +
                         '\r\n' +
                         'Given the following Account exist:\r\n' +
                         'Account Id|Account Name\r\n' +
                         '2         |Foo Inc.    \r\n' +
                         '\r\n' +
                         'Given the following Cases exist:\r\n' +
                         'Case Id|Account Id|Owner Id|Subject       |Case Origin|Escalated\r\n' +
                         '3      |2         |1       |This is a test|Web        |true     \r\n' +
                         '\r\n' +
                         'then the query [SELECT Case Id, Subject FROM Case WHERE "Escalated" = true] should return:\r\n' +
                         '3|This is a test'),
            new Scenario('My Controller', 2, 'Testing VF Page', 'PickleTest',
                         'Start Test\r\n' +
                         'Given I am on page "My VF Page" (PickleTest.MyVisualForceController)\r\n' +
                         'When I set "number" to "5"\r\n' +
                         'and I set "text" to "foo"\r\n' +
                         'and I set "select" to "23"\r\n' +
                         'and I click on "Compute"\r\n' +
                         'Then "result" should be >= "16"\r\n' +
                         'and the result should be 16\r\n' +
                         'Stop Test')
        };
    }
    
    public static void init() {
        if (scenarioss == null) scenarioss = createScenarios();
        scenarioMap = new Map<String, Scenario>();
        for (Scenario sc : scenarioss) {
            scenarioMap.put(sc.component + ':' + String.valueOf(sc.nb), sc);
        }
    }

    public class Scenario {
        public String component { get; private set; }
        public Integer nb { get; private set; }
        public String label { get; private set; }
        public String body { get; private set; }
        public String testClass { get; private set; }
        public String htmlBody { get; private set; }
        public String key { get; private set; }
        public Boolean testCovered { get; private set; }
        
        public Scenario(String c, Integer n, String l, String tc, String b) {
            component = c;
            nb = n;
            label = l;
            body = b;
            testClass = tc;
            htmlBody = body;
            if (scenarioNb == null) scenarioNb = 1;
            key = String.ValueOf(scenarioNb++);
        }
    }
 
    // STATIC METHODS
    static List<Scenario> scenarioss;
    static Map<String, Scenario> scenarioMap;
   
    public static Boolean run(String c, Integer n, Pickle p) {
        PickleScenarios.init();
        Scenario sc = scenarioMap.get(c + ':' + String.valueOf(n));
        return p.runScenario(sc.label, sc.body);
    }
    
    public static Scenario get(String c, Integer n) {
        PickleScenarios.init();
        return scenarioMap.get(c + ':' + String.valueOf(n));
    }

    public Scenario getByLabel(String l) {
        for (Scenario s : allScenarios) if (s.label == l) return s;
        return null;
    }
    
    // INSTANCE METHODS
    public PickleScenarios() {
        component = 'My Controller';
        testJobId = '';
        allScenarios = PickleScenarios.createScenarios();

        listComponents = new List<SelectOption>();
        component = '';
        scenarios = new Map<String, Map<String, List<Scenario>>>();
        Map<String, List<Scenario>> allTestClasses;
        List<Scenario> l;
        testClass2scenarios = new Map<String, List<Scenario>>();
        
        for (Scenario sc : allScenarios) {
            if (scenarios.containsKey(sc.component)) allTestClasses = scenarios.get(sc.component);
            else {
                allTestClasses = new Map<String, List<Scenario>>();
                scenarios.put(sc.component, allTestClasses);
                listComponents.add(new SelectOption(sc.component, sc.component));
            }
            
            if (allTestClasses.containsKey(sc.testClass)) l = allTestClasses.get(sc.testClass);
            else {
                l = new List<Scenario>();
                allTestClasses.put(sc.testClass, l);
            }
            l.add(sc);
            
            if (testClass2scenarios.containsKey(sc.testClass)) l = testClass2scenarios.get(sc.testClass);
            else {
                l = new List<Scenario>();
                testClass2scenarios.put(sc.testClass, l);
            }
            l.add(sc);
        }
        
        // Step 2: check that the scenarios are actually called in the test classes
        Boolean isCovered = false;
        Integer idx1, idx2, idx3;
        
        for (ApexClass ac : [SELECT Name, body FROM ApexClass WHERE name IN :(testClass2scenarios.keySet())]) {
        
            for (Scenario sc : testClass2scenarios.get(ac.Name)) {
                pattern myPattern = pattern.compile('\\(\'' + sc.component + '\',' + String.valueOf(sc.nb) + ',(.*)\\);'); 
                isCovered = false;
                idx1 = ac.body.indexOfIgnoreCase('PickleScenarios.run');
                while (idx1 >= 0 && isCovered == false) {
                    idx2 = ac.body.indexOf(';', idx1);
                    if (idx2 < 0) break;
                    idx3 = ac.body.lastIndexOfIgnoreCase('\n', idx1);
                    if (idx3 < 0) idx3 = 0; else idx3++;
//                    throw new Pickle.PickleException('[' + ac.body.substring(idx3, idx3 + 2) + ']');
                    if (ac.body.substring(idx3, idx3 + 2) != '//') {
                        matcher myMatcher = myPattern.matcher(ac.body.substring(idx1 + 19, idx2 + 1));
                        isCovered = myMatcher.matches();
                    }
                    idx1 = ac.body.indexOfIgnoreCase('PickleScenarios.run', idx2 + 1);
                }
                sc.testCovered = isCovered;
                if (!sc.testCovered) sc.htmlBody = '<span style="color:lightgrey">' + sc.body + '</span>';
            }
        }
        
        if (listComponents.size() >= 1) component = listComponents[0].getValue();
        else component = '';
    }
    Boolean containsPickeScenarioCall(String lineOfCode, String component, Integer nb) {
        Integer idx1, idx2;
        lineOfCode = lineOfCode.trim();
        if (lineOfCode.startsWith('//')) return false;
        idx1 = lineOfCode.indexOfIgnoreCase('PickleScenario.run');
        if (idx1 < 0) return false;
        return true;
    }
    public List<Scenario> getScenarios() { return PickleScenarios.scenarioss; }

    // Running the test    
    public PageReference runTest() {
        String testClassName = 'PickleTest';
        Id testClassId = [SELECT Id FROM ApexClass WHERE Name = :testClassName LIMIT 1].Id;
        ApexTestQueueItem[] queueItems = new ApexTestQueueItem[] { new ApexTestQueueItem(ApexClassId=testClassId) };
        insert queueItems;

        for (Scenario sc : testclass2scenarios.get(testClassName)) {
            sc.htmlbody = sc.body;
        }

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
            return item.Status + extStatus;
        }

        ApexTestResult[] results = 
           [SELECT Outcome, ApexClass.Name, MethodName, Message, StackTrace 
            FROM ApexTestResult 
            WHERE AsyncApexJobId=:jobId];
        for (ApexTestResult atr : results) {
            return atr.Outcome;
        }
        
        return '';
    } 
    
    public PageReference refresh() {
        debug = '';
        Integer i, j, lineNb, lineErr;
        String label, msg;
        
        ApexTestResult[] results = 
           [SELECT Outcome, ApexClass.Name, MethodName, Message, StackTrace 
            FROM ApexTestResult 
            WHERE AsyncApexJobId=:testJobId];
        for (ApexTestResult atr : results) {
            if (atr.message != null && atr.message.startsWith('Pickle.PickleException: ')) {
                i = atr.message.indexOf('"');
                j = atr.message.indexOf('"', i + 1);
                if (j < 0) label = atr.message.substring(i + 1);
                else label = atr.message.substring(i + 1, j);
                i = atr.message.indexOf('line ') + 5;
                j = atr.message.indexOf(':', i);
                try {
                    lineErr = Integer.valueOf(atr.message.substring(i, j));
                } catch (Exception e) { }
                msg = atr.message.substring(j + 1);
                 debug += '[' + String.valueOf(lineErr) + ': ' + label + ' - ' + msg +'] ';
                 
                 
                Scenario sc = getByLabel(label);
                String newBody = '';
                lineNb = 1;
                for (String oldLine : sc.body.split('\r\n')) {
                    if (lineNb < lineErr) newBody += '<span style="color:limegreen;">' + oldLine + '</span>\r\n';
                    else if (lineNb == lineErr) newBody += '<span style="color:red; font-weight:bold;">' + oldLine + ' [' + msg + ']</span>\r\n';
                    else newBody += '<span style="color:lightgrey;">' + oldLine + '</span>\r\n';
                    
                    lineNb++;
                }
                sc.htmlbody = newBody;
                
            }
            else if (atr.outcome == 'Pass') {
                for (Scenario sc : testclass2scenarios.get(atr.ApexClass.Name)) {
                    sc.htmlbody = '<span style="color:limegreen;">' + sc.body + '</span>';
                }
            }
            else debug = atr.outcome + ' ' + atr.message;
        }    
        testJobId = '';
       
        return null;
    }
}
