Pickle Syntax
-------------

A Pickle scenario is composed of several steps (delimited by a carriage return). Note that the first word of the step like "Given", "When" or "Then" is ignored.

    Given I am on page "<Page Name>" (<Controller class>) [with parameters param1=val1, param2=val2]

This step tells Pickle to initialize the Custom Controller for the VF page. Because the Controller class is provided, Pickle automatically allocates it and stores the instance in a variable called after the VF page name. This variable can be accessed by calling getVariable(<variable name>). The parameters are optional, but when set are added to ApexPages.getCurrent().getParameters().

    Given I am on page "<Page Name>"
    
This step does not indicate the controller class, and thus calls Pickle abstract method initializeController(String pageName) that must be overriden.

    When I set "number" to "5"
    
This step will call Pickle abstract method setValue("number", "5"), so you need to override this method.

    Then "result" should be >= "16"
    
This step will call Pickle abstract method getValue("result") (which needs to be overriden) and will compare the result with "16". The operations can be "contains" (text value only), =, >=, >, <, <=, <> (numeral value only) or "equal to" (any value)

    Given the following Users:
    1|Joe Smith
    2|Jane Doe
      

This step will look for the Users whose full names are "Joe Smith" and "Jane Doe" and will respectively assign them a temporary ID 1 and 2 (note: it can be any string and does not have to be a number). This step needs to be ended by a blank line to signal the end of the User table.

    Given the following Account exist:
    Account Id|Owner Id|Account Name
    3         |1       |Foo Inc.    
    4         |2       |Bar Corp.
      
    
This step will create two Account records with the properties defined in the table. The Owners are set to the Users previously defined.

    then the query [SELECT Case Id, Subject FROM Case WHERE "Escalated" = true] should return:
    3|This is a test
      

This step runs the SOQL query [SELECT Id, Subject FROM Case WHERE isEscalated = true] and compares the result with the table described after.

    Start Test

This step calls Test.startTest()

    Stop Test

This step calls Test.stopTest()
