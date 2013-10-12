// This class is extending Pickle and performs several tasks:
// - It embeds a reference to the VF controller
// - It defines the bindings between the text and the calls to the VF Controller
// - It can contain its own scenarios and aliases
// - It can define its own Statement type to extend the Pickle syntax
public class CustomPickle extends Pickle {
    
    public class MyVisualForceController {
        List<SelectOption> selectFieldOptions;
        public String selectField { get; set; }
        public List<SelectOption> getSelectFieldOptions() { return selectFieldOptions; }
        public String textField { get; set; }
        public Integer numberField { get; set; }
        Integer result;
        public Integer getResult() { return result; }
        
        public MyVisualForceController() {
            selectFieldOptions = new SelectOption[] { new SelectOption('1', 'Option 1'), new SelectOption('22', 'Option 2'), new SelectOption('333', 'Option 3') };
            numberField = 2;
            textField = 'Foo';
            selectField = '333';
        }

        public PageReference compute() {
            result = (numberField + textField.length()) * selectField.length();
            return null;
        }
    }
    
//        public MyVisualForceController ctrl;

        public override String getName() { return 'My VisualForce Page'; }
        public override List<Pickle.Scenario> getScenarios() {
            return new Scenario[] {
                new Pickle.Scenario('Creating SObject and testing them', 'PickleTest',
                             'Given the following Users:\r\n' +
                             '1|Laurent Poulain\r\n' +
                             '\r\n' +
                             'Given the following Accounts exist:\r\n' +
                             'Account Id|Account Name\r\n' +
                             '2         |Foo Inc.    \r\n' +
                             '3         |Bar Corp.   \r\n' +
                             '\r\n' +
                             'Given the following Cases exist:\r\n' +
                             'Case Id|Account Id|Owner Id|Subject             |Case Origin|Escalated\r\n' +
                             '4      |2         |1       |This is a test      |Web        |true     \r\n' +
                             '5      |3         |1       |This is another test|Web        |true     \r\n' +
                             '\r\n' +
                             'then the query [SELECT Case Id, Subject FROM Case WHERE "Escalated" = true] should return:\r\n' +
                             '4|This is a test\r\n' +
                             '5|This is another test'),
                new Pickle.Scenario('Testing VF Page', 'PickleTest',
                             'Start Test\r\n' +
                             'Given I am on page "My VF Page" (CustomPickle.MyVisualForceController)\r\n' +
                             'When I set "number" to "5"\r\n' +
                             'and I set "text" to "foo"\r\n' +
                             'and I set "select" to "23"\r\n' +
                             'and I click on "Compute"\r\n' +
                             'Then "result" should be >= "16"\r\n' +
                             'and the result should be 16\r\n' +
                             'Stop Test'),
                new Pickle.Scenario('Testing the tables', 'PickleTest',
                             'Given the Cases Sample #1 exist\r\n' +
                             'Given I am on page "My VF Page" (CustomPickle.MyVisualForceController)\r\n' +
                             'Then "cases" should be:\r\n' +
                             'Case Id|Subject |Case Origin|Escalated\r\n' +
                             '1      |Test #1 |Web        |true     \r\n' +
                             '3      |Test #2 |Web        |false    \r\n' +
                             '2      |Test #3 |Phone      |false'),
                new Pickle.Scenario('Testing the string table', 'PickleTest',
                             'Given I am on page "My VF Page" (CustomPickle.MyVisualForceController)\r\n' +
                             'Then "String Table" should be:\r\n' +
                             'Row 1|Field 1 |Field 2 |Field 3 \r\n' +
                             'Row 2|Field 1a|Field 2a|Field 3a\r\n' +
                             'Row 3|Field 1b|Field 2b|Field 3b')
            };
        }

        public override List<Pickle.Alias> getAliases() {
            return new Pickle.Alias[] {
                new Pickle.Alias('the Cases Sample #1 exist',
                                 'the following Cases exist:\r\n' +
                                 'Subject |Case Origin|Escalated|Case Id\r\n' +
                                 'Test #1 |Web        |true     |1\r\n' +
                                 'Test #3 |Phone      |false    |2\r\n' +
                                 'Test #2 |Web        |false    |3\r\n' +
                                 '\r\n')
            };
        }

        // These are the standard methods that you can extend to define
        // You don't have to extend them all, but will get an error if Pickle needs
        // a method which hasn't been overriden
//        public override void initializeController(String pageName) { ctrl = new MyVisualForceController(); }
        public override void setValue(String fieldName, String fieldValue) {
            if (fieldName == 'number') { if (fieldValue == '') ((MyVisualForceController)getVariable('My VF Page')).numberField = null; else ((MyVisualForceController)getVariable('My VF Page')).numberField = Integer.valueOf(fieldValue); }
            else if (fieldName == 'text') ((MyVisualForceController)getVariable('My VF Page')).textField = fieldValue;
            else if (fieldName == 'select') ((MyVisualForceController)getVariable('My VF Page')).selectField = fieldValue;
        }
        public override Object getValue(String fieldName) {
            if (fieldName == 'number') return ((MyVisualForceController)getVariable('My VF Page')).numberField;
            else if (fieldName == 'text') return ((MyVisualForceController)getVariable('My VF Page')).textField;
            else if (fieldName == 'select') return ((MyVisualForceController)getVariable('My VF Page')).selectField;
            else if (fieldName == 'result') return ((MyVisualForceController)getVariable('My VF Page')).getResult();
            else if (fieldName == 'cases') return [SELECT Subject, Id, Origin, isEscalated FROM Case ORDER BY Subject];
            else if (fieldName == 'String Table') {
                List<List<String>> l = new List<List<String>>();
                l.add(new String[] { 'Row 1', 'Field 1', 'Field 2', 'Field 3' });
                l.add(new String[] { 'Row 2', 'Field 1a', 'Field 2a', 'Field 3a' });
                l.add(new String[] { 'Row 3', 'Field 1b', 'Field 2b', 'Field 3b' });
                return l;
            }
            return null;
        }
        public override void executeAction(String actionName) { if (actionName == 'Compute') ((MyVisualForceController)getVariable('My VF Page')).compute(); }
        
    
    // This class extends the Pickle syntax by adding a new statement type
    public class StepCheckResult extends Pickle.StepDefinition {
        // This is where you define the regexp
        public StepCheckResult (Pickle p) { super(p, 'the result should be (.*)'); }
        // If the regexp is recognized, it will call this method, passing the arguments as a list of strings
        public override Boolean execute(List<String> args) {
            Integer result = ((MyVisualForceController)myPickle.getVariable('My VF Page')).getResult();
            if (result != Integer.valueOf(args[0])) myPickle.error('Error: result incorrect');
            return true;
        }
    }
        
}