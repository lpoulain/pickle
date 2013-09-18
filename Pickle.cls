global abstract class Pickle {
    Map<String, String> stmtId2sfdcId;
    public void addSObjectId(String stmtId, String sfdcId) {
        if (stmtId2sfdcId == null) stmtId2sfdcId = new Map<String, String>();
        if (stmtId2sfdcId.containsKey(stmtId)) throw new PickleException('Id "' + stmtId + '" has already been used');
        stmtId2sfdcId.put(stmtId, sfdcId);
    }
    public String getSObjectId(String stmtId) { if (stmtId2sfdcId == null) stmtId2sfdcId = new Map<String, String>(); return stmtId2sfdcId.get(stmtId); }
    Map<String, String> label2name;
    public String objectLabel2name(String l) {
        if (label2name != null) return label2name.get(l);
        
        label2name = new Map<String, String>();
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        Schema.DescribeSObjectResult sor;

        for (String s : gd.keySet()) {
            sor = gd.get(s).getDescribe();
            label2name.put(sor.getLabel(), s);
            label2name.put(sor.getLabelPlural(), s);
        }
        return label2name.get(l);
    }
    public class PickleException extends Exception { }
    public virtual void initializeController(String pageName) { throw new PickleException('initializeController() not defined'); }
    public virtual void setValue(String fieldName, String fieldValue) { throw new PickleException('setValue() not defined'); }
    public virtual Object getValue(String fieldName) { throw new PickleException('getValue() not defined'); }
    public virtual void executeAction(String actionName) { throw new PickleException('executeAction() not defined'); }

    List<StatementType> statementTypes = new List<StatementType>();
    public void registerStatementType(StatementType stt) { statementTypes.add(stt); }
    public void registerStatementTypes(List<StatementType> l) { statementTypes.addAll(l); }

    public abstract class StatementType {
        Pattern myPattern;
        Matcher myMatcher;
        public Pickle myPickle;
        public StatementType(Pickle p, String s) { myPickle = p; myPattern = Pattern.compile(s); }
        public Boolean matches(String s) { myMatcher = myPattern.matcher(s); return myMatcher.matches(); }
        public Boolean execute() {
            List<String> args = new List<String>();
            for (Integer nb=1; nb<=myMatcher.groupCount(); nb++) args.add(myMatcher.group(nb));
            return execute(args);
        }
        public abstract Boolean execute(List<String> args);
    }
    
    class StatementSetPage extends StatementType {
        public StatementSetPage (Pickle p) { super(p, 'I am on page "(.*)"'); }
        public override Boolean execute(List<String> args) {
            System.Debug('I AM ON PAGE statement matched ' + args);
            myPickle.initializeController(args[0]);
            return true;
        }
    }
    class StatementSetValue extends StatementType {
        public StatementSetValue (Pickle p) { super(p, 'I set "(.*)" to "(.*)"'); }
        public override Boolean execute(List<String> args) {
            System.Debug('WHEN I SET statement matched ' + args);
            myPickle.setValue(args[0], args[1]);
            return true;
        }
    }
    class StatementClickButton extends StatementType {
        public StatementClickButton (Pickle p) { super(p, 'I click on "(.*)"'); }
        public override Boolean execute(List<String> args) {
            System.Debug('AND I CLICK ON statement matched');
            myPickle.executeAction(args[0]);
            return true;
        }
    }
    class StatementCheckValue extends StatementType {
        public StatementCheckValue (Pickle p) { super(p, '"(.*)" should (contain|be equal to|be =|be <|be >|be <=|be >=) "(.*)"'); }
        public override Boolean execute(List<String> args) {
            System.Debug('THEN X SHOULD CONTAIN statement matched');
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
    
    global class statementIterator implements Iterator<String> {
        List<String> statements;
        Integer statementNb;
        
        public statementIterator(String scenario) {
           statements = scenario.split('\r\n');
           statementNb = 0; 
        }
        
        global boolean hasNext() { return (statementNb < statements.size()); }
        global String next() { return statements[statementNb++]; }
    }
    public Boolean hasNextStatement() { return statements.hasNext(); }
    public String nextStatement() { return statements.next(); }
    Iterator<String> statements;
 
    public Boolean runScenario(String scenario) {
        statements = new statementIterator(scenario);
        
        Boolean lineMatches;
        registerStatementTypes(new StatementType[] { new StatementSetPage(this), new StatementSetValue(this), new StatementClickButton(this), new StatementCheckValue(this), new PickleStatementDataLoader(this) });
        List<String> wordsToIgnore = new String[] { 'given', 'when', 'and', 'then' };
        
        String statement;
        
        List<String> test = new String[] { '234', '234', '234' };
        for (String line = nextStatement(); hasNextStatement(); line = nextStatement()) {
            statement = line;
            for (String word : wordsToIgnore) {
                if (line.startsWithIgnoreCase(word)) {
                    statement = line.substring(word.length());
                    break;
                }
            }
            statement = statement.trim();
            lineMatches = false;
            for (StatementType stt: statementTypes) {
                lineMatches = stt.matches(statement);
                if (lineMatches) {
                    if (stt.execute() == false) return false;
                    break;
                }
            }
            if (lineMatches) continue;
            throw new PickleException('Unknown statement: ' + statement);
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
