## Config files for Sublime Text 3 Editor

| Files 	| Installation 	| Usage 	|
|:-	|:-	|:-:	|
| [add_date.py](add_date.py) 	| Save this in `/[home_directory]/.config/sublime-text-3/Packages/User/`<br>Add these to `Preference` > `Key Bindings` > `User keymap`<br>[<br>    {"keys": ["ctrl+shift+,"], "command": "add_date" },<br>    {"keys": ["ctrl+shift+."], "command": "add_time" }<br>] 	| `Ctrl` + `Shift` + , <br> `Ctrl` + `Shift` + . 	|
| [python_about.sublime-snippet](python_about.sublime-snippet) 	| Save this in `/[home_directory]/.config/sublime-text-3/Packages/User/` 	| about + `Tab` 	|
| [python_shebang.sublime-snippet](python_shebang.sublime-snippet) 	| Save this in `/[home_directory]/.config/sublime-text-3/Packages/User/` 	| shebang + `Tab` 	|
|Monokai.sublime-color-scheme|`Ctrl+Shift+P >> pvr >> Open Resource >> Color Scheme - Default >>` <br> Add `"highlight": "var(blue)",` in `globals`<br>* [Ref1](https://sublimetext.userecho.com/en/communities/1/topics/4674-make-highlight-matches-easier-to-see) <br>* [Ref2](https://www.sublimetext.com/docs/3/color_schemes.html#global_settings-find)|

## Sublime REPL (Side-by-side Build System)
| Files 	| Installation 	| Usage 	|
|:-	|:-	|:-:	|
||[Origami](https://github.com/SublimeText/Origami#installation)|[Usage](https://github.com/SublimeText/Origami#using-the-command-line)
||[Terminus](https://packagecontrol.io/packages/Terminus)|[Usage](https://packagecontrol.io/packages/Terminus)
|[PythonREPL.sublime-build](PythonREPL.sublime-build)|Save this in `/[home_directory]/.config/sublime-text-3/Packages/User/`|
|[terminus_python.sublime-build](terminus_python.sublime-build)|Save this in `/[home_directory]/.config/sublime-text-3/Packages/User/`|
|[terminus_repl.py](terminus_repl.py)|Save this in `/[home_directory]/.config/sublime-text-3/Packages/User/`|
|[newPython3.sublime-build](newPython3.sublime-build)|Save this in `/[home_directory]/.config/sublime-text-3/Packages/User/`|

## Reference
* [[QT08] Supercharging Terminus builds in Sublime Text](https://www.youtube.com/watch?v=HaH3U53UvcY&ab_channel=OdatNurd-SublimeTextTutorials)
