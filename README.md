# BinTooling

 Small toolset to help analysing object files ( preferably *.o understood by objdump )
 This will create annotated source-html and a graphviz file showing the call graphs


## parse_object_files.pl

 Read and parse and create dot file and related hrefs html using pandoc
 Usage:
```
 perl  parse_object_files.pl $(cat cont.list) -savedb files_loaded.db tags analysis -savedb analysed.db html new.dot && dot   -Tsvg new.dot -o html/out.svg
```
 or 
```
perl parse_object_files.pl analysed.db html new.dot && dot   -Tsvg new.dot -o html/out.svg
```
Inputs accepted:
-     *.o  : object files to be parsed by objdump
-     *.db : perl-database containing all current state (to restore state)
-     -savedb *.db :  Save database state into file
-     analysis :  post process loaded objects and link relations (optional)
-     tags : load source references also from tags file
            (future:  use '-g' from object format to find source locations )
-     html : use pandoc to create annotated html sources (stored in ./html/* )
-     *.dot : Create dot format of understood content  (url references to html files

  parsing of dot files:  dot   -Tsvg new.dot -o html/out.svg
