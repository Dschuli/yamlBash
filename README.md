**yamlBash.sh**

Bash script to replace a value of a key:value pair in a yaml file while keeping original structure and comments.

(Nested) Key elements should separated by ":", e.g. Key0:Key1:Key2.
Key elements are treated as regex, so can e.g. be specified like "St.*". This will pick up any
key starting with "St" and might lead to more than one line being changed. 

Currently yamlBash.sh supports only chnages to mappings/dictionaries, as e.g.
	
    Key0:
      Key1: Null
      Key2: xxxx
         Key3: to be replaced
      Key4: yyyy
    Key5: zzzz


and allows to e.g. replace/insert a value for Key3. Key parameter would be Key0:Key2:Key3.

Current settings/restrictions:
- If the target key has sub-maps (additional lines with higher indent), those will be replaced by the provided value parameter. deleting/replacing those sub-maps. 
  Only comments on the same line a the key will be retained
- A key value provided by the -v parameter has to be a simple scalar or string and will get applied without. 
  any transformation, e.g. required apostrophes etc have to be part of the provided value parameter.
- When using the -f / --file parameter, the following applies:
  - If the file contains a single line (trailing blank lines are ignored), the content of that line 
    will be handeled like a -v parameter.
  - If the file has more than one line, the content will be treated as sub-mapping and the corresponding lines 
    will get inserted as-is (including comments) after the target key, replacing any value/sub-mapping in the 
    original yaml file. Indention of those new lines is adjusted to fit into the original structure as below:
      - Any (starting; line 1) indent in the value file will be removed and replaced by the next level of indent
        of the target key. This additional indent will be detected in the original file. If nothing can be detected,
        a default indent (set in the script; usually 2 spaces) will be used.   
- Other forms of YAML structures and notations (e.g. lists, block or flow style) will not be changed, 
  but left as-is.
- No support for multi-line strings. 

ymf.sh uses stdIn and stdOut to allow piping / redirection to implement multiple changes to a yaml file. Check out the provided example script.

    Help for yamlBash.sh:
      Function: Replace value for a (nested) key identified by the "key" parameter in a yaml file
                while keeping structure and comments.
    
      (Required) Parameters are:
         -k / --key          Key name to be altered as above in the format Level0:Level1:Level2
         -v / --value        (New) value for the key
         -f / --file         File with the (new) value for the key
                             -v or -f have to be provided. -v takes precedence over -f
        Optional:
        -c / --check         File(s) will be checked against the use of tab characters (YAML uses spaces) "
        -h / --help / ?      Help

