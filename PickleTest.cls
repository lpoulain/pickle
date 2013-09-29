@isTest
public class PickleTest {
    // This class is just a fake VisualForce custom controller
    // This controller has a known bug: if any field is not set the result will be null - or may crash
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

    // This class is extending Pickle and performs several tasks:
    // - It embeds a reference to the VF controller
    // - It defines the bindings between the text (e.g. "") and the calls to the VF Controller
    // - It defines its own Statement type to extend the Pickle syntax
    public class CustomPickle extends Pickle {
//        public MyVisualForceController ctrl;
    
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
    }
    
    // This class extends the Pickle syntax by adding a new statement type
    class StepCheckResult extends Pickle.StepDefinition {
        // This is where you define the regexp
        public StepCheckResult (Pickle p) { super(p, 'the result should be (.*)'); }
        // If the regexp is recognized, it will call this method, passing the arguments as a list of strings
        public override Boolean execute(List<String> args) {
            Integer result = ((MyVisualForceController)myPickle.getVariable('My VF Page')).getResult();
            if (result != Integer.valueOf(args[0])) myPickle.error('Error: result incorrect');
            return true;
        }
    }
    
    public PickleTest() {
        // Instantiate the Pickle class
        CustomPickle cp = new CustomPickle();
        // Registers the custom statement type (you can pass a Pickle.StatementType of List<Pickle.StatementType>)
        cp.registerStepDefinition(new StepCheckResult(cp));

        // Runs the scenario. An exception is thrown if it fails
        PickleScenarios.run('My Controller',1,cp);
        PickleScenarios.run('My Controller',2,cp);
 
/*
        // The second part is preparing Pickle for random testing
        // It should NOT be deployed on a Production org as a test method (unless you catch an exception)
        // Instead, it should be run on the sandbox only
        
        // It first registers the available action
        cp.registerAction('Compute');
        cp.initializeController('My VF Page');
        // It registers the available fields, along with the available values
        // (not that Pickle will always use them ;-)
        cp.registerField('text', new String[] { 'sessdf', 'sdfs', 'dgfg' } );
        cp.registerField('number', new Integer[] { 1, 2, 3, 4, 5, 6 } );
        cp.registerField('select', cp.ctrl.getSelectFieldOptions());
        // Launches the testing, asking to perform 1000 random steps
        cp.randomTesting('My VF Page', 1000);*/
    }
    
 /*   public static testMethod void test1() {
        PickleTest st = new PickleTest();
    }
*/
    public static testMethod void test2() {
        CustomPickle cp = new CustomPickle();
        PickleScenarios.run('My Other Controller',1,cp);
        PickleScenarios.run('My Other Controller',2,cp);
     }
/*
    public static testMethod void testStandardSteps() {
        CustomPickle cp = new CustomPickle();
        cp.runScenario('Test', 'I am on page "My VF Page" (PickleTest.MyVisualForceController) with parameters foo=bar');
        PickleTest.MyVisualForceController ctrl = (PickleTest.MyVisualForceController)cp.getVariable('My VF Page');
        cp.runScenario('Test', 'When I set "number" to "5"');
        System.assert(ctrl.numberField == 5);
        cp.runScenario('Test', 'Then "number" should be = "5"');
        cp.runScenario('Test', 'and I set "text" to "foo"\r\n' +
                               'and I set "select" to "22"\r\n' +
                               'and I click on "Compute"');
        System.assert(ctrl.result == 16);
        cp.runScenario('Test', 'Given the following Users:\r\n' +
                               '1|Laurent Poulain\r\n' +
                               '\r\n');
        System.assert(cp.getSObjectId('1') != null);
        cp.runScenario('Test', 'Given the following Accounts exist:\r\n' +
                               'Account Id|Owner Id|Account Name\r\n' +
                               '2         |1       |Foo Inc.    \r\n' +
                               '\r\n');
        Account a = [SELECT Id, OwnerId, Name FROM Account];
        System.assert(a.Id == cp.getSObjectId('2'));
        System.assert(a.OwnerId == cp.getSObjectId('1'));
        System.assert(a.Name == 'Foo Inc.');
        cp.runScenario('Test', 'then the query [SELECT Account Id, Owner Id, Account Name FROM Account WHERE "Account Name" = \'Foo Inc.\'] should return:\r\n' +
                               '2|1|Foo Inc.');
        cp.runScenario('Test', 'Start Test\r\nStop Test');
    }
*/
}