## dump-contacts2db.sh
Dumps contacts from an Android contacts2.db to stdout in vCard format.

### Usage 
```Bash
dump-contacts2db.sh path/to/contacts2.db > path/to/output-file.vcf
```

### Dependencies
* perl
* base64
* sqlite3

#### [Execution on Windows](http://nerdspiral.com/howto-android-kontakte-retten-auch-aus-backups/)
* Install cygwin with added perl and sqlite3 packages
* Ensure that Git does not change the file ending settings to Windows!!

Otherwise, you will get a similar error:
```
./dump-contacts2db.sh: line 2: $'\r': command not found.
./dump-contacts2db.sh: line 26: $'\r': command not found.
./dump-contacts2db.sh: line 57: syntax error: unexpected word `$'do\r''
'/dump-contacts2db.sh: line 57: `do
```


### Tested platforms
* Ubuntu 12.04 Precise Pangolin
* Debian Squeeze/Wheezy
* Windows 7

### Tested Android versions (all Google Experience Devices)
* 2.2	Froyo
* 2.3.5 Gingerbread
* 4.0.3 Ice Cream Sandwich
* 4.1.1 Jelly Bean
* 4.4.4 KitKat (Cyanogenmod 11)

### Known issues
* Doesn't handle file-not-found or type mismatch gracefully; need to implement validation
* Doesn't handle missing sqlite gracefully; need to implement validation



