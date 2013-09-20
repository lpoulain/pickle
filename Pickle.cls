global abstract class Pickle {
    class PickleException extends Exception { }
    public void error(String msg) {
        throw new PickleException('Line ' + getLineNb() + ': ' + msg);
    }

    // Variables
    public Map<String, Object> variables;

    // SFDC Object ID management
    // used by StepDataLoader to manage temporary object IDs and map them to SFDC Ids
    Map<String, String> scenarioId2sfdcId;
    public void addSObjectId(String scenarioId, String sfdcId) {
        if (scenarioId2sfdcId.containsKey(scenarioId)) throw new PickleException('Line ' + getLineNb() + ': Temporary Id "' + scenarioId + '" has already been used');
        scenarioId2sfdcId.put(scenarioId, sfdcId);
    }
    public String getSObjectId(String scenarioId) {
        if (!scenarioId2sfdcId.containsKey(scenarioId)) throw new PickleException('Line ' + getLineNb() + ': Unknown temporary Id "' + scenarioId + '"');
        return scenarioId2sfdcId.get(scenarioId);
    }

    // Helper class    
    public PickleUtil util;
    
    public Pickle() {
        registerStepDefinitions(new StepDefinition[] { new StepSetPageVar(this), new StepSetPage(this), new StepSetValue(this), new StepClickButton(this), new StepCheckValue(this), new PickleStepUserMatch(this), new PickleStepDataLoader(this), new PickleStepSOQL(this) });
        scenarioId2sfdcId = new Map<String, String>();
        util = new PickleUtil(this);
        variables = new Map<String, Object>();
    }
    
    // These are the methods that can be defined when creating a new custom step
    public virtual void initializeController(String pageName) { throw new PickleException('initializeController() not defined'); }
    public virtual void setValue(String fieldName, String fieldValue) { throw new PickleException('setValue() not defined'); }
    public virtual Object getValue(String fieldName) { throw new PickleException('getValue() not defined'); }
    public virtual void executeAction(String actionName) { throw new PickleException('executeAction() not defined'); }

    // Standard steps that come with Pickle
    List<StepDefinition> stepDefinitions = new List<StepDefinition>();
    public void registerStepDefinition(StepDefinition st) { stepDefinitions.add(st); }
    public void registerStepDefinitions(List<StepDefinition> l) { stepDefinitions.addAll(l); }

    public abstract class StepDefinition {
        Pattern myPattern;
        Matcher myMatcher;
        public Pickle myPickle;
        public StepDefinition(Pickle p, String s) { myPickle = p; myPattern = Pattern.compile(s); }
        public Boolean matches(String s) { myMatcher = myPattern.matcher(s); return myMatcher.matches(); }
        public Boolean execute() {
            List<String> args = new List<String>();
            for (Integer nb=1; nb<=myMatcher.groupCount(); nb++) args.add(myMatcher.group(nb));
            return execute(args);
        }
        public abstract Boolean execute(List<String> args);
    }

    class StepSetPageVar extends StepDefinition {
        public StepSetPageVar (Pickle p) { super(p, 'I am on page "(.*)" \\((.*)\\)(| with parameters (.*))'); }
        public override Boolean execute(List<String> args) {
            Type t = Type.forName(args[1]);
            if (t == null) myPickle.error('Class "' + args[1] + '" unknown');
            
            if (args.size() > 2 && ApexPages.currentPage() != null) {
                Map<String, String> pageParams = ApexPages.currentPage().getParameters();
                List<String> paramInfo;
                for (String param : args[3].split(',')) {
                    paramInfo = param.split('=');
                    if (paramInfo.size() < 2) continue;
                    pageParams.put(paramInfo[0].trim(), paramInfo[1].trim());
                }
            }
            
            Object obj = t.newInstance();
            myPickle.variables.put(args[0], obj);
            return true;
        }
    }
    
    class StepSetPage extends StepDefinition {
        public StepSetPage (Pickle p) { super(p, 'I am on page "(.*)"'); }
        public override Boolean execute(List<String> args) {
            myPickle.initializeController(args[0]);
            return true;
        }
    }
    class StepSetValue extends StepDefinition {
        public StepSetValue (Pickle p) { super(p, 'I set "(.*)" to "(.*)"'); }
        public override Boolean execute(List<String> args) {
            myPickle.setValue(args[0], args[1]);
            return true;
        }
    }
    class StepClickButton extends StepDefinition {
        public StepClickButton (Pickle p) { super(p, 'I click on "(.*)"'); }
        public override Boolean execute(List<String> args) {
            myPickle.executeAction(args[0]);
            return true;
        }
    }
    class StepCheckValue extends StepDefinition {
        public StepCheckValue (Pickle p) { super(p, '"(.*)" should (contain|be equal to|be =|be <|be >|be <=|be >=) "(.*)"'); }
        public override Boolean execute(List<String> args) {
            String fieldName = args[0], theoreticalFieldValue = args[2], comparison = args[1];
            
            Object obj = myPickle.getValue(fieldName);
            Boolean succeeds = false;
            
            if (obj instanceOf String) {
                String fieldValue = (String)obj;
                if (comparison == 'contain') succeeds = fieldValue.contains(theoreticalFieldValue);
                else if (comparison == 'be =' || comparison == 'be equal to') succeeds = (fieldValue == theoreticalFieldValue);
                else throw new PickleException('Comparison operator "' + comparison + '" is incompatible with a string');
            }
            else if (obj instanceOf Integer || obj instanceOf Double) {
                Double fieldValue = (Double)obj;
                if (comparison == 'be =' || comparison == 'be equal to') succeeds = (fieldValue == Double.valueOf(theoreticalFieldValue));
                else if (comparison == 'be >') succeeds = (fieldValue > Double.valueOf(theoreticalFieldValue));
                else if (comparison == 'be >=') succeeds = (fieldValue >= Double.valueOf(theoreticalFieldValue));
                else if (comparison == 'be <') succeeds = (fieldValue < Double.valueOf(theoreticalFieldValue));
                else if (comparison == 'be <=') succeeds = (fieldValue <= Double.valueOf(theoreticalFieldValue));
                else throw new PickleException('Comparison operator "' + comparison + '" is incompatible with a number');
            }
            else throw new PickleException('Unknown field type');
            
            if (succeeds) return true;
            throw new PickleException('"' + fieldName + '" ' + comparison + ' "' + theoreticalFieldValue + '" is false (actual value: ' + String.valueOf(obj) + ')');
            return false;
        }
    }
    
    // Because some scenarios can have to parse multiple lines, we
    // need to have an iterator accessible through hasNextLine() and nextLine()
    global class lineIterator {
        List<String> lines;
        Integer lineNb;
        
        public lineIterator(String scenario) {
           lines = scenario.split('\r\n');
           lineNb = 0; 
        }
        
        global boolean hasNext() { return (lineNb < lines.size()); }
        global String next() { return lines[lineNb++]; }
        global Integer getLineNb() { return lineNb; }
    }
    public Boolean hasNextLine() { return lines.hasNext(); }
    public String nextLine() { return lines.next(); }
    public Integer getLineNb() { return lines.getlineNb(); }
    lineIterator lines;
 
    /////////////////////////////////////////////////   
    // RUN SCENARIO
    /////////////////////////////////////////////////   
    public Boolean runScenario(String scenario) {
        lines = new lineIterator(scenario);
        
        Boolean lineMatches;
        List<String> wordsToIgnore = new String[] { 'given', 'when', 'and', 'then' };
        
        List<String> test = new String[] { '234', '234', '234' };
        String line;
        while (hasNextLine()) {
            line = nextLine();
            for (String word : wordsToIgnore) {
                if (line.startsWithIgnoreCase(word)) {
                    line = line.substring(word.length());
                    break;
                }
            }
            line = line.trim();
            lineMatches = false;
            for (StepDefinition sd: stepDefinitions) {
                lineMatches = sd.matches(line);
                if (lineMatches) {
                    System.debug(getLineNb() + ' Step "' + line + '"');
                    if (sd.execute() == false) throw new PickleException('Step "' + line + '" failed');
                    break;
                }
            }
            if (lineMatches) continue;
            throw new PickleException('Unknown step: ' + line);
            return false;
        }
        return true;
    }
 
    /////////////////////////////////////////////////   
    // RANDOM TESTING SECTION
    /////////////////////////////////////////////////   
    List<String> availableActions;
    Map<String, List<Object>> availableFieldsMap;
    public void registerAction(String actionName) {
        if (availableActions == null) availableActions = new List<String>();
        availableActions.add(actionName);
    }
    public void registerField(String fieldName, List<Object> possibleValues) {
        if (availableFieldsMap == null) availableFieldsMap = new Map<String, List<Object>>();
        availableFieldsMap.put(fieldName, possibleValues);
    }

    public Boolean randomTesting(String pageName, Integer nbSteps) {
        if (availableActions == null) throw new PickleException('Must register at least one action using registerAction()');
        if (availableFieldsMap == null) throw new PickleException('Must register at least one field using registerField()');

        System.debug('Launching random testing for ' + pageName);
    
        List<String> availableFields = new List<String>();
        availableFields.addAll(availableFieldsMap.keyset());
    
        initializeController(pageName);
        Integer randomNumber;
        String fieldName, fieldValue;
        List<Object> possibleValues;
        
        for (Integer nb=0; nb<nbSteps; nb++) {
            randomNumber = Integer.valueOf(Math.random() * 2);
            
            // Try an action
            if (randomNumber == 0) {
                randomNumber = Integer.valueOf(Math.random() * availableActions.size());
                System.debug('Step #' + nb + ': Executing action "' + availableActions[randomNumber] + '"');
                executeAction(availableActions[randomNumber]);
            } else
            // Try setting a value
            {
                randomNumber = Integer.valueOf(Math.random() * availableFields.size());
                fieldName = availableFields[randomNumber];
                possibleValues = availableFieldsMap.get(fieldName);
                
                randomNumber = Integer.valueOf(Math.random() * 10);
                
                // We're going to try one of the possible values
                if (randomNumber <= 8) {
                    randomNumber = Integer.valueOf(Math.random() * possibleValues.size());
                    if (possibleValues instanceOf List<SelectOption>) fieldValue = ((SelectOption)(possibleValues[randomNumber])).getValue();
                    else fieldValue = String.valueOf(possibleValues[randomNumber]);
                }
                // We're going to set an empty field
                else if (randomNumber == 9) fieldValue = '';
                // We're going to try another value
                else {
                    if (possibleValues instanceOf List<SelectOption> || possibleValues instanceOf List<String>) {
                        fieldValue = 'sdfsdfsdf';
                    }
                    else if (possibleValues instanceOf List<Integer> || possibleValues instanceOf List<Double>) {
                        fieldValue = String.valueOf(Math.random() * 1000000.0 - 500000.0);
                    }
                }
                System.debug('Step #' + nb + ': Setting field "' + fieldName + '" to "' + fieldValue + '"');
                setValue(fieldName, fieldValue);
            }
        }
        return true;
    }
}
