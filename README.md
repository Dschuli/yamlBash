ymf.sh

Allows to change the value of a property in a yaml file, without altering structure and removing comments as eg. yp merging does.
According to the use case the property is at a hierarchy level 3, with level 1 and 3 being hardcoded (currently) and level 2 being
provided as parameter propertyName:

image:
  propertyName:
    digest: 

ymf.sh uses stdIn and stdOut to allow chaining to affect multiple changes. Check out the provided example 
	FloForTenX.sh,
which implements the original use case. 


Help for ymf.sh:
  Function: Replace value for property image:propertyName:digest in a yaml file while keeping structure and comments.

  (Required) Parameters are:
     -p / --property     Name of property to change as above
     -v / --value        (New) value of property
     -f / --file         File with the (new) value of property
                         -v or -f have to be provided. -v takes precedence over -f

     -h / -- help / ?    Help

