# PocketBookDic
Scripts to convert to pocketbook dictionary dic-format

pocketbookdic.pl 
Script to convert from cvs-, Stardict dict-, Stardict dictdz- and xdxf-format to pocketbook dic-format

Dependencies:
- Perl - It's a Perl script: Install Perl to run it!
- Perl modules - Sort::Key::Natural, Storable, Term::ANSIColor and Encode are used. Some are installed with Perl, others will have to be installed separately. They can be installed with from cpan. E.g. In Arch Linux the first module is installed by `cpan i Sort::Key::Natural`. Most modules can alse be installed from the AUR in Arch Linux: `yay -s perl-sort-naturally`.
- converter.exe - Pocketbook's converter. Look on the mobileread site in the pocketbook subforum for the newest version.
- language folders - converter.exe depends on the presence of a language folder in which the files collates.txt, keyboard.txt and  morphems.txt are located. The name of the language folder should be the same as the language_from which your dictionary translates. There are a lot of preformed language folders floating around the mobileread site in the pocketbook subforum.
- Wine - Converter.exe is a windows binary, which can be runned with Wine. (If your running windows, you should remove wine from the last command in the script. E.g. `system("wine convert.exe \"$FileName\" $lang_from");` becomes `system("convert.exe \"$FileName\" $lang_from");` 
- stardict-bin2text - The script uses a binary from the stardict-tools package to convert a triplet of ifo-, -idx and -dict (or -dict.dz) Stardict files to one xml-file. (That xml-file will then be converted to a xdxf-file, which will be reconstructed to fit through converter.exe. (If you run Windows you should change the system() call to stardict-bin2text to something that works on windows!)
- I've probably forgotten something. If you run into it, please open an issue.
