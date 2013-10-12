@isTest
public class PickleTest {
    public PickleTest() {
        // Instantiate the Pickle class
        CustomPickle cp = new CustomPickle();
        // Registers the custom statement type (you can pass a Pickle.StatementType of List<Pickle.StatementType>)
        cp.registerStepDefinition(new CustomPickle.StepCheckResult(cp));

        // You have two ways to run a scenario.
        // The first is to run one directly:
/*        
        cp.runScenario('Test #1', 'Given I am on page "My VF Page" (PickleTest.MyVisualForceController)\r\n' +
                                  'When I set "number" to "5"\r\n' +
                                  'and I set "text" to "foo"\r\n' +
                                  'and I set "select" to "23"\r\n' +
                                  'and I click on "Compute"\r\n' +
                                  'Then "result" should be >= "16"\r\n' +
                                  'and the result should be 16');*/

        // The other one is to run a scenarion from the scenario Repository:
        cp.runScenario(1);
        cp.runScenario(2);
 
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
    
   public static testMethod void test1() {
        PickleTest st = new PickleTest();
    }

    public static testMethod void test2() {
        CustomPickle cp = new CustomPickle();
        cp.runScenario(3);
        cp.runScenario(4);
     }
}