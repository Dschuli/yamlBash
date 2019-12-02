**ymf.sh**

Allows to change the value of a property in a yaml file, without altering structure and removing comments as eg. yp merging does.
The property to be changed is identified by the parameter `property` (see below) and has to be at hierarchy level 3, e.g.

    level1:
       level2:
          level3: value to be altered 

ymf.sh uses stdIn and stdOut to allow piping to implement multiple changes. Check out the provided example 
	FloForTenX.sh,
which implements the original use case. 


    Help for ymf.sh:
       Function: Replace value for a property identified by the property parameter in a yaml file 
                 while keeping structure and comments. Property is currently hardcoded to be at Level 3 (sub-sub-property)"

       Required) Parameters are:
          -p / --property     Name of property to altered as above in the format Level1:Level2:Level3
          -v / --value        (New) value of property
          -f / --file         File with the (new) value of property
                              -v or -f have to be provided. -v takes precedence over -f

         -h / -- help / ?    Help
