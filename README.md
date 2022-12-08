Design Choices
--------------
Justification of my sollution can be found in the comments together with java methods.

Most of the code for the solution is in the schema.sql file, while the java code is used mostly for interaction with the database and it also uses the queries that sort the results.
I have used FUNCTIONS and VIEWS within postgres to make my sollution reliable and easy to use. I handle errors in the java code using try-catch blocks and close prepared statemets and result sets after use. 
My program successfully handles all the test cases provided in the assignment. And also handles the error cases like invalid inputs and invalid queries. If error occurs, the state of the database is not changed.