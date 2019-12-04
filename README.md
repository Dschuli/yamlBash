**yamlBash.sh**

Bash script to replace a value of a key:value pair in a yaml file while 
keeping original structure and comments.

(Nested) Key elements should separated by ":", e.g. Key0:Key1:Key2.
Key elements are treated as regex, so can e.g. be specified like "St.*". This will pick up any
	key starting with "St" and might lead to more than one line being altered. 

Currently only supports simple mappings/dictionaries, as e.g.
	
    Key0:
      Key1: Null
      Key2: xxxx
         Key3: to be replaced
      Key4: yyyy
    Key5: zzzz

and allows to e.g. replace/insert a value for Key3. Key parameter would be Key1:Key3.
Current settings/restrictions:
- Other forms of YAML structures and notations (e.g. lists, block or flow style), are not supported.
- Value has to be a simple scalar or string
- Inserted values are not put into " or ', therefore no multiline strings
- If the target key has sub-keys/nestings, those will not be altered 

ymf.sh uses stdIn and stdOut to allow piping to implement multiple changes. Check out the provided example 
	FloForTenX.sh,
which implements the original use case. 


    Help for yamlBash.sh:
      Function: Replace value for a (nested) key identified by the "key" parameter in a yaml file
                while keeping structure and comments. Currently a nesting level of 3 (and only 3) is supported.
    
      (Required) Parameters are:
         -k / --key          Key name to be altered as above in the format Level0:Level1:Level2
         -v / --value        (New) value for the key
         -f / --file         File with the (new) value for the key
                             -v or -f have to be provided. -v takes precedence over -f
    
         -h / -- help / ?    Help

