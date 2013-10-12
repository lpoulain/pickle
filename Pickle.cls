global abstract class Pickle {
    ///////////////////////////////////////////////////
    // METHODS THAN CAN BE OVERRIDEN WHEN CREATING A NEW CUSTOM PICKLE
    ///////////////////////////////////////////////////
    
    // These are the methods that can be defined when creating a new custom step
    public virtual void initializeController(String pageName) { error('initializeController() not defined'); }
    public virtual void setValue(String fieldName, String fieldValue) { error('setValue() not defined'); }
    public virtual Object getValue(String fieldName) { error('getValue() not defined'); return null; }
    public virtual void executeAction(String actionName) { error('executeAction() not defined'); }
    public virtual String getName() { error('getName() not defined'); return null; }
    public virtual List<Scenario> getScenarios() { return new List<Scenario>(); }
    public virtual List<Alias> getAliases() { return new List<Alias>(); }

    ///////////////////////////////////////////////////////
    // INTERNAL STRUCTURES
    //////////////////////////////////////////////////////
    public String scenarioLabel = '';
    Integer scenarioNb;
    
    public class PickleException extends Exception { }
    public void error(String msg) {
        String finalMsg;
        throw new PickleException(getPosition() + ': ' + msg);
    }

    // Variables
    final Map<String, Object> variables;
    public Object getVariable(String name) {
        if (!variables.containsKey(name)) error('Variable "' + name + '" does not exist');
        return variables.get(name);
    }
    public Set<String> allVariables() { return variables.keySet(); }

    // SFDC Object ID management
    // used by StepDataLoader to manage temporary object IDs and map them to SFDC Ids
    Map<String, String> scenarioId2sfdcId;
    Map<String, String> sfdcId2scenarioId;
    public void addSObjectId(String scenarioId, String sfdcId) {
        if (scenarioId2sfdcId.containsKey(scenarioId)) error('Temporary Id "' + scenarioId + '" has already been used');
        scenarioId2sfdcId.put(scenarioId, sfdcId);
        sfdcId2scenarioId.put(sfdcId, scenarioId);
    }
    public String getSObjectId(String scenarioId) {
        if (!scenarioId2sfdcId.containsKey(scenarioId)) error('Unknown temporary Id "' + scenarioId + '"');
        return scenarioId2sfdcId.get(scenarioId);
    }
    public String getScenarioId(String sfdcId) {
        return sfdcId2scenarioId.get(sfdcId);
    }

    // Helper class    
//    public PickleUtil util;
    
    public Pickle() {
        registerStepDefinitions(new StepDefinition[] { new StepStartTest(this), new StepStopTest(this), new StepSetPageVar(this), new StepSetPage(this), new StepSetValue(this), new StepClickButton(this), new StepCheckValue(this), new StepUserMatch(this), new StepDataLoader(this), new StepSOQL(this), new StepCheckTable(this) });
        scenarioId2sfdcId = new Map<String, String>();
        sfdcId2scenarioId = new Map<String, String>();
//        util = new PickleUtil(this);
        SObjectMap = new Map<String, SObjectInfo>();
        variables = new Map<String, Object>();
        aliases = getAliases();
        for (Integer i=0; i<aliases.size(); i++) aliases[i].nb = i;
    }
    
    ////////////////////////////////////////////
    // Helper methods
    ////////////////////////////////////////////
    
    // Returns the SObject name given its label (singluar or plural)    
    Map<String, String> sobjectLabel2name;
    public String getSObjectName(String label) {
        if (sobjectLabel2name != null) return sobjectLabel2name.get(label);
        
        sobjectLabel2name = new Map<String, String>();
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        Schema.DescribeSObjectResult sor;

        for (String s : gd.keySet()) {
            sor = gd.get(s).getDescribe();
            sobjectLabel2name.put(sor.getLabel(), s);
            sobjectLabel2name.put(sor.getLabelPlural(), s);
        }
        return sobjectLabel2name.get(label);
    }
    
    // SObject metadata field information
    Map<String, SObjectInfo> SObjectMap;
    public SObjectInfo getSObjectInfo(String objectName) {
        if (!SObjectMap.containsKey(objectName)) {
            SObjectInfo soi = new SObjectInfo(objectName, this);
            SObjectMap.put(objectName, soi);
            return soi;
        }
        return SObjectMap.get(objectName);
    }
    
    public class SObjectInfo {
        String objectName;
        Pickle myPickle;
        Map<String, Schema.SObjectField> objectFields;
        Map<String, String> fieldLabel2name;
        Map<String, DisplayType> fieldName2type;
        Schema.SObjectType objectType;
        
        public SObjectInfo(String name, Pickle p) {
            DisplayType dt;
            objectName = name;
            myPickle = p;
        
            objectType = Schema.getGlobalDescribe().get(objectName);
            Schema.DescribeSObjectResult F = objectType.getDescribe();
            objectFields = F.fields.getMap();
            fieldLabel2name = new Map<String, String>();
            fieldName2type = new Map<String, DisplayType>();
            
            for (SObjectField sof : objectFields.values()) {
                Schema.DescribeFieldResult dfr = sof.getDescribe();
                fieldLabel2name.put(dfr.getLabel().toLowerCase(), dfr.getName());
                fieldName2type.put(dfr.getName().toLowerCase(), dfr.getType());
            }
        }

        public Set<String> getFieldLabels() { return fieldLabel2name.keySet(); }

        public SObject instanciate() { return objectType.newSObject(); }
        
        public String getFieldName(String fieldLabel) {
            if (!fieldLabel2name.containsKey(fieldLabel)) myPickle.error('Unknown field "' + fieldLabel + '" for object "' + objectName + '"');
            return fieldLabel2name.get(fieldLabel);
        }
        
        public DisplayType getFieldType(String fieldName) {
            if (!fieldname2type.containsKey(fieldName)) myPickle.error('Unknown field "' + fieldName + '" for object "' + objectName + '"');
            return fieldname2type.get(fieldName);
        }
        
        public List<FieldConversion> getConversionList(List<String> fieldNames) {
            List<FieldConversion> res = new List<FieldConversion>();
            DisplayType dt;
            
            for (String fieldName : fieldNames) {
                dt = fieldName2type.get(fieldName.toLowerCase());
                if (dt == DisplayType.Reference || dt == DisplayType.Id) res.add(new FieldConversionId(myPickle));
                else if (dt == DisplayType.String || dt == DisplayType.picklist || dt == DisplayType.textarea) res.add(new FieldConversionString());
                else if (dt == DisplayType.Currency || dt == DisplayType.Double || dt == DisplayType.Percent || dt == DisplayType.Integer) res.add(new FieldConversionNumber());
                else if (dt == DisplayType.Boolean) res.add(new FieldConversionBoolean());
                else if (dt == DisplayType.Date) res.add(new FieldConversionDate());
                else if (dt == DisplayType.Datetime) res.add(new FieldConversionDatetime());            
                else myPickle.error('Unsupported type "' + String.valueOf(dt) + '" for field "' + fieldName + '" for object "' + objectName + '"');
            }
            
            return res;
        }
    }

    public String dumpListSObject(List<SObject> objs, List<String> fieldNames) {
        String result = '', line, cell, theId;
        for (SObject obj : objs) {
            line = '';
            for (String fieldName : fieldNames) {
                cell = String.valueOf(obj.get(fieldName));
                theId = getScenarioId(cell);
                if (theId != null) line += '|' + theId;
                else line += '|' + cell;
            }
            if (line != '') line = line.substring(1);
            result += '   ' + line + '\r\n';
        }
        return result;
    }

    public String dumpStringTable(List<List<String>> stringTable) {
        String result = '', line;
        for (List<String> row : stringTable) {
            line = '';
            for (String cell : row) line += '|' + cell;
            if (line != '') line = line.substring(1);
            result += '   ' + line + '\r\n';
        }
        return result;
    }
 
    public abstract class FieldConversion {
        public abstract Object convert(String s);
    }
    class FieldConversionId extends FieldConversion {
        Pickle myPickle;
        FieldConversionId(Pickle p) { myPickle = p; }
        public override Object convert(String s) { return myPickle.getSObjectId(s); }
    }
    class FieldConversionString extends FieldConversion {
        public override Object convert(String s) { return s; }
    }
    class FieldConversionNumber extends FieldConversion {
        public override Object convert(String s) { return Double.valueOf(s); }
    }
    class FieldConversionBoolean extends FieldConversion {
        public override Object convert(String s) { return (s == 'true'); }
    }
    class FieldConversionDate extends FieldConversion {
        public override Object convert(String s) { return Date.valueOf(s); }
    }
    class FieldConversionDatetime extends FieldConversion {
        public override Object convert(String s) { return Datetime.valueOf(s); }
    }

    ///////////////////////////////////////////////
    // STANDARD STEPS THAT COME WITH PICKLE
    ////////////////////////////////////////////////
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
            
            if (args.size() >= 4 && args[2] != null && args[3] != null && ApexPages.currentPage() != null) {
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

    class StepStartTest extends StepDefinition {
        public StepStartTest (Pickle p) { super(p, 'Start Test'); }
        public override Boolean execute(List<String> args) { Test.startTest(); return true; }
    }
    class StepStopTest extends StepDefinition {
        public StepStopTest (Pickle p) { super(p, 'Stop Test'); }
        public override Boolean execute(List<String> args) { Test.stopTest(); return true; }
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
        public StepCheckValue (Pickle p) { super(p, '"(.*)" should (contain|be equal to|be different than|be =|be <>|be <|be >|be <=|be >=) "(.*)"'); }
        public override Boolean execute(List<String> args) {
            String fieldName = args[0], theoreticalFieldValue = args[2], comparison = args[1];
            
            Object obj = myPickle.getValue(fieldName);
            Boolean succeeds = false;
            
            if (obj instanceOf String) {
                String fieldValue = (String)obj;
                if (comparison == 'contain') succeeds = fieldValue.contains(theoreticalFieldValue);
                else if (comparison == 'be =' || comparison == 'be equal to') succeeds = (fieldValue == theoreticalFieldValue);
                else if (comparison == 'be <>' || comparison == 'be different than') succeeds = (fieldValue != theoreticalFieldValue);
                else myPickle.error('Comparison operator "' + comparison + '" is incompatible with a string');
            }
            else if (obj instanceOf Integer || obj instanceOf Double) {
                Double fieldValue = (Double)obj;
                if (comparison == 'be =' || comparison == 'be equal to') succeeds = (fieldValue == Double.valueOf(theoreticalFieldValue));
                else if (comparison == 'be >') succeeds = (fieldValue > Double.valueOf(theoreticalFieldValue));
                else if (comparison == 'be >=') succeeds = (fieldValue >= Double.valueOf(theoreticalFieldValue));
                else if (comparison == 'be <') succeeds = (fieldValue < Double.valueOf(theoreticalFieldValue));
                else if (comparison == 'be <>' || comparison == 'be different than') succeeds = (fieldValue <> Double.valueOf(theoreticalFieldValue));
                else if (comparison == 'be <=') succeeds = (fieldValue <= Double.valueOf(theoreticalFieldValue));
                else myPickle.error('Comparison operator "' + comparison + '" is incompatible with a number');
            }
            else myPickle.error('Unknown field type');
            
            if (succeeds) return true;
            myPickle.error('"' + fieldName + '" ' + comparison + ' "' + theoreticalFieldValue + '" is false (actual value: ' + String.valueOf(obj) + ')');
            return false;
        }
    }
    class StepCheckTable extends StepDefinition {
        public StepCheckTable (Pickle p) { super(p, '"(.*)" should be:'); }
        public override Boolean execute(List<String> args) {
            Object obj = myPickle.getValue(args[0]);
            String tmpString, line;

            if (obj == null) myPickle.error('"' + args[0] + '" is null');
            if (!(obj instanceOf List<List<String>>) && !(obj instanceOf List<SObject>)) myPickle.error('"' + args[0] + '" should be a list of either SObjects or List<String>');
        
            // Check the string table
            if (obj instanceOf List<List<String>>) {
                List<List<String>> stringTable = (List<List<String>>)obj;
                List<String> refRow;
                Integer rowNb = 1;

                for (List<String> row : stringTable) {
                    if (!myPickle.hasNextLine()) myPickle.error('\r\n\r\nString table "' + args[0] + '" has more rows than what is expected. Actual table returned:\r\n' + myPickle.dumpStringTable(stringTable) + '\r\n');
                    line = myPickle.nextLine();
                    if (line == '') myPickle.error('String table "' + args[0] + '" has more rows than what is expected');
                    refRow = line.split('\\|');
                    
                    if (refRow.size() != row.size()) myPickle.error('\r\n\r\nString table "' + args[0] + '", row #' + String.valueOf(rowNb) + ' has an incorrect number of cells (' + String.valueOf(row.size()) + ' vs. ' + String.valueOf(refRow.size()) + '). Actual table returned:\r\n' + myPickle.dumpStringTable(stringTable) + '\r\n\r\n');
                    for (Integer colNb=0; colNb<row.size(); colNb++) {
                        if (refRow[colNb].trim() != row[colNb]) myPickle.error('\r\n\r\nString table "' + args[0] + '", row #' + String.valueOf(rowNb) + ', col #' + String.valueOf(colNb + 1) + ' has an incorrect value in a cell (' + row[colNb] + ' vs. ' + refRow[colNb] + '). Actual table returned:\r\n' + myPickle.dumpStringTable(stringTable));
                    }
                    rowNb++;
                }
                if (!myPickle.hasNextLine()) return true;
                line = myPickle.nextLine();
                if (line != '') myPickle.error('\r\n\r\nString table "' + args[0] + '" has less rows than what is expected');

            // Check the value of a List<SObject>                
            } else {
                if (!myPickle.hasNextLine()) myPickle.error('empty table');
                line = myPickle.nextLine();
                if (line == '') myPickle.error('empty table');
                        
                List<SObject> sobjs = ((List<SObject>)obj);
                if (sobjs.size() == 0) {
                    if (!myPickle.hasNextLine()) return true;
                    line = myPickle.nextLine();
                    if (!myPickle.hasNextLine()) return true;
                    line = myPickle.nextLine();
                    if (line != '') myPickle.error('Field "' + args[0] + '" is an empty list');
                }

                SObjectType t = sobjs[0].getSObjectType();
                Schema.DescribeSObjectResult sor = t.getDescribe();
                SObjectInfo soi = myPickle.getSObjectInfo(sor.getLabel());
                
                List<String> fieldNames = new List<String>();
                List<String> fieldLabels = line.split('\\|');
                List<String> recordFieldValues;
                Object fieldValue;

                for (String label : fieldLabels) {
                    tmpString = soi.getFieldName(label.toLowercase().trim());
                    fieldNames.add(tmpString);
                }
                List<FieldConversion> fieldConversion = soi.getConversionList(fieldNames);
                
                for (SObject sobj : sobjs) {
                    if (!myPickle.hasNextLine()) myPickle.error('\r\n\r\nVariable "' + args[0] + '" returns more rows than what is expected. Actual list returned:\r\n' + myPickle.dumpListSObject(sobjs, fieldNames));
                    line = myPickle.nextLine();
                    if (line == '') myPickle.error('\r\n\r\nVariable "' + args[0] + '" returns more rows than what is expected. Actual list returned:\r\n' + myPickle.dumpListSObject(sobjs, fieldNames));
                
                    recordFieldValues = line.split('\\|');
                    System.debug(fieldConversion);
                    for (Integer i=0; i<fieldNames.size(); i++) {
                        fieldValue = fieldConversion[i].convert(recordFieldValues[i].trim());
                        if (fieldValue != sobj.get(fieldNames[i])) myPickle.error('\r\n\r\nField "' + fieldLabels[i] + '"\'s value "' + sobj.get(fieldNames[i]) + '" different than the expected "' + fieldValue + '". Actual list returned:\r\n' + myPickle.dumpListSObject(sobjs, fieldNames));
                    }
                }
                if (!myPickle.hasNextLine()) return true;
                line = myPickle.nextLine();
                if (line != '') myPickle.error('Variable "' + args[0] + '" returns less rows than what is expected');
            }

            return true;
        }
    }

    class StepSOQL extends Pickle.StepDefinition {
        public StepSOQL(Pickle p) { super(p, 'the query \\[SELECT (.*) FROM (.*) WHERE (.*)\\] should return:'); }
        public override Boolean execute(List<String> args) {
            System.debug('Step SOQL (SELECT: [' + args[0] + '], FROM: [' + args[1] + '], WHERE: [' + args[2] + '])');
            
            String objectName = myPickle.getSObjectName(args[1]);
            if (objectName == null) myPickle.error('Object "' + args[0] + '" unknown');
            
            SObjectInfo soi = myPickle.getSObjectInfo(objectName);
    
            String soqlSelect = '';
            String soqlFrom = objectName;
            String soqlWhere = args[2];
            String tmpString, fieldLabel, line;
    
            System.debug(soi.getFieldLabels());
                    
            Integer idx = 0, idx2;
            tmpString = '';
            while (idx >= 0) {
                idx2 = soqlWhere.indexOf('"', idx);
                if (idx2 < 0) {
                    tmpString += soqlWhere.substring(idx);
                    break;
                }
                idx = idx2;
                idx2 = soqlWhere.indexOf('"', idx + 1);
                if (idx2 < 0) {
                    tmpString += soqlWhere.substring(idx);
                    break;
                }
                fieldLabel = soqlWhere.substring(idx + 1, idx2);
                tmpString += soi.getFieldName(fieldLabel.toLowerCase());
                idx = idx2 + 1;
            }
            soqlWhere = tmpString;
    
            List<String> fieldNames = new List<String>();
            List<String> fieldLabels = args[0].split(',');
            List<String> recordFieldValues;
            Object fieldValue;
    
            for (String label : fieldLabels) {
                tmpString = soi.getFieldName(label.toLowercase().trim());
                soqlSelect += ', ' + tmpString;
                fieldNames.add(tmpString);
            }
            List<FieldConversion> fieldConversion = soi.getConversionList(fieldNames);
            soqlSelect = soqlSelect.substring(1);
            
            System.debug('SELECT ' + soqlSelect + ' FROM ' + soqlFrom + ' WHERE ' + soqlWhere);
            
            List<SObject> sobjs = Database.query('SELECT ' + soqlSelect + ' FROM ' + soqlFrom + ' WHERE ' + soqlWhere);
            for (SObject obj : sobjs) {
                if (!myPickle.hasNextLine()) myPickle.error('The SOQL query returns more rows than what is expected. Actual result returned:\r\n' + myPickle.dumpListSObject(sobjs, fieldNames));
                line = myPickle.nextLine();
                if (line == '') myPickle.error('The SOQL query returns more rows than what is expected. Actual result returned:\r\n' + myPickle.dumpListSObject(sobjs, fieldNames));
            
                recordFieldValues = line.split('\\|');
                System.debug(fieldConversion);
                for (Integer i=0; i<fieldNames.size(); i++) {
                    fieldValue = fieldConversion[i].convert(recordFieldValues[i].trim());
                    if (fieldValue != obj.get(fieldNames[i])) myPickle.error('Field "' + fieldLabels[i] + '" value "' + obj.get(fieldNames[i]) + '" different than the expected "' + fieldValue + '". Actual result returned:\r\n' + myPickle.dumpListSObject(sobjs, fieldNames));
                }
            }
            
            if (!myPickle.hasNextLine()) return true;
            line = myPickle.nextLine();
            if (line != '') myPickle.error('The SOQL query returns less rows than what is expected');
            
            return true;
        }
    }
    
    class StepDataLoader extends Pickle.StepDefinition {
        public StepDataLoader(Pickle p) { super(p, 'the following (.*) exist:'); }
        public override Boolean execute(List<String> args) {
            String line;
            String objectName = myPickle.getSObjectName(args[0]);
            if (objectName == null) myPickle.error('Object "' + args[0] + '" unknown');
    
            if (!myPickle.hasNextLine()) return true;
            line = myPickle.nextLine();
            if (line == '') return true;
            Integer i;
            
            SObjectInfo soi = myPickle.getSObjectInfo(objectName);
    
            List<String> fieldNames = new List<String>();
            String tmpString;
    
            for (String s : line.split('\\|')) {
                tmpString = soi.getFieldName(s.trim().toLowerCase());
                fieldNames.add(tmpString);
            }
    
            sObject obj;
            String fieldName;
            List<String> recordFieldValues;
            List<FieldConversion> recordFieldConversion = soi.getConversionList(fieldNames);
            List<String> tempIds = new List<String>();
            List<SObject> objects = new List<SObject>();
            
            while (myPickle.hasNextLine()) {
                line = myPickle.nextLine();
                if (line == '') break;
    
                obj = soi.instanciate();
                objects.add(obj);
                recordFieldValues = line.split('\\|');
                for (i=0; i<fieldNames.size(); i++) {
                    if (i >= recordFieldValues.size()) myPickle.error('Not enough columns for object "' + args[0] + '" at line ' + myPickle.getLineNb() + ' (' + line + ')');
                    if (soi.getFieldType(fieldNames[i].toLowerCase()) == DisplayType.ID) {
                        tempIds.add(recordFieldValues[i].trim());
                    } else {
    //                    System.debug(recordFieldNames[i].toLowerCase());
                        obj.put(fieldNames[i].toLowerCase(), recordFieldConversion[i].convert(recordFieldValues[i].trim()));
                    }
                }
    
    //            System.debug('######## ' + objects);
    //            System.debug(tempIds);
            }
            insert objects;
            for (i=0; i<objects.size(); i++) myPickle.addSObjectId(tempIds[i], objects[i].Id);
            return true;
        }
    }    

    public class StepUserMatch extends Pickle.StepDefinition {
        public StepUserMatch(Pickle p) { super(p, 'the following User(s|):'); }
        public override Boolean execute(List<String> args) {
            String line;
    
            List<String> recordFieldValues;
            Map<String, String> username2id = new Map<String, String>();
            Set<String> usernames = new Set<String>();
    
            while (myPickle.hasNextLine()) {
                line = myPickle.nextLine();
                if (line == '') break;
                
                recordFieldValues = line.split('\\|');
                if (recordFieldValues.size() != 2) myPickle.error('The User table should contain only 2 columns (temporary ID and name)');
                
                usernames.add(recordFieldValues[1].trim());
                username2id.put(recordFieldValues[1].trim(), recordFieldValues[0].trim());
            }
    
            for (User u : [SELECT Id, Name FROM User WHERE Name IN :usernames]) {
                myPickle.addSObjectId(username2id.get(u.Name), u.Id);
                usernames.remove(u.Name);
            }
    
            if (usernames.size() != 0) {
                List<String> tmpList = new List<String>();
                tmpList.addAll(usernames);
                myPickle.error('The following Users were not found: ' + String.join(tmpList, ', '));
            }
    
            return true;
        }
    }        

    /////////////////////////////////////////////////////////////    
    // Because some scenarios can have to parse multiple lines, we
    // need to have an iterator accessible through hasNextLine() and nextLine()
    /////////////////////////////////////////////////////////////
    global class lineIterator {
        List<String> lines;
        Integer lineNb;
        List<Alias> aliases;
        List<String> currentAliasLines;
        Integer aliasLineNb;
        Integer aliasNb;
        
        public lineIterator(String scenario, List<Alias> a) {
           lines = scenario.split('\r\n');
           aliases = a;
           aliasNb = null;
           currentAliasLines = new List<String>();
           lineNb = 0;
        }
        
        global boolean hasNext() { return (currentAliasLines.size() > 0 || lineNb < lines.size()); }
        global String next() {
            List<String> wordsToIgnore = new String[] { 'given', 'when', 'and', 'then' };
            String line;
            if (currentAliasLines.size() > 0) {
                line = currentAliasLines[0];
                currentAliasLines.remove(0);
                if (currentAliasLines.size() == 0) aliasNb = null;
                aliasLineNb++;
                return line;
            }
            line = lines[lineNb++];
            for (String word : wordsToIgnore) {
                if (line.startsWithIgnoreCase(word)) {
                    line = line.substring(word.length());
                    break;
                }
            }
            line = line.trim();
             for (Alias a : aliases) {
                if (line.trim() == a.pattern.trim()) {
                    currentAliasLines = a.expandsTo.split('\r\n');
                    if (a.expandsTo.endsWith('\r\n')) currentAliasLines.add('');
                    aliasLineNb = 0;
                    aliasNb = a.nb;
                    return next();
                }
            }
            return line;
        }
        
        global Integer getLineNb() { return lineNb; }
        global Integer getAliasNb() { return aliasNb; }
        global Integer getAliasLineNb() { return aliasLineNb; }
    }
    public Boolean hasNextLine() { return lines.hasNext(); }
    public String nextLine() { return lines.next(); }
    public Integer getLineNb() { return lines.getlineNb(); }
    public Integer getAliasLineNb() { return lines.getAliasLineNb(); }
    public Integer getAliasNb() { return lines.getAliasNb(); }
    public String getPosition() {
        String pos = '';
        if (scenarioNb != null) pos = 'Scenario ' + String.valueOf(scenarioNb + 1) + ' ';
        pos += 'Line ' + getLineNb();
        if (lines.getAliasNb() != null) pos += ',Alias ' + String.valueOf(lines.getAliasNb() + 1) + ' Line ' + String.valueOf(lines.getAliasLineNb());
        return pos;
    }
    lineIterator lines;
 
    /////////////////////////////////////////////////   
    // RUN SCENARIO
    /////////////////////////////////////////////////   
    List<Alias> aliases;

    public Boolean runScenario(Integer nb) {
        List<Scenario> scenarios = getScenarios();
        if (nb < 1) throw new PickleException('Scenario number must be at least 1');
        if (nb > scenarios.size()) throw new PickleException('Scenario ' + String.valueOf(nb) + ' not found - only ' + String.valueOf(scenarios.size()) + ' scenarios');
        scenarioNb = nb - 1;
        return runScenarioHelper(scenarios[nb - 1].label, scenarios[nb - 1].body);
    }
    
    public Boolean runScenario(String name, String scenario) {
        scenarioNb = null;
        return runScenarioHelper(name, scenario);
    }
        
    public Boolean runScenarioHelper(String name, String scenario) {
        scenarioLabel = name;
        lines = new lineIterator(scenario, aliases);
        
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
                    if (sd.execute() == false) error('Step "' + line + '" failed');
                    break;
                }
            }
            if (lineMatches) continue;
            error('Unknown step: ' + line);
            return false;
        }

        if (ApexPages.currentPage() != null) ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.FATAL, 'my error msg'));
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

    /////////////////////////////////////////////////   
    // PICKLE SCENARIO REPOSITORY
    /////////////////////////////////////////////////   
    public class Scenario {
        public String label { get; private set; }
        public String body { get; private set; }
        public String testClass { get; private set; }
        public String htmlBody { get; private set; }
        public String key { get; private set; }
        public Boolean testCovered { get; private set; }
        public Integer nb { get; set; }
        
        public void init() { htmlBody = body; }
        public void isCoveredByTest(Boolean isCovered) {
            testCovered = isCovered;
            if (!testCovered) htmlBody = '<span style="color:lightgrey">' + body + '</span>';
        }
        public void testPasses() { htmlBody = '<span style="color:limegreen">' + body + '</span>'; }
        public void displayError(Integer lineNbErr, String errMsg) {
            if (body == null) return;
            htmlBody = '';
            Integer lineNb = 1;
            for (String oldLine : body.split('\r\n')) {
                if (lineNb < lineNbErr) htmlBody += '<span style="color:limegreen;">' + oldLine + '</span>\r\n';
                else if (lineNb == lineNbErr) htmlBody += '<span style="color:red; font-weight:bold;">' + oldLine + ' [' + errMsg + ']</span>\r\n';
                else htmlBody += '<span style="color:lightgrey;">' + oldLine + '</span>\r\n';
                        
                lineNb++;
            }
        }
        
        public Scenario(String l, String tc, String b) {
            label = l;
            body = b;
            testClass = tc;
            htmlBody = body;
        }
    }
    
    public class Alias {
        public String pattern { get; private set; }
        public String expandsTo { get; private set; }
        public String expandsToHTML { get; private set; }
        public Integer nb { get; set; }
        public Boolean hasError { get; private set; }

        public void init() { expandsToHTML = expandsTo; hasError = false; }
        public void displayError(Integer lineNbErr, String errMsg) {
            hasError = true;
            Integer lineNb = 1;
            expandsToHTML = '';
            for (String oldLine : expandsTo.split('\r\n')) {
                if (lineNb < lineNbErr) expandsToHTML += '<span style="color:limegreen;">' + oldLine + '</span>\r\n';
                else if (lineNb == lineNbErr) expandsToHTML += '<span style="color:red; font-weight:bold;">' + oldLine + ' [' + errMsg + ']</span>\r\n';
                else expandsToHTML += '<span style="color:lightgrey;">' + oldLine + '</span>\r\n';
                
                lineNb++;
            }
        }
        
        public Alias(String p, String e) {
            pattern = p;
            expandsTo = e;
            expandsToHTML = e;
            hasError = false;
        }
    }
}