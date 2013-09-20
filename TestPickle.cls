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
            if (fieldName == 'number') { if (fieldValue == '') ((MyVisualForceController)variables.get('My VF Page')).numberField = null; else ((MyVisualForceController)variables.get('My VF Page')).numberField = Integer.valueOf(fieldValue); }
            else if (fieldName == 'text') ((MyVisualForceController)variables.get('My VF Page')).textField = fieldValue;
            else if (fieldName == 'select') ((MyVisualForceController)variables.get('My VF Page')).selectField = fieldValue;
        }
        public override Object getValue(String fieldName) {
            if (fieldName == 'number') return ((MyVisualForceController)variables.get('My VF Page')).numberField;
            else if (fieldName == 'text') return ((MyVisualForceController)variables.get('My VF Page')).textField;
            else if (fieldName == 'select') return ((MyVisualForceController)variables.get('My VF Page')).selectField;
            else if (fieldName == 'result') return ((MyVisualForceController)variables.get('My VF Page')).getResult();
            return null;
        }
        public override void executeAction(String actionName) { if (actionName == 'Compute') ((MyVisualForceController)variables.get('My VF Page')).compute(); }
    }
    
    // This class extends the Pickle syntax by adding a new statement type
    class StepCheckResult extends Pickle.StepDefinition {
        // This is where you define the regexp
        public StepCheckResult (Pickle p) { super(p, 'the result should be (.*)'); }
        // If the regexp is recognized, it will call this method, passing the arguments as a list of strings
        public override Boolean execute(List<String> args) {
            Integer result = ((MyVisualForceController)myPickle.variables.get('My VF Page')).getResult();
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
        cp.runScenario('Given the following Users exist:\r\n' +
                       '1|Laurent Poulain\r\n' +
                       '\r\n' +
                       'Given the following "Account" exist:\r\n' +
                       'Account Id|Account Name\r\n' +
                       '2         |Foo Inc.    \r\n' +
                       '\r\n' +
                       'Given the following "Cases" exist:\r\n' +
                       'Case Id|Account Id|Owner Id|Subject       |Case Origin|Escalated\r\n' +
                       '3      |2         |1       |This is a test|Web        |true     \r\n' +
                       '\r\n' +
                       'then the query [SELECT Case Id, Subject FROM Case WHERE "Escalated" = true] should return:\r\n' +
                       '3|This is a test');
                       
        cp.runScenario('Given I am on page "My VF Page" (PickleTest.MyVisualForceController) with parameters foo=24, bar=27\r\n' +
                       'When I set "number" to "5"\r\n' +
                       'and I set "text" to "foo"\r\n' +
                       'and I set "select" to "22"\r\n' +
                       'and I click on "Compute"\r\n' +
                       'Then "result" should be >= "16"\r\n' +
                       'and the result should be 16');
 
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
    
    public static testMethod void test() {
        PickleTest st = new PickleTest();
    }
}
