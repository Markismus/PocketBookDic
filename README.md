# PocketBookDic
Scripts to convert to pocketbook dictionary dic-format

**pocketbookdic.pl** \
Script to convert from csv-, Stardict dict-, Stardict dictdz-, Textual Stardict xml-, mobi- (via html- with KindleUnpack) and xdxf-format to pocketbook dic-format and Stardict dict/idx/ifo-format. (The csv-file should be comma separated.)

_Dependencies:_
- Perl - It's a Perl script: Install Perl to run it! 
- Perl modules - Term::ANSIColor and Encode are used. They might be installed with Perl or will have to be installed separately. They can be installed from cpan. E.g. In Arch Linux the first module is installed by `cpanp i Term::ANSIColor`. On Windows 10 I only installed 'Strawberry Perl' and no modules and it still ran, so go figure!
- converter.exe - Pocketbook's converter. Look on the mobileread site in the pocketbook subforum for the newest version. (Currently it is converter3.exe posted by ezdiy. Please rename it to converter.exe.)
- language folders - converter.exe depends on the presence of a language folder in which the files collates.txt, keyboard.txt and  morphems.txt are located. The name of the language folder should be the same as the language_from which your dictionary translates. There are a lot of preformed language folders floating around the mobileread site in the pocketbook subforum.
- Wine - Converter.exe is a windows binary, which can be runned with Wine. (If your running windows, you of course do not need wine.
- stardict-bin2text - The script uses a binary from the stardict-tools package to convert a triplet of ifo-, -idx and -dict (or -dict.dz) Stardict files to one xml-file. (That xml-file will then be converted to a xdxf-file, which will be reconstructed to fit through converter.exe. 
    - If you run Windows you should _manually_ generate the xml- or csv-file. E.g. You can use stardict-editor (included with the windows Stardict installation) and decompile a dictionary to Textual Stardict dictionary. This generates a xml-file that you can use as filename at the start of the script.
- stardict-text2bin - The script has been expanded to generate Stardict binary files. 
- KindleUnpack - If you want to convert mobi-dictionaries, you'll first have to convert it to html-format using KindleUnpack (https://github.com/kevinhendricks/KindleUnpack).
- I've probably forgotten something. If you run into it, please open an issue.

_Preparation:_
- Install the dependencies
- Move the script `pocketbook.pl`, the language maps, e.g. `eng`, `converter.exe` into the same map.
- Change the control variables in the beginning of the script to your liking. The most important one will be:
  - BaseDir = "absolute_path_to_your_map"; (In Windows remember to write your path with slashes, e.g. "C:/Users/DefaultUser/Downloads/PocketbookDic/".
  - FileName = "relative_to_your_$Basedir_path/name_of_your_dictionary", e.g. "dict/Latin-English\ dictionary.ifo".
  - isCreateStardictDictionary = 1; # Turns on Stardict text and binary dictionary creation.
  - isCreatePocketbookDictionary = 1; # Turns on Pocketbook Dictionary dic-format creation.

  
  
_Usage:_
- To run: `perl pocketbookdic.pl`
- Using arguments: 
    - `perl pocketbookdic.pl path_to_and_filename_of_your_dictionary_with_extention`
    - `perl pocketbookdic.pl path_to_and_filename_of_your_dictionary_with_extention language_folder_name`
